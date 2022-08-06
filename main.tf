data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "kms_key_policy_document" {

  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    actions = [
      "kms:*",
    ]

    resources = [
      "*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid    = "Allow EC2 to use KMS"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = [
      "*",
    ]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ec2_instance.arn]
    }
  }


  statement {
    sid    = "Allow use of the key for logs"
    effect = "Allow"

    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = [
      "*",
    ]
    principals {
      type        = "Service"
      identifiers = ["logs.${local.aws_region}.amazonaws.com"]
    }
  }

  statement {
    sid    = "Allow attachment of persistent resources"
    effect = "Allow"

    actions = [
      "kms:CreateGrant"
    ]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }

    resources = ["*", ]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      ]
    }
  }

  statement {
    sid    = "Allow service-linked role use of the customer managed key"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      ]
    }
  }
}

resource "aws_iam_service_linked_role" "asg_service_role" {
  count            = var.create_asg_service_linked_role ? 1 : 0
  aws_service_name = "autoscaling.amazonaws.com"
}

resource "aws_kms_key" "key" {
  count                   = var.kms_key_id == "" ? 1 : 0
  description             = "${local.base_name}-kms"
  policy                  = data.aws_iam_policy_document.kms_key_policy_document.json
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-kms"
    },
  )
}

resource "aws_kms_alias" "key" {
  count         = var.kms_key_id == "" ? 1 : 0
  name          = "alias/${local.base_name}-kms"
  target_key_id = aws_kms_key.key[0].key_id
}

data "aws_kms_key" "by_id" {
  key_id = local.kms_key_id
}

resource "aws_cloudwatch_log_group" "logs" {
  for_each          = toset(["vaultaudit", "secure", "messages"])
  name              = "${local.base_name}-${each.key}"
  retention_in_days = 90

  kms_key_id = data.aws_kms_key.by_id.arn

  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-${each.key}"
    },
  )
}



resource "aws_ssm_parameter" "vault_backup" {
  name   = replace("/${local.base_name}/sys/last_backup", "-", "/")
  type   = "SecureString"
  value  = "-"
  key_id = local.kms_key_id
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

resource "aws_ssm_parameter" "vault_init" {
  name   = replace("/${local.base_name}/root/init", "-", "/")
  type   = "SecureString"
  value  = "init"
  key_id = local.kms_key_id
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

resource "aws_ssm_parameter" "root_token" {
  name   = replace("/${local.base_name}/root/token", "-", "/")
  type   = "SecureString"
  value  = "init"
  key_id = local.kms_key_id
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

resource "aws_ssm_parameter" "admin_pass" {
  name   = replace("/${local.base_name}/admin/pass", "-", "/")
  type   = "SecureString"
  value  = "init"
  key_id = local.kms_key_id
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
