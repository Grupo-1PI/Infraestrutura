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

# A API fica no mesmo ALB publico, mas em um target group independente. Isso
# permite que o frontend use a URL relativa /api sem conhecer IPs privados.
resource "aws_lb_target_group" "backend" {
  name        = "tg-taotenshin-backend"
  port        = 8080
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.vpc_taotenshin.id

  health_check {
    path                = "/api/actuator/health"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "tg-taotenshin-backend"
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

resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api", "/api/*"]
    }
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

resource "aws_lb_target_group_attachment" "backend_1" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend_1.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "backend_2" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend_2.id
  port             = 8080
}
