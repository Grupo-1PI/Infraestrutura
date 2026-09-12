# 1. Frontend publico na primeira Availability Zone
resource "aws_instance" "frontend_1" {
  ami                         = "ami-0b6d9d3d33ba97d99"
  instance_type               = "t3.micro"
  key_name                    = "vockey"
  subnet_id                   = aws_subnet.publica_1.id
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  associate_public_ip_address = true

  tags = {
    Name = "frontend-1"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./vockey.pem")
    host        = self.public_ip
  }

  # Mesmo modelo da aula: cria as pastas antes de enviar os arquivos.
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ubuntu/scripts"
    ]
  }

  provisioner "file" {
    source      = "./scripts/"
    destination = "/home/ubuntu/scripts/"
  }

  # Instala Docker, monta o EFS e inicia o frontend.
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/scripts/*.sh",
      "cd /home/ubuntu/scripts && bash instalacoes.sh",
      "sudo apt-get install -y nfs-common",
      "sudo mkdir -p /mnt/taotenshin",
      "sudo mount -t nfs4 -o nfsvers=4.1 ${aws_efs_file_system.efs_taotenshin.id}.efs.us-east-1.amazonaws.com:/ /mnt/taotenshin",
      "sudo docker pull nginx:stable",
      "sudo docker rm -f taotenshin-frontend || true",
      "sudo docker run -d --restart unless-stopped --name taotenshin-frontend -p 80:80 -v /mnt/taotenshin:/mnt/taotenshin nginx:stable"
    ]
  }

  provisioner "file" {
    source      = "./vockey.pem"
  # Como no exemplo da aula, a instancia publica usa a chave para acessar
  # as instancias privadas e iniciar o backend nelas.
    destination = "/home/ubuntu/vockey.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/ubuntu/vockey.pem",
      "ssh -i /home/ubuntu/vockey.pem -o StrictHostKeyChecking=no ubuntu@${aws_instance.backend_1.private_ip} 'until command -v docker >/dev/null 2>&1; do sleep 5; done; sudo docker pull nginx:stable; sudo docker rm -f taotenshin-backend || true; sudo docker run -d --restart unless-stopped --name taotenshin-backend -p 8080:8080 -e DB_HOST=${aws_db_instance.taotenshin.address} -e DB_PORT=3306 -e DB_NAME=taotenshin -e DB_USERNAME=taotenshin nginx:stable'",
      "ssh -i /home/ubuntu/vockey.pem -o StrictHostKeyChecking=no ubuntu@${aws_instance.backend_2.private_ip} 'until command -v docker >/dev/null 2>&1; do sleep 5; done; sudo docker pull nginx:stable; sudo docker rm -f taotenshin-backend || true; sudo docker run -d --restart unless-stopped --name taotenshin-backend -p 8080:8080 -e DB_HOST=${aws_db_instance.taotenshin.address} -e DB_PORT=3306 -e DB_NAME=taotenshin -e DB_USERNAME=taotenshin nginx:stable'"
    ]
  }

  depends_on = [
    aws_route_table_association.publica_1,
    aws_efs_mount_target.az_1,
    aws_efs_mount_target.az_2
  ]
}

# 2. Frontend publico na segunda Availability Zone
resource "aws_instance" "frontend_2" {
  ami                         = "ami-0b6d9d3d33ba97d99"
  instance_type               = "t3.micro"
  key_name                    = "vockey"
  subnet_id                   = aws_subnet.publica_2.id
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  associate_public_ip_address = true

  tags = {
    Name = "frontend-2"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./vockey.pem")
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ubuntu/scripts"
    ]
  }

  provisioner "file" {
    source      = "./scripts/"
    destination = "/home/ubuntu/scripts/"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ubuntu/scripts/*.sh",
      "cd /home/ubuntu/scripts && bash instalacoes.sh",
      "sudo apt-get install -y nfs-common",
      "sudo mkdir -p /mnt/taotenshin",
      "sudo mount -t nfs4 -o nfsvers=4.1 ${aws_efs_file_system.efs_taotenshin.id}.efs.us-east-1.amazonaws.com:/ /mnt/taotenshin",
      "sudo docker pull nginx:stable",
      "sudo docker rm -f taotenshin-frontend || true",
      "sudo docker run -d --restart unless-stopped --name taotenshin-frontend -p 80:80 -v /mnt/taotenshin:/mnt/taotenshin nginx:stable"
    ]
  }

  depends_on = [
    aws_route_table_association.publica_2,
    aws_efs_mount_target.az_1,
    aws_efs_mount_target.az_2
  ]
}

# 3. Backend privado na primeira Availability Zone
resource "aws_instance" "backend_1" {
  ami                         = "ami-0b6d9d3d33ba97d99"
  instance_type               = "t3.micro"
  key_name                    = "vockey"
  subnet_id                   = aws_subnet.backend_1.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = false

  user_data = file("./scripts/instalar_docker.sh")

  tags = {
    Name = "backend-1"
  }

  depends_on = [aws_route_table_association.backend_1]
}

# 4. Backend privado na segunda Availability Zone
resource "aws_instance" "backend_2" {
  ami                         = "ami-0b6d9d3d33ba97d99"
  instance_type               = "t3.micro"
  key_name                    = "vockey"
  subnet_id                   = aws_subnet.backend_2.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = false

  user_data = file("./scripts/instalar_docker.sh")

  tags = {
    Name = "backend-2"
  }

  depends_on = [aws_route_table_association.backend_2]
}
