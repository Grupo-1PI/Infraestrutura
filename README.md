# Datalake IBGE: Bronze e Silver

Branch: `feature/20261016/implementando-lambda`.

Este diretório contém somente a infraestrutura do datalake e seus scripts.
ALB, EC2, EFS, VPC, RDS, o bucket da aplicação e os bootstraps antigos foram removidos.
Os três buckets são Bronze (raw), Silver (trusted) e Gold. Gold fica vazio nesta etapa.
IAM e CloudWatch também são criados porque a Lambda precisa de permissões e logs.

## Fluxo

1. O Terraform cria os buckets, a Lambda e a notificação S3.
2. Depois de ativar o gatilho, o `terraform apply` executa `scripts/bronze.py` no seu PC.
3. O Python consulta o Censo 2022 e baixa o ZIP da PNS 2019. Salva os CSVs em `dados/bronze/`.
4. Cada CSV é enviado ao bucket Bronze, em `bronze/censo_bronze.csv` ou `bronze/pns_bronze.csv`.
5. Cada criação ou sobrescrita de objeto sob `bronze/` dispara a Lambda.
6. `scripts/silver.py` transforma o CSV e grava `silver/censo_silver.csv` ou `silver/pns_silver.csv` no bucket Silver.

Raw/Bronze e Trusted/Silver são nomes das camadas, não quatro buckets diferentes.
Arquivos com outros nomes disparam o gatilho, mas são ignorados pela função porque
não há regra de transformação para eles. Objetos fora de `bronze/` não disparam o gatilho.

A Lambda processa CSVs linha a linha, sem pandas. O pacote ZIP é montado pelo
Terraform e contém apenas `silver.py`; boto3 já vem no runtime Python 3.12 da AWS.
A função tem 1 GB de memória, 2 GB de armazenamento temporário e timeout de 15 minutos.
As regras de idade, UF, respostas de dor crônica, município e arredondamento dos
scripts fornecidos foram mantidas. As posições de largura fixa da PNS também foram mantidas.

## Antes De Executar

- Instale Git, Terraform >= 1.4, Python >= 3.10 e AWS CLI v2 no outro PC.
- Use uma conta com permissão para criar S3, Lambda, roles/policies IAM e logs CloudWatch.
	Alguns laboratórios acadêmicos restringem a criação de IAM; nesse caso o deploy
	precisa ser adaptado para uma role de laboratório já existente.
- Tenha internet e vários GB livres no disco do projeto para o ZIP da PNS e os CSVs.
- Não versione credenciais, os dados baixados nem arquivos de state.

No Windows, você pode instalar os programas pelo PowerShell e depois abrir outro terminal:

```powershell
winget install --id Git.Git -e
winget install --id Hashicorp.Terraform -e
winget install --id Python.Python.3.12 -e
winget install --id Amazon.AWSCLI -e
```

As alterações precisam estar commitadas e enviadas ao remoto para que outro PC
consiga baixá-las. Este trabalho não faz commit nem push automaticamente:

```powershell
git add --all
git commit -m "feat: implementa pipeline S3 Bronze e Lambda Silver"
git push -u origin feature/20261016/implementando-lambda
```

## Executar No Outro PC

No clone do repositório, execute no PowerShell:

```powershell
git fetch origin
git switch feature/20261016/implementando-lambda
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Copy-Item terraform.tfvars.example terraform.tfvars
```

Em `terraform.tfvars`, ajuste a região/prefixo se desejar e configure o Python
do ambiente virtual com barras normais:

```hcl
aws_region        = "us-east-1"
bucket_prefix     = "taotenshin"
python_executable = ".venv/Scripts/python.exe"
```

O nome de cada bucket inclui prefixo, camada, ID da conta AWS e região para
evitar colisões com os nomes globais antigos.

Configure as credenciais no MESMO PowerShell em que executará o Terraform:

