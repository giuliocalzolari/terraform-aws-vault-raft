resource "aws_security_group" "lambda_sg" {

  name        = "${local.base_name}-lambda-sg"
  description = "${local.base_name}-lambda-sg"

  vpc_id = var.vpc_id

  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-lambda-sg"
    },
  )
}

resource "aws_security_group_rule" "lambda_egress_rule" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda_sg.id
}

// ALB
resource "aws_security_group" "alb_sg" {

  name        = "${local.base_name}-alb-sg"
  description = "${local.base_name}-alb-sg"

  vpc_id = var.vpc_id

  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-alb-sg"
    },
  )
}


resource "aws_security_group_rule" "alb_http_rule" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  description       = "HTTP redirect"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "alb_https_rule" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  description       = "HTTPs"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "alb_vault_rule" {
  type              = "ingress"
  from_port         = 8200
  to_port           = 8200
  protocol          = "tcp"
  description       = "Vaul HTTPs"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "alb_egress_rule" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.ec2.id
  security_group_id        = aws_security_group.alb_sg.id
}




// ec2_sg
resource "aws_security_group" "ec2" {
  name        = "${local.base_name}-sg"
  description = "${local.base_name}-sg"
  vpc_id      = var.vpc_id

  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-sg"
    },
  )
}

resource "aws_security_group_rule" "asg_vault_rule" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  description              = "ALB Vault port"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "lambda_asg_vault_rule" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "tcp"
  description              = "Lambda Vault port"
  source_security_group_id = aws_security_group.lambda_sg.id
  security_group_id        = aws_security_group.ec2.id
}


resource "aws_security_group_rule" "vault_node_ig" {
  security_group_id = aws_security_group.ec2.id
  type              = "ingress"
  from_port         = 8200
  protocol          = "tcp"
  self              = true
  to_port           = 8201
  description       = "Internal Vault communications"
}



resource "aws_security_group_rule" "asg_egress_rule" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "asg_ssh_admin_rule" {
  count             = var.admin_cidr_blocks == [] ? 0 : 1
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  description       = "Admin SSH ASG"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group_rule" "asg_app_admin_rule" {
  count             = var.admin_cidr_blocks == [] ? 0 : 1
  type              = "ingress"
  from_port         = 8200
  to_port           = 8600
  protocol          = "tcp"
  description       = "Admin App Access ASG"
  cidr_blocks       = var.admin_cidr_blocks
  security_group_id = aws_security_group.ec2.id
}
