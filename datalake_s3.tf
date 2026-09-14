# 1. Bucket S3 - Bronze
resource "aws_s3_bucket" "taotenshin_bronze" {

  bucket = "taotenshin-bronze-dev-local"

  tags = {
    Name = "taotenshin-bronze-dev-local"
  }
}

# 2. Bucket S3 - Silver
resource "aws_s3_bucket" "taotenshin_silver" {

  bucket = "taotenshin-silver-dev-local"

  tags = {
    Name = "taotenshin-silver-dev-local"
  }
}

# 3. Bucket S3 - Gold
resource "aws_s3_bucket" "taotenshin_gold" {

  bucket = "taotenshin-gold-dev-local"

  tags = {
    Name = "taotenshin-gold-dev-local"
  }
}