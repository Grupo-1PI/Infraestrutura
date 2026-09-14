# 1. Elastic IP necessario para o NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "taotenshin-nat-eip"
  }
}

# 2. NAT Gateway na primeira subnet publica
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.publica_1.id

  tags = {
    Name = "taotenshin-nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw_taotenshin]
}

# 3. Route Table publica
resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.vpc_taotenshin.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_taotenshin.id
  }

  tags = {
    Name = "taotenshin-public-rt"
  }
}

# 4. Route Table dos backends privados
resource "aws_route_table" "backend" {
  vpc_id = aws_vpc.vpc_taotenshin.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "taotenshin-private-backend-rt"
  }
}

# 5. Route Table das subnets de banco.
resource "aws_route_table" "banco" {
  vpc_id = aws_vpc.vpc_taotenshin.id

  tags = {
    Name = "taotenshin-private-db-rt"
  }
}

# 6. Associacoes das subnets publicas
resource "aws_route_table_association" "publica_1" {
  subnet_id      = aws_subnet.publica_1.id
  route_table_id = aws_route_table.publica.id
}

resource "aws_route_table_association" "publica_2" {
  subnet_id      = aws_subnet.publica_2.id
  route_table_id = aws_route_table.publica.id
}

# 7. Associacoes das subnets de backend
resource "aws_route_table_association" "backend_1" {
  subnet_id      = aws_subnet.backend_1.id
  route_table_id = aws_route_table.backend.id
}

resource "aws_route_table_association" "backend_2" {
  subnet_id      = aws_subnet.backend_2.id
  route_table_id = aws_route_table.backend.id
}

# 8. Associacoes das subnets de banco
resource "aws_route_table_association" "banco_1" {
  subnet_id      = aws_subnet.banco_1.id
  route_table_id = aws_route_table.banco.id
}

resource "aws_route_table_association" "banco_2" {
  subnet_id      = aws_subnet.banco_2.id
  route_table_id = aws_route_table.banco.id
}
