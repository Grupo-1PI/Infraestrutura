# 1. Grupo de subnets utilizado pelo RDS
resource "aws_db_subnet_group" "taotenshin" {
  name = "taotenshin-db-subnet-group"

  subnet_ids = [
    aws_subnet.banco_1.id,
    aws_subnet.banco_2.id
  ]

  tags = {
    Name = "taotenshin-db-subnet-group"
  }
}

# 2. Banco MySQL do projeto
resource "aws_db_instance" "taotenshin" {
  identifier             = "rds-taotenshin-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  port                   = 3306
  db_subnet_group_name   = aws_db_subnet_group.taotenshin.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "rds-taotenshin-db"
  }
}
