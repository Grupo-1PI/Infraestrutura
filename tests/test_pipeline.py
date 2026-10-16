import csv
import io
import os
import sys
import tempfile
import types
import unittest
import zipfile
from pathlib import Path
from unittest.mock import Mock, patch

from scripts import bronze, silver


class SilverTests(unittest.TestCase):
    def transform(self, function, text):
        target = io.StringIO()
        count = function(io.StringIO(text), target)
        target.seek(0)
        return count, list(csv.DictReader(target))

    def test_censo_filters_totals_and_normalizes_ages(self):
        count, rows = self.transform(
            silver.transform_censo,
            'Idade,Populacao_2022,Municipio\n'
            'Total,100,Sao Caetano\n'
            'Menos de 1 m\u00eas,5,Sao Caetano\n'
            '2 meses,6,Sao Caetano\n'
            '1 ano,7,Sao Caetano\n'
            '25 anos,8,Sao Caetano\n'
            '100 anos ou mais,9,Sao Caetano\n',
        )
        self.assertEqual(count, 5)
        self.assertEqual([row['faixa_etaria'] for row in rows], [
            'menos_de_1_mes', '2_mes', '1_ano', '25_ano', '100_ano_ou_mais',
        ])
        self.assertEqual(rows[-1]['municipio'], 'SCS-SP')
        self.assertEqual(rows[-1]['qtd_amostra'], '9')

    def test_pns_maps_values_filters_empty_and_rounds_half_up(self):
        count, rows = self.transform(
            silver.transform_pns,
            'V0001,UPA_PNS,C008,Q084,V00291\n'
            '35,000123,025,1,12.5\n'
            '33,000456,000,2,12.4\n'
            '99,000789,030, ,20\n',
        )
        self.assertEqual(count, 2)
        self.assertEqual(rows[0], {
            'uf': 'SP', 'codigo_upa': '000123', 'idade': '25',
            'dor_cronica': '1', 'peso_amostral_pns': '13',
        })
        self.assertEqual(rows[1]['uf'], 'RJ')
        self.assertEqual(rows[1]['idade'], '0')
        self.assertEqual(rows[1]['dor_cronica'], '0')
        self.assertEqual(rows[1]['peso_amostral_pns'], '12')

    def test_pns_rejects_unknown_codes_and_invalid_weights(self):
        for state, answer, weight in [
            ('99', '1', '2'), ('35', '3', '2'),
            ('35', '1', 'abc'), ('35', '1', 'NaN'),
        ]:
            with self.subTest(state=state, answer=answer, weight=weight):
                with self.assertRaises(ValueError):
                    self.transform(
                        silver.transform_pns,
                        'V0001,UPA_PNS,C008,Q084,V00291\n'
                        f'{state},0001,020,{answer},{weight}\n',
                    )

    def test_missing_columns_are_rejected(self):
        for function in (silver.transform_censo, silver.transform_pns):
            with self.assertRaises(ValueError):
                self.transform(function, 'incorrect\nvalue\n')

    def test_handler_downloads_transforms_and_uploads(self):
        uploads = []

        class FakeS3:
            def download_file(self, bucket, key, filename, ExtraArgs):
                assert ExtraArgs['ExpectedBucketOwner'] == '123456789012'
                with open(filename, 'w', encoding='utf-8-sig', newline='') as target:
                    target.write('Idade,Populacao_2022,Municipio\n25 anos,8,SCS\n')

            def upload_file(self, filename, bucket, key, ExtraArgs):
                uploads.append((bucket, key, Path(filename).read_bytes()))

        event = {'Records': [
            {'s3': {'bucket': {'name': 'raw'}, 'object': {'key': key}}}
            for key in ('bronze%2Fcenso_bronze.csv', 'bronze/other.csv')
        ]}
        with patch.object(silver, 's3_client', return_value=FakeS3()):
            with patch.dict(os.environ, {
                'BRONZE_BUCKET': 'raw', 'SILVER_BUCKET': 'trusted',
                'BUCKET_OWNER_ACCOUNT_ID': '123456789012',
            }):
                result = silver.lambda_handler(event, None)
        self.assertEqual(result, {'processed': [{'key': 'silver/censo_silver.csv', 'rows': 1}]})
        self.assertEqual(len(uploads), 1)
        self.assertEqual(uploads[0][:2], ('trusted', 'silver/censo_silver.csv'))
        self.assertTrue(uploads[0][2].startswith(b'\xef\xbb\xbf'))
        self.assertIn('25_ano,8,SCS-SP', uploads[0][2].decode('utf-8-sig'))


