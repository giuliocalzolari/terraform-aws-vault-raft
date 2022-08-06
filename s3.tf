data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    actions = ["s3:PutObject"]
    resources = [
      "arn:aws:s3:::${local.s3_bucket}/alb_access_logs/*",
      "arn:aws:s3:::${local.s3_bucket}"
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_elb_service_account.main.id}:root"]
    }
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.s3_bucket}/alb_access_logs/*"]
    condition {
      test     = "StringEquals"
      values   = ["bucket-owner-full-control"]
      variable = "s3:x-amz-acl"
    }

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
  }

  statement {
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${local.s3_bucket}"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
  }
}



resource "aws_s3_bucket" "bucket" {
  #checkov:skip=CKV_AWS_21:S3 Versioning moved as dedicated resource in aws 4.0 provider
  #checkov:skip=CKV_AWS_145:S3 KMS moved as dedicated resource in aws 4.0 provider
  #checkov:skip=CKV_AWS_144:S3 cross region not required
  #checkov:skip=CKV_AWS_18:S3 logging not required
  #checkov:skip=CKV_AWS_19:S3 KMS moved as dedicated resource in aws 4.0 provider
  bucket = local.s3_bucket

  force_destroy = true
  tags = merge(
    var.extra_tags,
    { "Name" : local.s3_bucket }
  )
}

resource "aws_s3_bucket_versioning" "s3_versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "bucket-config" {
  bucket = aws_s3_bucket.bucket.bucket

  rule {
    id = "lifecycle"
    expiration {
      days = 92
    }

    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "s3_enc" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      kms_master_key_id = data.aws_kms_key.by_id.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pl" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



resource "aws_s3_bucket_policy" "s3_alb_logs" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}
