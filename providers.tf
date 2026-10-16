terraform {
  backend "local" {
    path = "terraform-datalake.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  required_version = ">= 1.4.0"
}

provider "aws" {
  region = var.aws_region
}
