locals {
  file_location = "${path.module}/src/main.py"
  filename      = "code.zip"
}


data "archive_file" "lambda" {
  type        = "zip"
  source_file = local.file_location
  output_path = local.filename
}


resource "aws_cloudwatch_event_target" "lambda_rule" {
  target_id = "${local.base_name}-lambda"
  rule      = aws_cloudwatch_event_rule.asg_cw_rule.name
  arn       = aws_lambda_function.main.arn
}

resource "aws_lambda_permission" "self" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.asg_cw_rule.arn
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.base_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:DescribeAutoScalingGroups",
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


resource "aws_iam_role" "lambda_role" {
  name = "${local.base_name}-lambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags               = var.extra_tags
}

resource "aws_cloudwatch_log_group" "lambda_log" {
  name              = "/aws/lambda/${local.base_name}-lambda"
  retention_in_days = 90

  kms_key_id = data.aws_kms_key.by_id.arn

  tags = var.extra_tags
}


resource "aws_lambda_function" "main" {
  filename         = local.filename
  function_name    = "${local.base_name}-lambda"
  description      = "${local.base_name}-lambda"
  timeout          = 300
  memory_size      = 256
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_role.arn
  handler          = "main.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      VAULT_ROLE = "lambda_util"
      VAULT_ADDR = format("https://%s.%s:8200", local.base_name, data.aws_route53_zone.zone.name)
    }
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-lambda"
    },
  )

  vpc_config {
    subnet_ids         = var.ec2_subnets
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}
