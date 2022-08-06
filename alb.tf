resource "aws_alb" "main" {

  name = "${local.base_name}-alb"

  internal        = var.internal
  subnets         = var.lb_subnets
  security_groups = [aws_security_group.alb_sg.id]

  access_logs {
    bucket  = aws_s3_bucket.bucket.id
    prefix  = "alb_access_logs"
    enabled = false #to be fixed
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-alb"
    },
  )
  depends_on = [aws_s3_bucket_policy.s3_alb_logs]
}

resource "aws_alb_listener" "main" {

  load_balancer_arn = aws_alb.main.id
  port              = 8200
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.vault.certificate_arn
  ssl_policy        = var.alb_ssl_policy

  default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "forward"
  }
}

resource "aws_alb_listener" "https" {

  load_balancer_arn = aws_alb.main.id
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.vault.certificate_arn
  ssl_policy        = var.alb_ssl_policy

  default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "forward"
  }
}



resource "aws_alb_listener" "redirect_http_to_https" {
  load_balancer_arn = aws_alb.main.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      host        = "${local.base_name}.${data.aws_route53_zone.zone.name}"
      port        = "8200"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


resource "aws_alb_target_group" "main" {
  name_prefix = "vault-"

  port        = 8200
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 5
    matcher             = "200,429"
    path                = "/v1/sys/health"
    port                = "traffic-port"
    protocol            = "HTTPS"
    timeout             = 2
    unhealthy_threshold = 2
  }

  stickiness {
    cookie_duration = 3600
    enabled         = true
    type            = "lb_cookie"
  }

  deregistration_delay = 15

  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-tg"
    },
  )

}
