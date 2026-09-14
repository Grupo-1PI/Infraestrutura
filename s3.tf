# 1. Bucket S3 utilizado pelo projeto
resource "aws_s3_bucket" "taotenshin" {
  bucket = "taotenshin-dev-local"

  tags = {
    Name = "taotenshin-dev-local"
  }
}

# 2. Endpoint Gateway para acesso ao S3 pela VPC
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc_taotenshin.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.backend.id,
    aws_route_table.banco.id
  ]

  tags = {
    Name = "taotenshin-s3-gateway-endpoint"
  }
}
