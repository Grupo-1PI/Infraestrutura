# Copie este arquivo como terraform.tfvars e preencha os valores.
# terraform.tfvars esta no .gitignore e nao deve ser enviado ao Git.

frontend_image       = "allyawada/tao-tenshin_front-end:latest"
backend_image        = "allyawada/tao-tenshin_back-end:latest"
saas_image           = "allyawada/tao-tenshin_rabbitmq:latest"
database_init_sql_url = "https://raw.githubusercontent.com/Grupo-1PI/Banco-de-dados/refs/heads/production/script_completo.sql"

db_name     = "taotenshin"
db_username = "taotenshin"
db_password = "TaoTenshin2026SenhaForte123"
jwt_secret  = "TaoTenshinJWT2026SenhaSeguraComMaisDe32Chars"

twilio_account_sid   = "AC224b79c9f89971ecbe44269d1d305153"
twilio_auth_token    = "5ff93689b8f909ffdffd9a706c01bd2b"
twilio_phone_number  = "+17372508034"
twilio_content_sid   = "HXfe5ab5f00277942d4d4200328b4d403c"

# Descubra em https://checkip.amazonaws.com e acrescente /32.
ssh_allowed_cidr = "203.0.113.10/32"
key_name         = "vockey"
