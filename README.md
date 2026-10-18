# Datalake IBGE: Bronze → Silver

Branch `feature/20261016/implementando-lambda` contém somente o fluxo do
datalake: buckets Bronze/Silver, bloqueio de acesso público, Lambda acionada
por evento S3 e scripts da captura e transformação. A role existente
`LabRole` é usada pela Lambda; não há VPC, EC2, ALB, EFS ou RDS nesta branch.

## Executar em um computador novo (Windows)

Pré-requisitos instalados: Git, Terraform >= 1.4, Python >= 3.10 e AWS CLI v2.
O apply precisa de internet, alguns GB livres para os microdados da PNS e uma
conta AWS autorizada. A `LabRole` precisa permitir `s3:GetObject` no prefixo
`bronze/`, `s3:PutObject` no prefixo `silver/` e gravação de logs CloudWatch.

No PowerShell:

```powershell
git clone --branch feature/20261016/implementando-lambda https://github.com/Grupo-1PI/Infraestrutura.git
Set-Location Infraestrutura
aws configure
aws sts get-caller-identity
terraform init
terraform apply
```

`aws configure` pede as credenciais e a região. Use `us-east-1`, que é o padrão
do projeto; para credenciais temporárias do laboratório, configure também o
session token. Não envie nem versione credenciais.

O `terraform apply` faz o fluxo completo:

1. Prepara `.venv`, verifica que as dependências importam corretamente e
   recria o ambiente se ele estiver incompatível; instala `requirements.txt`.
2. Cria ou reutiliza os buckets com nomes que incluem prefixo, ID da conta e
   região, aplicando bloqueio de acesso público.
3. Configura a Lambda e a notificação de objetos criados sob `bronze/`.
4. Executa `scripts/bronze.py` localmente: baixa/reutiliza os CSVs do Censo e
   da PNS e envia `censo_bronze.csv` e `pns_bronze.csv` para Bronze.
5. Cada upload aciona a Lambda de forma assíncrona; ela transforma os CSVs e
   grava `censo_silver.csv` e `pns_silver.csv` em Silver.

O apply espera os downloads e uploads para Bronze, mas não espera a Lambda
terminar. Consulte os logs depois de alguns instantes:

Se um `.venv` antigo estiver incompatível com a versão do Python instalada, o
bootstrap o recria automaticamente antes da captura.

```powershell
$logs = terraform output -raw silver_log_group
aws logs tail $logs --since 10m
```

Cada novo `terraform apply` reenvia os dados e aciona a transformação novamente.
Os CSVs baixados ficam em `dados/bronze/` e são reutilizados nos próximos
applies, a menos que se use `--refresh` manualmente.

## Configuração e segurança

Região, prefixo dos buckets e executável Python podem ser ajustados em
`terraform.tfvars`; os padrões (`us-east-1`, `taotenshin` e `python`) funcionam
para o fluxo documentado. Os buckets são privados. O script local usa as
credenciais do AWS CLI; a Lambda usa `LabRole`.

`terraform-datalake.tfstate`, `.terraform/`, `.venv/`, `terraform.tfvars` e os
dados locais são ignorados pelo Git. O state contém identificadores de recursos
e deve ser guardado em segurança. Se já houver um deploy na mesma conta, use o
state correspondente em vez de aplicar com um state novo, para evitar conflito
com recursos já existentes.

## Testes locais

Depois do primeiro apply, os testes podem ser executados sem chamadas à AWS:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
terraform fmt -check
terraform validate
```

## Remover recursos gerenciados

O Terraform não destrói os buckets nem seus dados. O comando abaixo remove os
recursos Lambda, notificação, bloqueios públicos e logs que estão no state:

```powershell
terraform destroy
```

Os buckets e os dados permanecem na conta. Remova-os separadamente somente se
tiver certeza de que não são usados por outro fluxo.