class BronzeTests(unittest.TestCase):
    def test_censo_capture_keeps_bronze_columns(self):
        response = Mock()
        response.json.return_value = [{'resultados': [{
            'classificacoes': [{'categoria': {'123': '25 anos'}}],
            'series': [{
                'localidade': {'id': '3548807', 'nome': 'Sao Caetano do Sul'},
                'serie': {'2022': '100'},
            }],
        }]}]
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(bronze, 'RAW_DIR', Path(temporary)):
                with patch.object(bronze.requests, 'get', return_value=response):
                    path = bronze.capture_censo(False)
                with path.open(encoding='utf-8-sig', newline='') as source:
                    rows = list(csv.DictReader(source))
        response.raise_for_status.assert_called_once()
        self.assertEqual(rows[0]['Codigo_idade'], '123')
        self.assertEqual(rows[0]['Populacao_2022'], '100')
        self.assertEqual(rows[0]['Codigo_municipio'], '3548807')

    def test_pns_capture_reads_original_fixed_width_positions(self):
        record = [' '] * 1439
        values = ['35', '0000001', '000000123', '025', '1', '000000000012.5']
        for (start, end), value in zip(bronze.PNS_COLSPECS, values):
            record[start:end] = list(value.ljust(end - start))
        payload = io.BytesIO()
        with zipfile.ZipFile(payload, 'w') as archive:
            archive.writestr('PNS_2019.txt', ''.join(record) + '\n')
        response = Mock()
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        response.iter_content.return_value = [payload.getvalue()]
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(bronze, 'RAW_DIR', Path(temporary)):
                with patch.object(bronze.requests, 'get', return_value=response):
                    path = bronze.capture_pns(False)
                with path.open(encoding='utf-8-sig', newline='') as source:
                    rows = list(csv.DictReader(source))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0], dict(zip(bronze.PNS_COLUMNS, values)))

    def test_cached_capture_does_not_download(self):
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(bronze, 'RAW_DIR', Path(temporary)):
                for name in ('censo_bronze.csv', 'pns_bronze.csv'):
                    (Path(temporary) / name).touch()
                with patch.object(bronze.requests, 'get') as get:
                    bronze.capture_censo(False)
                    bronze.capture_pns(False)
                get.assert_not_called()

    def test_main_uploads_both_files_even_when_cached(self):
        client = Mock()
        session = Mock()
        session.client.return_value = client
        boto3 = types.SimpleNamespace(Session=Mock(return_value=session))
        with patch.dict(sys.modules, {'boto3': boto3}):
            with patch.object(sys, 'argv', ['bronze.py', '--bucket', 'raw']):
                with patch.object(bronze, 'capture_censo', return_value=Path('censo_bronze.csv')):
                    with patch.object(bronze, 'capture_pns', return_value=Path('pns_bronze.csv')):
                        bronze.main()
        self.assertEqual(client.upload_file.call_count, 2)
        self.assertEqual(client.upload_file.call_args_list[0].args[1:], ('raw', 'bronze/censo_bronze.csv'))
        self.assertEqual(client.upload_file.call_args_list[1].args[1:], ('raw', 'bronze/pns_bronze.csv'))


if __name__ == '__main__':
    unittest.main()