resource "aws_sns_topic" "topic" {
  name              = "${local.base_name}-sns"
  kms_master_key_id = data.aws_kms_key.by_id.arn
  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-sns"
    },
  )
}


resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }

    resources = [aws_sns_topic.topic.arn]
  }
}

resource "aws_sns_topic_subscription" "topic_email_subscription" {
  for_each  = toset(var.sns_email)
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "email"
  endpoint  = each.key
}

resource "aws_cloudwatch_metric_alarm" "vault_raft_backup" {
  alarm_name          = "${local.base_name}-BackupError"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "vault_raft_backup_to_s3"
  namespace           = format("%s-n", local.base_name)
  period              = 3600
  statistic           = "Average"
  threshold           = "0.9"
  alarm_description   = "Backup not executed"
  alarm_actions       = [aws_sns_topic.topic.arn]
  ok_actions          = [aws_sns_topic.topic.arn]

  dimensions = {
    "metric_type" = "gauge"
  }
}

resource "aws_cloudwatch_metric_alarm" "vault_core_unsealed" {
  alarm_name          = "${local.base_name}-CoreUnsealed"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = format("vault_core_unsealed_%s", local.base_name)
  namespace           = format("%s-n", local.base_name)
  period              = 300
  statistic           = "Average"
  threshold           = "0.9"
  alarm_description   = "Node NOT Unsealed"
  alarm_actions       = [aws_sns_topic.topic.arn]
  ok_actions          = [aws_sns_topic.topic.arn]

  dimensions = {
    "metric_type" = "gauge"
  }

  tags = var.extra_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_alarm" {
  alarm_name          = "${local.base_name}-LambdaError"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 600
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.topic.arn]
  ok_actions          = [aws_sns_topic.topic.arn]
  dimensions = {
    FunctionName = aws_lambda_function.main.function_name
  }

  tags = var.extra_tags
}



resource "aws_cloudwatch_metric_alarm" "asg_alarm_inservice" {
  alarm_name          = "${local.base_name}-InServiceInstances"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Average"
  threshold           = var.size
  alarm_actions       = [aws_sns_topic.topic.arn]
  ok_actions          = [aws_sns_topic.topic.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  tags = var.extra_tags
}


resource "aws_cloudwatch_metric_alarm" "httpcode_target_5xx_count" {
  alarm_name          = "${local.base_name}-TG-high5XXCount"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_description   = "Average API 5XX target group error code count is too high"
  alarm_actions       = [aws_sns_topic.topic.arn]
  ok_actions          = [aws_sns_topic.topic.arn]

  dimensions = {
    "TargetGroup"  = aws_alb_target_group.main.arn_suffix
    "LoadBalancer" = aws_alb.main.arn_suffix
  }

  tags = var.extra_tags
}

resource "aws_cloudwatch_metric_alarm" "httpcode_lb_5xx_count" {
  alarm_name          = "${local.base_name}-LB-high5XXCount"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 600
  statistic           = "Sum"
  threshold           = "0"
  treat_missing_data  = "notBreaching"
  alarm_description   = "Average API 5XX load balancer error code count is too high"
  alarm_actions       = [aws_sns_topic.topic.arn]
  ok_actions          = [aws_sns_topic.topic.arn]

  dimensions = {
    "LoadBalancer" = aws_alb.main.arn_suffix
  }

  tags = var.extra_tags
}

resource "aws_cloudwatch_metric_alarm" "target_response_time_average" {
  alarm_name          = "${local.base_name}-highResponseTime"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 600
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "Average API response time is too high"
  alarm_actions       = [aws_sns_topic.topic.arn]
  ok_actions          = [aws_sns_topic.topic.arn]

  dimensions = {
    "TargetGroup"  = aws_alb_target_group.main.arn_suffix
    "LoadBalancer" = aws_alb.main.arn_suffix
  }

  tags = var.extra_tags
}



resource "aws_cloudwatch_metric_alarm" "alb_unhealty_host" {
  alarm_name          = "${local.base_name}-UnHealthyHostCount"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "ALB UnHealthyHostCount"
  alarm_actions       = [aws_sns_topic.topic.arn]
  ok_actions          = [aws_sns_topic.topic.arn]

  dimensions = {
    "TargetGroup"  = aws_alb_target_group.main.arn_suffix
    "LoadBalancer" = aws_alb.main.arn_suffix
  }

  tags = var.extra_tags
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  alarm_name          = "${local.base_name}-high-cpu-utilization"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Average"
  threshold           = 90
  unit                = "Percent"
  alarm_actions       = [aws_sns_topic.topic.arn]
  ok_actions          = [aws_sns_topic.topic.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  tags = var.extra_tags
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_credit_balance" {
  count = format("%.1s", var.instance_type) == "t" ? 1 : 0

  alarm_name          = "${local.base_name}-low-cpu-credit-balance"
  namespace           = "AWS/EC2"
  metric_name         = "CPUCreditBalance"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Minimum"
  threshold           = 10
  unit                = "Count"
  alarm_actions       = [aws_sns_topic.topic.arn]
  ok_actions          = [aws_sns_topic.topic.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  tags = var.extra_tags
}
