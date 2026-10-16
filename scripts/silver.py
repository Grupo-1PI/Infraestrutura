from __future__ import annotations

import csv
import io
import os
import re
import tempfile
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from functools import cache
from pathlib import Path
from urllib.parse import unquote_plus


UF_CODES = dict(zip(
    ('11', '12', '13', '14', '15', '16', '17', '21', '22', '23', '24',
     '25', '26', '27', '28', '29', '31', '32', '33', '35', '41', '42',
     '43', '50', '51', '52', '53'),
    ('RO', 'AC', 'AM', 'RR', 'PA', 'AP', 'TO', 'MA', 'PI', 'CE', 'RN',
     'PB', 'PE', 'AL', 'SE', 'BA', 'MG', 'ES', 'RJ', 'SP', 'PR', 'SC',
     'RS', 'MS', 'MT', 'GO', 'DF'),
))
AGE_PATTERN = re.compile(
    r'Menos de 1 m\u00eas|\d+ (?:m\u00eas|meses|ano|anos)|100 anos ou mais'
)


def round_weight(value: str) -> str:
    value = value.strip()
    if not value:
        return ''
    try:
        weight = Decimal(value)
        if not weight.is_finite():
            raise InvalidOperation
        return str(weight.quantize(Decimal('1'), rounding=ROUND_HALF_UP))
    except InvalidOperation as error:
        raise ValueError(f'Peso amostral invalido: {value!r}') from error


def normalize_age_label(age: str) -> str:
    age = age.strip()
    age = age.replace('Menos de 1 m\u00eas', 'menos_de_1_mes')
    age = age.replace('100 anos ou mais', '100_ano_ou_mais')
    age = re.sub(r'^(\d+) (?:m\u00eas|meses)$', r'\1_mes', age)
    return re.sub(r'^(\d+) (?:ano|anos)$', r'\1_ano', age)


def transform_censo(source: io.TextIOBase, target: io.TextIOBase) -> int:
    reader = csv.DictReader(source)
    required = {'Idade', 'Populacao_2022', 'Municipio'}
    if not required.issubset(reader.fieldnames or []):
        raise ValueError('Colunas obrigatorias ausentes no Censo bronze.')
    writer = csv.writer(target)
    writer.writerow(['faixa_etaria', 'qtd_amostra', 'municipio'])
    count = 0
    for row in reader:
        age = row['Idade'].strip()
        if not AGE_PATTERN.fullmatch(age):
            continue
        population = Decimal(row['Populacao_2022'])
        if not population.is_finite():
            raise ValueError('Populacao do Censo invalida.')
        writer.writerow([normalize_age_label(age), str(population), 'SCS-SP'])
        count += 1
    return count


def transform_pns(source: io.TextIOBase, target: io.TextIOBase) -> int:
    reader = csv.DictReader(source)
    required = {'V0001', 'UPA_PNS', 'C008', 'Q084', 'V00291'}
    if not required.issubset(reader.fieldnames or []):
        raise ValueError('Colunas obrigatorias ausentes na PNS bronze.')
    writer = csv.writer(target)
    writer.writerow(['uf', 'codigo_upa', 'idade', 'dor_cronica', 'peso_amostral_pns'])
    count = 0
    for row in reader:
        answer = row['Q084'].strip()
        if not answer:
            continue
        state = row['V0001'].strip()
        if state not in UF_CODES:
            raise ValueError(f'Codigo de UF nao reconhecido: {state!r}')
        if answer not in {'1', '2'}:
            raise ValueError(f'Codigo de dor cronica nao reconhecido: {answer!r}')
        age = re.sub(r'^0+(?=\d)', '', row['C008'].strip())
        writer.writerow([
            UF_CODES[state], row['UPA_PNS'], age,
            '1' if answer == '1' else '0', round_weight(row['V00291']),
        ])
        count += 1
    return count


@cache
def s3_client():
    import boto3
    from botocore.config import Config

    return boto3.client('s3', config=Config(
        connect_timeout=10,
        read_timeout=120,
        retries={'mode': 'standard', 'max_attempts': 3},
    ))


def lambda_handler(event: dict, context: object) -> dict:
    client = s3_client()
    bronze_bucket = os.environ['BRONZE_BUCKET']
    silver_bucket = os.environ['SILVER_BUCKET']
    bucket_owner = os.environ['BUCKET_OWNER_ACCOUNT_ID']
    transformations = {
        'bronze/censo_bronze.csv': ('silver/censo_silver.csv', transform_censo),
        'bronze/pns_bronze.csv': ('silver/pns_silver.csv', transform_pns),
    }
    processed = []
    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        key = unquote_plus(record['s3']['object']['key'])
        if bucket != bronze_bucket or key not in transformations:
            print(f'Objeto ignorado: s3://{bucket}/{key}')
            continue
        output_key, transform = transformations[key]
        with tempfile.TemporaryDirectory(prefix='silver_') as temporary:
            source_path = Path(temporary) / 'bronze.csv'
            target_path = Path(temporary) / 'silver.csv'
            client.download_file(
                bucket, key, str(source_path),
                ExtraArgs={'ExpectedBucketOwner': bucket_owner},
            )
            with (
                source_path.open('r', encoding='utf-8-sig', newline='') as source,
                target_path.open('w', encoding='utf-8-sig', newline='') as target,
            ):
                count = transform(source, target)
            client.upload_file(
                str(target_path), silver_bucket, output_key,
                ExtraArgs={
                    'ContentType': 'text/csv; charset=utf-8',
                    'ExpectedBucketOwner': bucket_owner,
                },
            )
        print(f'{count} linhas enviadas para s3://{silver_bucket}/{output_key}')
        processed.append({'key': output_key, 'rows': count})
    return {'processed': processed}