```powershell
$env:AWS_ACCESS_KEY_ID = "SUA_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY = "SUA_SECRET_KEY"
$env:AWS_SESSION_TOKEN = "SEU_SESSION_TOKEN"
$env:AWS_DEFAULT_REGION = "us-east-1"
aws sts get-caller-identity
terraform init -reconfigure
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

O token é obrigatório para credenciais temporárias de laboratório/AWS Academy.
Para chaves permanentes sem token, remova um token antigo do terminal com
`Remove-Item Env:AWS_SESSION_TOKEN -ErrorAction SilentlyContinue`.
Também é possível usar `aws configure` e perfis da AWS em vez das variáveis.

As três constantes no início de `scripts/bronze.py` permitem preencher as
credenciais diretamente no script, conforme solicitado. Deixadas vazias, usam
as credenciais do ambiente/perfil. Não faça commit de chaves preenchidas.
Essas constantes autenticam SOMENTE o Python: o Terraform ainda precisa das
credenciais no ambiente ou no perfil. A Lambda usa sua role, não essas chaves.

**State isolado:** o backend local grava em `terraform-datalake.tfstate`, separado
do antigo `terraform.tfstate`. Use `init -reconfigure`, nunca migre o state antigo
para este projeto. Isso não destrói nem desliga recursos antigos já existentes
na AWS; eles continuam sob responsabilidade do state/configuração anteriores.
Guarde o novo state para administrar ou remover o datalake. Se mudar de PC após
o deploy, transfira esse state de forma privada; ele não é enviado ao Git.

Cada `apply` executa novamente a captura/upload, mesmo sem mudanças na AWS.
Os CSVs locais existentes são reutilizados, mas sempre reenviados para disparar
a Lambda. Por isso o `plan` sempre mostra substituição de `terraform_data.capture_bronze`.
Se o download falhar, corrija conexão/credenciais e execute `apply` novamente.

## Conferir Os Resultados

O `apply` termina depois dos uploads, mas não espera a Lambda concluir.
Consulte os resultados e logs quando o processamento terminar:

```powershell
$bronze = terraform output -raw bronze_bucket
$silver = terraform output -raw silver_bucket
$logs = terraform output -raw silver_log_group
aws s3 ls "s3://$bronze/bronze/"
aws s3 ls "s3://$silver/silver/"
aws logs tail $logs --since 1h
aws s3 cp "s3://$silver/silver/" ./dados/silver/ --recursive
```

Para baixar novamente as fontes e repetir o pipeline sem outro `apply`:

```powershell
$bronze = terraform output -raw bronze_bucket
.\.venv\Scripts\python.exe scripts/bronze.py --bucket $bronze --region us-east-1 --refresh
```

Sem `--refresh`, reutiliza o cache local e reenvia os mesmos dois arquivos.
A notificação S3 pode entregar eventos mais de uma vez; a função sobrescreve
as mesmas chaves de saída. Evite execuções simultâneas da captura.
Erros de transformação aparecem no CloudWatch; falhas assíncronas são repetidas
pela AWS e não aparecem como erro no `terraform apply`.

## Testes Locais

Sem acessar AWS ou baixar dados do IBGE:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
terraform fmt -check
terraform validate
```

Esses testes verificam transformações, leitura de largura fixa, cache e upload
com serviços simulados. Não substituem o teste real de permissões, downloads e
tempo de execução da PNS na AWS.

## Remover O Datalake

Os buckets não têm `force_destroy`: esvazie os dados conscientemente antes de remover.
Use as mesmas credenciais, região e state do deploy:

```powershell
$bronze = terraform output -raw bronze_bucket
$silver = terraform output -raw silver_bucket
$gold = terraform output -raw gold_bucket
aws s3 rm "s3://$bronze" --recursive
aws s3 rm "s3://$silver" --recursive
aws s3 rm "s3://$gold" --recursive
terraform destroy
```

AWS pode gerar custos de S3, Lambda, logs e transferência. O `destroy` não remove
recursos da infraestrutura antiga nem o cache local em `dados/`.

## Commits

Use Conventional Commits: `feat: descrição`, `fix: descrição`, `docs: descrição`.
