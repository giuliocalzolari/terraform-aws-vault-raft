resource "aws_autoscaling_lifecycle_hook" "ec2terminate" {
  name                   = "ec2terminate"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  default_result         = "ABANDON"
  heartbeat_timeout      = 60
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"
}

resource "aws_cloudwatch_event_rule" "asg_cw_rule" {
  name = "${local.base_name}-rule"

  description = "${local.base_name} CW Rule Node delete"

  event_pattern = <<EOF
{
  "source": ["aws.autoscaling"],
  "detail-type": [
    "EC2 Instance-terminate Lifecycle Action",
    "EC2 Instance Terminate Successful"
  ],
  "detail": {
    "AutoScalingGroupName": ["${aws_autoscaling_group.asg.name}"]
  }
}
EOF
  tags = merge(
    var.extra_tags,
    {
      "Name" = "${local.base_name}-rule"
    }
  )

}


resource "aws_iam_role" "cw_role" {
  name               = "${local.base_name}-cw-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.cw.json
  tags = merge(
    var.extra_tags,
    {
      "Name" = "${local.base_name}-cw-role"
    }
  )
}


data "aws_iam_policy_document" "cw" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}


data "aws_iam_policy_document" "cw_role_policy" {

  statement {
    effect = "Allow"
    actions = [
      "ssm:DescribeInstanceInformation",
      "ssm:ListCommands",
      "ssm:ListCommandInvocations"
    ]
    resources = [
      "*"
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["autoscaling:CompleteLifecycleAction"]
    resources = [
      aws_autoscaling_group.asg.arn
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ssm:${local.aws_region}::document/AWS-RunShellScript",
    ]
  }

  statement {
    effect  = "Allow"
    actions = ["ssm:SendCommand"]
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Uuid"
      values   = [random_uuid.uuid.result]
    }

    resources = [
      "arn:aws:ec2:${local.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*",
    ]
  }
}


resource "aws_iam_role_policy" "cw_role_policy" {
  name   = "${local.base_name}-cw-role-policy"
  role   = aws_iam_role.cw_role.id
  policy = data.aws_iam_policy_document.cw_role_policy.json
}


resource "aws_cloudwatch_event_target" "event_target" {
  target_id = local.base_name
  arn       = "arn:aws:ssm:${local.aws_region}::document/AWS-RunShellScript"
  rule      = aws_cloudwatch_event_rule.asg_cw_rule.name
  role_arn  = aws_iam_role.cw_role.arn

  run_command_targets {
    key    = "tag:Uuid"
    values = [random_uuid.uuid.result]
  }

  input = "{\"commands\":[\"/opt/vault/bin/raft-backup\"],\"executionTimeout\":[\"60\"]}"
}
