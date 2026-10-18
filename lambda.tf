data "archive_file" "silver" {
  type        = "zip"
  source_file = "${path.module}/scripts/silver.py"
  output_path = "${path.module}/.terraform/silver_lambda.zip"
}

data "aws_iam_role" "lambda_execution" {
  name = "LabRole"
}

resource "aws_cloudwatch_log_group" "silver" {
  name              = "/aws/lambda/${var.bucket_prefix}-bronze-to-silver"
  retention_in_days = 7
}

resource "aws_lambda_function" "silver" {
  function_name    = "${var.bucket_prefix}-bronze-to-silver"
  role             = data.aws_iam_role.lambda_execution.arn
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
      BRONZE_BUCKET           = local.bronze_bucket_name
      SILVER_BUCKET           = local.silver_bucket_name
      BUCKET_OWNER_ACCOUNT_ID = data.aws_caller_identity.current.account_id
    }
  }

  depends_on = [aws_cloudwatch_log_group.silver]
}

resource "aws_lambda_permission" "bronze" {
  statement_id   = "AllowBronzeS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.silver.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = "arn:aws:s3:::${local.bronze_bucket_name}"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "bronze" {
  bucket = local.bronze_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.silver.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "bronze/"
  }

  depends_on = [
    aws_lambda_permission.bronze,
    aws_s3_bucket_public_access_block.taotenshin_bronze,
    aws_s3_bucket_public_access_block.taotenshin_silver,
  ]
}

resource "terraform_data" "capture_and_upload_bronze" {
  triggers_replace = [timestamp()]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-Command"]
    command     = "& \"${path.module}/.venv/Scripts/python.exe\" \"${path.module}/scripts/bronze.py\" --bucket \"${local.bronze_bucket_name}\" --region \"${var.aws_region}\""
  }

  depends_on = [aws_s3_bucket_notification.bronze]
}

resource "terraform_data" "prepare_buckets" {
  triggers_replace = [timestamp()]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = "Stop"
      $project = "${path.module}"
      $python = (Get-Command "${var.python_executable}" -ErrorAction Stop).Source
      $venv = Join-Path $project ".venv"
      $venvPython = Join-Path $venv "Scripts\python.exe"
      $recreateVenv = -not (Test-Path -LiteralPath $venvPython)
      if (-not $recreateVenv) {
        & $venvPython -c "import boto3, pandas, requests"
        $recreateVenv = $LASTEXITCODE -ne 0
      }
      if ($recreateVenv) {
        Write-Output "Criando um ambiente virtual Python limpo e compativel."
        & $python -m venv --clear $venv
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
      }
      if (-not (Test-Path -LiteralPath $venvPython)) {
        & $python -m venv $venv
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
      }
      & $venvPython -m pip install --disable-pip-version-check -r (Join-Path $project "requirements.txt")
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
      & $venvPython (Join-Path $project "scripts\bootstrap_buckets.py") --region "${var.aws_region}" --bronze-bucket "${local.bronze_bucket_name}" --silver-bucket "${local.silver_bucket_name}"
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    EOT
  }
}