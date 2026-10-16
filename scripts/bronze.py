from __future__ import annotations

import argparse
import io
import os
import tempfile
import zipfile
from pathlib import Path

import pandas as pd
import requests


AWS_ACCESS_KEY_ID = ''
AWS_SECRET_ACCESS_KEY = ''
AWS_SESSION_TOKEN = ''

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / 'dados' / 'bronze'
CENSO_URL = (
    'https://servicodados.ibge.gov.br/api/v3/agregados/9514/periodos/2022/'
    'variaveis/93?localidades=N6[3548807]&classificacao=287[all]'
)
PNS_URL = (
    'https://ftp.ibge.gov.br/PNS/2019/Microdados/Dados/'
    'PNS_2019_20220525.zip'
)
PNS_COLSPECS = [(0, 2), (2, 9), (9, 18), (116, 119), (967, 968), (1425, 1439)]
PNS_COLUMNS = ['V0001', 'V0024', 'UPA_PNS', 'C008', 'Q084', 'V00291']


def capture_censo(refresh: bool) -> Path:
    output_path = RAW_DIR / 'censo_bronze.csv'
    if output_path.exists() and not refresh:
        print(f'Reutilizando captura existente: {output_path}', flush=True)
        return output_path

    response = requests.get(
        CENSO_URL, timeout=120, headers={'User-Agent': 'Mozilla/5.0'}
    )
    response.raise_for_status()
    payload = response.json()
    if not isinstance(payload, list) or not payload:
        raise ValueError('A API do Censo retornou uma resposta vazia ou invalida.')

    rows = []
    for result in payload[0].get('resultados', []):
        classifications = result.get('classificacoes', [])
        series = result.get('series', [])
        if not classifications or not series:
            continue
        categories = classifications[0].get('categoria', {})
        locality = series[0].get('localidade', {})
        rows.append({
            'Codigo_idade': next(iter(categories.keys()), ''),
            'Idade': next(iter(categories.values()), ''),
            'Populacao_2022': series[0].get('serie', {}).get('2022', ''),
            'Codigo_municipio': locality.get('id', ''),
            'Municipio': locality.get('nome', ''),
        })

    if not rows:
        raise ValueError('A API do Censo nao retornou linhas de populacao.')
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='censo_', dir=RAW_DIR) as temporary:
        temporary_path = Path(temporary) / 'censo.csv'
        pd.DataFrame(rows).to_csv(temporary_path, index=False, encoding='utf-8-sig')
        temporary_path.replace(output_path)
    print(f'Captura do Censo salva: {output_path}', flush=True)
    return output_path


def capture_pns(refresh: bool) -> Path:
    output_path = RAW_DIR / 'pns_bronze.csv'
    if output_path.exists() and not refresh:
        print(f'Reutilizando captura existente: {output_path}', flush=True)
        return output_path

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='pns_capture_', dir=RAW_DIR) as temporary:
        zip_path = Path(temporary) / 'pns_microdados.zip'
        temporary_csv = Path(temporary) / 'pns.csv'
        print('Baixando microdados da PNS; o arquivo e grande.', flush=True)
        with requests.get(
            PNS_URL, stream=True, timeout=(30, 300),
            headers={'User-Agent': 'Mozilla/5.0'},
        ) as response:
            response.raise_for_status()
            with zip_path.open('wb') as zip_file:
                for block in response.iter_content(chunk_size=1024 * 1024):
                    if block:
                        zip_file.write(block)

        count = 0
        with (
            zipfile.ZipFile(zip_path) as archive,
            archive.open('PNS_2019.txt') as binary,
            io.TextIOWrapper(binary, encoding='latin-1') as text,
        ):
            chunks = pd.read_fwf(
                text, colspecs=PNS_COLSPECS, names=PNS_COLUMNS,
                chunksize=250_000, dtype=str, keep_default_na=False,
            )
            for chunk in chunks:
                if chunk.empty:
                    continue
                chunk.to_csv(
                    temporary_csv, index=False,
                    encoding='utf-8-sig' if count == 0 else 'utf-8',
                    mode='w' if count == 0 else 'a', header=count == 0,
                )
                count += len(chunk)
        if count == 0:
            raise ValueError('O arquivo de microdados da PNS nao continha linhas.')
        temporary_csv.replace(output_path)

    print(f'Captura da PNS salva: {output_path}', flush=True)
    return output_path


def main() -> None:
    import boto3

    parser = argparse.ArgumentParser(description='Captura Censo/PNS e envia ao S3 Bronze.')
    parser.add_argument('--bucket', required=True, help='Nome do bucket Bronze criado pelo Terraform.')
    parser.add_argument('--region', default=os.environ.get('AWS_DEFAULT_REGION', 'us-east-1'))
    parser.add_argument('--refresh', action='store_true', help='Baixa novamente os CSVs locais.')
    args = parser.parse_args()

    if bool(AWS_ACCESS_KEY_ID) != bool(AWS_SECRET_ACCESS_KEY):
        parser.error('Preencha tanto AWS_ACCESS_KEY_ID quanto AWS_SECRET_ACCESS_KEY.')
    session = boto3.Session(
        aws_access_key_id=AWS_ACCESS_KEY_ID or None,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY or None,
        aws_session_token=AWS_SESSION_TOKEN or None,
        region_name=args.region,
    )
    client = session.client('s3')
    for capture in (capture_censo, capture_pns):
        output_path = capture(args.refresh)
        key = f'bronze/{output_path.name}'
        client.upload_file(
            str(output_path), args.bucket, key,
            ExtraArgs={'ContentType': 'text/csv; charset=utf-8'},
        )
        print(f'Enviado: s3://{args.bucket}/{key}', flush=True)


if __name__ == '__main__':
    main()