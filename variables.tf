variable "aws_region" {
  description = "Regiao dos buckets e da Lambda."
  type        = string
  default     = "us-east-1"
}

variable "bucket_prefix" {
  description = "Prefixo dos buckets Bronze e Silver; conta e regiao sao acrescentadas ao nome."
  type        = string
  default     = "taotenshin"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,14}[a-z0-9]$", var.bucket_prefix))
    error_message = "Use de 3 a 16 caracteres: letras minusculas, numeros e hifens; sem hifens nas pontas."
  }
}

variable "python_executable" {
  description = "Comando do Python instalado localmente, usado para preparar o ambiente virtual."
  type        = string
  default     = "python"
}
