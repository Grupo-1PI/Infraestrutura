output "bronze_bucket" {
  value = aws_s3_bucket.taotenshin_bronze.bucket
}

output "silver_bucket" {
  value = aws_s3_bucket.taotenshin_silver.bucket
}

output "gold_bucket" {
  value = aws_s3_bucket.taotenshin_gold.bucket
}

output "silver_lambda_name" {
  value = aws_lambda_function.silver.function_name
}

output "silver_log_group" {
  value = aws_cloudwatch_log_group.silver.name
}
