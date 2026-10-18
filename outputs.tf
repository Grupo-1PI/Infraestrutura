output "bronze_bucket" {
  value = local.bronze_bucket_name
}

output "silver_bucket" {
  value = local.silver_bucket_name
}

output "silver_lambda_name" {
  value = aws_lambda_function.silver.function_name
}

output "silver_log_group" {
  value = aws_cloudwatch_log_group.silver.name
}
