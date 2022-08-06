
data "aws_ami" "ami" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "name"
    values = ["vault-${var.vault_version}-*"]
  }

  filter {
    name   = "architecture"
    values = [var.arch]
  }
}


resource "tls_private_key" "key" {
  count     = var.public_key == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key" {
  key_name   = "${local.base_name}-ssh"
  public_key = var.public_key == null ? tls_private_key.key.0.public_key_openssh : var.public_key
}


resource "aws_ssm_parameter" "ssh_key" {
  count  = var.public_key == null ? 1 : 0
  name   = replace("/${local.base_name}/ssh", "-", "/")
  type   = "SecureString"
  value  = tls_private_key.key.0.private_key_pem
  key_id = local.kms_key_id
  tags   = var.extra_tags
}


resource "random_uuid" "uuid" {}


data "template_file" "vault" {
  template = file(format("%s/templates/userdata.tpl", path.module))

  vars = {
    kms_key         = local.kms_key_id
    aws_region      = local.aws_region
    cluster_size    = var.size
    app_name        = format("%s%s%s", var.prefix, var.app_name, var.suffix)
    environment     = var.environment
    uuid            = random_uuid.uuid.result
    vault_domain    = format("%s.%s", local.base_name, var.zone_name)
    vault_telemetry = var.vault_telemetry
    s3_bucket       = local.s3_bucket
    ec2_role_arn    = aws_iam_role.ec2_instance.arn
    lambda_role_arn = aws_iam_role.lambda_role.arn
  }
}

locals {
  tpl_tags = merge(
    var.extra_tags,
    { Uuid = random_uuid.uuid.result },
    { AppName = "${var.prefix}${var.app_name}${var.suffix}" },
    { AppEnv = var.environment }
  )
}

/*
 * Create Launch Template
 */
resource "aws_launch_template" "tpl" {
  name_prefix            = "${local.base_name}-"
  ebs_optimized          = var.ebs_optimized
  image_id               = data.aws_ami.ami.id
  instance_type          = var.instance_type
  user_data              = sensitive(base64encode(data.template_file.vault.rendered))
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_instance.arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 32
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = data.aws_ami.ami.root_device_name
    ebs {
      delete_on_termination = true
      encrypted             = true
      volume_type           = var.root_volume_type
      volume_size           = var.root_volume_size
      kms_key_id            = data.aws_kms_key.by_id.arn
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.tpl_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tpl_tags
  }

  tag_specifications {
    resource_type = "network-interface"
    tags          = local.tpl_tags
  }

  tags = local.tpl_tags
}
/*
 * Create Auto-Scaling Group
 */
resource "aws_autoscaling_group" "asg" {

  name                      = "${local.base_name}-asg"
  vpc_zone_identifier       = var.ec2_subnets
  min_size                  = var.size
  max_size                  = var.size
  desired_capacity          = var.size
  health_check_type         = var.health_check_type
  force_delete              = true
  health_check_grace_period = 60

  default_cooldown     = var.default_cooldown
  termination_policies = var.termination_policies

  launch_template {
    id      = aws_launch_template.tpl.id
    version = aws_launch_template.tpl.latest_version
  }

  enabled_metrics = [
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
  ]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      checkpoint_delay       = 10
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 10
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${local.base_name}-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "Uuid"
    value               = random_uuid.uuid.result
    propagate_at_launch = true
  }

  tag {
    key                 = "AppName"
    value               = "${var.prefix}${var.app_name}${var.suffix}"
    propagate_at_launch = true
  }

  tag {
    key                 = "AppEnv"
    value               = var.environment
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.extra_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  protect_from_scale_in = var.protect_from_scale_in
  target_group_arns     = [aws_alb_target_group.main.arn]
}
