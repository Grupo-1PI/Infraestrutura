data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_ecr_repository" "frontend" {
  name                 = var.frontend_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = var.backend_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

locals {
  ecr_registry   = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
  frontend_image = "${aws_ecr_repository.frontend.repository_url}:${var.image_tag}"
  backend_image  = "${aws_ecr_repository.backend.repository_url}:${var.image_tag}"
}

resource "aws_iam_role" "ec2_ecr_pull" {
  name = "taotenshin-ec2-ecr-pull"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_ecr_pull" {
  name = "taotenshin-ecr-pull"
  role = aws_iam_role.ec2_ecr_pull.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:GetDownloadUrlForLayer",
        "ecr:ListImages"
      ]
      Resource = [
        aws_ecr_repository.frontend.arn,
        aws_ecr_repository.backend.arn
      ]
      }, {
      Effect   = "Allow"
      Action   = ["ecr:GetAuthorizationToken"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_ecr_pull" {
  name = "taotenshin-ec2-ecr-pull"
  role = aws_iam_role.ec2_ecr_pull.name
}