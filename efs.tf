# 1. EFS compartilhado
resource "aws_efs_file_system" "efs_taotenshin" {
  tags = {
    Name = "efs-taotenshin"
  }
}

# 2. Mount Target na AZ 1
resource "aws_efs_mount_target" "az_1" {
  file_system_id  = aws_efs_file_system.efs_taotenshin.id
  subnet_id       = aws_subnet.backend_1.id
  security_groups = [aws_security_group.efs.id]
}

# 3. Mount Target na AZ 2
resource "aws_efs_mount_target" "az_2" {
  file_system_id  = aws_efs_file_system.efs_taotenshin.id
  subnet_id       = aws_subnet.backend_2.id
  security_groups = [aws_security_group.efs.id]
}
