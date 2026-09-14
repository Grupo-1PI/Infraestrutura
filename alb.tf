# 1. Application Load Balancer publico
resource "aws_lb" "taotenshin" {
  name               = "alb-taotenshin"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.publica_1.id,
    aws_subnet.publica_2.id
  ]

  tags = {
    Name = "alb-taotenshin"
  }

  depends_on = [
    aws_route_table_association.publica_1,
    aws_route_table_association.publica_2
  ]
}

# 2. Target Group dos frontends
resource "aws_lb_target_group" "frontend" {
  name        = "tg-taotenshin-frontend"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.vpc_taotenshin.id

  tags = {
    Name = "tg-taotenshin-frontend"
  }
}

# 3. Listener HTTP do ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.taotenshin.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# 4. Registro dos dois frontends no Target Group
resource "aws_lb_target_group_attachment" "frontend_1" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "frontend_2" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend_2.id
  port             = 80
}
