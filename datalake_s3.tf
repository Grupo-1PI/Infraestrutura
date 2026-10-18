data "aws_caller_identity" "current" {}

locals {
  bronze_bucket_name = "${var.bucket_prefix}-bronze-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  silver_bucket_name = "${var.bucket_prefix}-silver-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

resource "aws_s3_bucket_public_access_block" "taotenshin_bronze" {
  bucket                  = local.bronze_bucket_name
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [terraform_data.prepare_buckets]
}

resource "aws_s3_bucket_public_access_block" "taotenshin_silver" {
  bucket                  = local.silver_bucket_name
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [terraform_data.prepare_buckets]
}
