data "archive_file" "silver" {
  type        = "zip"
  source_file = "${path.module}/scripts/silver.py"
  output_path = "${path.module}/.terraform/silver_lambda.zip"
}

resource "aws_iam_role" "silver" {
  name_prefix = "${var.bucket_prefix}-silver-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "silver_logs" {
  role       = aws_iam_role.silver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "silver_s3" {
  role = aws_iam_role.silver.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.taotenshin_bronze.arn}/bronze/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:AbortMultipartUpload"]
        Resource = "${aws_s3_bucket.taotenshin_silver.arn}/silver/*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "silver" {
  name              = "/aws/lambda/${var.bucket_prefix}-bronze-to-silver"
  retention_in_days = 7
}

resource "aws_lambda_function" "silver" {
  function_name    = "${var.bucket_prefix}-bronze-to-silver"
  role             = aws_iam_role.silver.arn
  runtime          = "python3.12"
  handler          = "silver.lambda_handler"
  filename         = data.archive_file.silver.output_path
  source_code_hash = data.archive_file.silver.output_base64sha256
  timeout          = 900
  memory_size      = 1024

  ephemeral_storage {
    size = 2048
  }

  environment {
    variables = {
      BRONZE_BUCKET           = aws_s3_bucket.taotenshin_bronze.bucket
      SILVER_BUCKET           = aws_s3_bucket.taotenshin_silver.bucket
      BUCKET_OWNER_ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
  }

  depends_on = [
    aws_iam_role_policy.silver_s3,
    aws_iam_role_policy_attachment.silver_logs,
    aws_cloudwatch_log_group.silver,
  ]
}

resource "aws_lambda_permission" "bronze" {
  statement_id   = "AllowBronzeS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.silver.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.taotenshin_bronze.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "bronze" {
  bucket = aws_s3_bucket.taotenshin_bronze.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.silver.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "bronze/"
  }

  depends_on = [aws_lambda_permission.bronze]
}

resource "terraform_data" "capture_bronze" {
  triggers_replace = [timestamp()]

  provisioner "local-exec" {
    command = "\"${var.python_executable}\" \"${path.module}/scripts/bronze.py\" --bucket ${aws_s3_bucket.taotenshin_bronze.bucket} --region ${var.aws_region}"
  }

  depends_on = [aws_s3_bucket_notification.bronze]
}