/*== ec2 CLUSTER INSTANCES IAM ==*/
resource "aws_iam_instance_profile" "ec2_instance" {
  name = "${local.base_name}-ec2-profile"
  role = aws_iam_role.ec2_instance.name
}

resource "aws_iam_role" "ec2_instance" {
  name               = "${local.base_name}-ec2-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_instance.json
  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-ec2-role"
    },
  )
}

data "aws_iam_policy_document" "ec2_instance" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ec2_role_policy" {
  name   = "${local.base_name}-ec2-role-policy"
  role   = aws_iam_role.ec2_instance.id
  policy = data.aws_iam_policy_document.ec2_role_policy.json
}



data "aws_iam_policy_document" "ec2_role_policy" {

  statement {
    sid       = "VaultKMSUnseal"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "iam:GetRole"
    ]
  }
  statement {
    sid    = "allowParameterStore"
    effect = "Allow"
    resources = [
      replace("arn:aws:ssm:*:*:parameter/${local.base_name}/*", "-", "/")
    ]
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:GetParameterHistory"
    ]
  }

  statement {
    sid    = "allowLoggingToCloudWatch"
    effect = "Allow"
    resources = [
      "*"
    ]
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "cloudwatch:PutMetricData",
    ]
  }

  statement {
    sid    = "allowRaftBackupOnS3"
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.bucket.arn}/*",
    ]
    actions = [
      "s3:PutObject",
      "s3:GetObjectAcl",
      "s3:GetObject",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucketVersions",
      "s3:PutObjectAcl",
      "s3:ListMultipartUploadParts",
    ]
  }

  statement {
    sid    = "ListS3Bucket"
    effect = "Allow"
    resources = [
      aws_s3_bucket.bucket.arn,
    ]
    actions = [
      "s3:ListBucket"
    ]
  }
}


resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.ec2_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
