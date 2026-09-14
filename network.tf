# 1. VPC principal do projeto
resource "aws_vpc" "vpc_taotenshin" {
  cidr_block           = "10.0.0.0/21"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-taotenshin"
  }
}

# 2. Subnets publicas
resource "aws_subnet" "publica_1" {
  vpc_id                  = aws_vpc.vpc_taotenshin.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "publica_2" {
  vpc_id                  = aws_vpc.vpc_taotenshin.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2"
  }
}

# 3. Subnets privadas dos backends
resource "aws_subnet" "backend_1" {
  vpc_id            = aws_vpc.vpc_taotenshin.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-backend-subnet-1"
  }
}

resource "aws_subnet" "backend_2" {
  vpc_id            = aws_vpc.vpc_taotenshin.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-backend-subnet-2"
  }
}

# 4. Subnets privadas do banco
resource "aws_subnet" "banco_1" {
  vpc_id            = aws_vpc.vpc_taotenshin.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-db-subnet-1"
  }
}

resource "aws_subnet" "banco_2" {
  vpc_id            = aws_vpc.vpc_taotenshin.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-db-subnet-2"
  }
}

# 5. Internet Gateway
resource "aws_internet_gateway" "igw_taotenshin" {
  vpc_id = aws_vpc.vpc_taotenshin.id

  tags = {
    Name = "taotenshin-igw"
  }
}
