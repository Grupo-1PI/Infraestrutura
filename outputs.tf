output "application_url" {
  description = "URL publica da aplicacao. A API fica no mesmo endereco, sob /api."
  value       = "http://${aws_lb.taotenshin.dns_name}"
}

output "rds_endpoint" {
  description = "Endpoint privado do RDS, usado somente para diagnostico administrativo."
  value       = aws_db_instance.taotenshin.address
}

output "frontend_ecr_repository_url" {
  description = "URL do repositorio ECR do frontend."
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_ecr_repository_url" {
  description = "URL do repositorio ECR do backend."
  value       = aws_ecr_repository.backend.repository_url
}
