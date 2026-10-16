data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "taotenshin_bronze" {
  bucket = "${var.bucket_prefix}-bronze-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Layer = "raw-bronze"
  }
}

resource "aws_s3_bucket" "taotenshin_silver" {
  bucket = "${var.bucket_prefix}-silver-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Layer = "trusted-silver"
  }
}

resource "aws_s3_bucket" "taotenshin_gold" {
  bucket = "${var.bucket_prefix}-gold-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  tags = {
    Layer = "gold"
  }
}