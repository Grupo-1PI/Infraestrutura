# 1. Security Group do ALB
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Permite HTTP publico para o ALB"
  vpc_id      = aws_vpc.vpc_taotenshin.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# 2. Security Group dos frontends
resource "aws_security_group" "frontend" {
  name        = "frontend-sg"
  description = "Permite HTTP do ALB e SSH administrativo"
  vpc_id      = aws_vpc.vpc_taotenshin.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "frontend-sg"
  }
}

# 3. Security Group dos backends
resource "aws_security_group" "backend" {
  name        = "backend-sg"
  description = "Permite API exclusivamente do ALB e SSH dentro da VPC"
  vpc_id      = aws_vpc.vpc_taotenshin.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_taotenshin.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-sg"
  }
}

# 4. Security Group do RDS
resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Permite MySQL apenas dos backends"
  vpc_id      = aws_vpc.vpc_taotenshin.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# 5. Security Group do EFS
resource "aws_security_group" "efs" {
  name        = "efs-sg"
  description = "Permite NFS apenas dos frontends"
  vpc_id      = aws_vpc.vpc_taotenshin.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-sg"
  }
}
