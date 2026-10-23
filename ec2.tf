# As instancias recebem imagens ja construidas pelo GitHub Actions. Terraform
# provisiona a AWS; nao copia source, dist ou JAR para as EC2.
resource "aws_instance" "frontend_1" {
  ami                         = "ami-0b6d9d3d33ba97d99"
  instance_type               = "t3.small"
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.publica_1.id
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/scripts/bootstrap_frontend.sh.tftpl", {
    frontend_image = var.frontend_image
  })

  tags = {
    Name = "frontend-1"
    Role = "frontend"
  }

  depends_on = [aws_route_table_association.publica_1]
}

resource "aws_instance" "frontend_2" {
  ami                         = "ami-0b6d9d3d33ba97d99"
  instance_type               = "t3.small"
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.publica_2.id
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/scripts/bootstrap_frontend.sh.tftpl", {
    frontend_image = var.frontend_image
  })

  tags = {
    Name = "frontend-2"
    Role = "frontend"
  }

  depends_on = [aws_route_table_association.publica_2]
}

resource "aws_instance" "backend_1" {
  ami                         = "ami-0b6d9d3d33ba97d99"
  instance_type               = "t3.small"
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.backend_1.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/scripts/bootstrap_backend.sh.tftpl", {
    backend_image         = var.backend_image
    filamq_image          = var.filamq_image
    database_init_sql_url = var.database_init_sql_url
    db_host               = aws_db_instance.taotenshin.address
    db_name               = var.db_name
    db_password_b64       = base64encode(var.db_password)
    db_username           = var.db_username
    initialize_database   = true
    jwt_secret_b64        = base64encode(var.jwt_secret)
    twilio_account_sid    = var.twilio_account_sid
    twilio_auth_token     = var.twilio_auth_token
    twilio_phone_number   = var.twilio_phone_number
    twilio_content_sid    = var.twilio_content_sid
  })

  tags = {
    Name = "backend-1"
    Role = "backend"
  }

  depends_on = [
    aws_db_instance.taotenshin,
    aws_route_table_association.backend_1,
    aws_lb.taotenshin,
  ]
}

resource "aws_instance" "backend_2" {
  ami                         = "ami-0b6d9d3d33ba97d99"
  instance_type               = "t3.small"
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.backend_2.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/scripts/bootstrap_backend.sh.tftpl", {
    backend_image         = var.backend_image
    filamq_image          = var.filamq_image
    database_init_sql_url = var.database_init_sql_url
    db_host               = aws_db_instance.taotenshin.address
    db_name               = var.db_name
    db_password_b64       = base64encode(var.db_password)
    db_username           = var.db_username
    initialize_database   = false
    jwt_secret_b64        = base64encode(var.jwt_secret)
    twilio_account_sid    = var.twilio_account_sid
    twilio_auth_token     = var.twilio_auth_token
    twilio_phone_number   = var.twilio_phone_number
    twilio_content_sid    = var.twilio_content_sid
  })

  tags = {
    Name = "backend-2"
    Role = "backend"
  }

  depends_on = [
    aws_db_instance.taotenshin,
    aws_route_table_association.backend_2,
    aws_lb.taotenshin,
  ]
}
