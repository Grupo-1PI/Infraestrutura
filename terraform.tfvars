# Copie este arquivo como terraform.tfvars e preencha os valores.
# terraform.tfvars esta no .gitignore e nao deve ser enviado ao Git.

frontend_image       = "allyawada/allyawada/tao-tenshin_front-end:latest"
backend_image        = "allyawada/allyawada/tao-tenshin_back-end:latest"
database_init_sql_url = "https://raw.githubusercontent.com/Grupo-1PI/Banco-de-dados/refs/heads/production/script_completo.sql"

db_name     = "taotenshin"
db_username = "taotenshin"
db_password = "Troque-esta-senha-por-uma-senha-segura"
jwt_secret  = "Coloque-uma-senha-segura-aqui-para-gerar-o-token-jwt"

# Descubra em https://checkip.amazonaws.com e acrescente /32.
ssh_allowed_cidr = "203.0.113.10/32"
key_name         = "vockey"
