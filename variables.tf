variable "frontend_image" {
  description = "Imagem completa do frontend publicada no Docker Hub."
  type        = string
}

variable "backend_image" {
  description = "Imagem completa do backend publicada no Docker Hub."
  type        = string
}

variable "db_name" {
  description = "Nome do banco MySQL criado no RDS."
  type        = string
  default     = "taotenshin"
}

variable "db_username" {
  description = "Usuario administrador da aplicacao no RDS."
  type        = string
  default     = "taotenshin"
}

variable "db_password" {
  description = "Senha do RDS. Nao a versione no Git."
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Segredo JWT do backend, em Base64 e com no minimo 32 bytes."
  type        = string
  sensitive   = true
}

variable "database_init_sql_url" {
  description = "URL raw HTTPS do script SQL que inicializa o banco vazio."
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorizado a acessar SSH nos frontends, por exemplo 203.0.113.10/32."
  type        = string
}

variable "key_name" {
  description = "Nome do Key Pair ja criado na AWS."
  type        = string
  default     = "vockey"
}
