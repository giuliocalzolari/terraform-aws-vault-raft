
// resource "aws_iam_role" "codebuild" {
//   name               = "${var.codebuild_name}"
//   assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
// }

// data "aws_iam_policy_document" "assume_role" {
//   statement {
//     effect  = "Allow"
//     actions = ["sts:AssumeRole"]

//     principals {
//       type        = "Service"
//       identifiers = ["codebuild.amazonaws.com"]
//     }
//   }
// }

// # Create the IAM policy.

// resource "aws_iam_policy" "codebuild" {
//   name        = "${var.codebuild_name}"
//   path        = "/service-role/"
//   description = "Policy used in trust relationship with CodeBuild"
//   policy      = "${data.aws_iam_policy_document.codebuild.json}"
// }

// data "aws_iam_policy_document" "codebuild" {
//   statement {
//     effect    = "Allow"
//     resources = ["*"]

//     actions = [
//       "logs:CreateLogGroup",
//       "logs:CreateLogStream",
//       "logs:PutLogEvents",
//     ]
//   }

//   statement {
//     effect = "Allow"

//     actions = [
//       "s3:GetObject",
//       "s3:GetObjectVersion",
//       "s3:GetBucketVersioning",
//     ]

//     resources = [
//       "arn:aws:s3:::${aws_s3_bucket_object.source.bucket}",
//       "arn:aws:s3:::${aws_s3_bucket_object.source.bucket}/${aws_s3_bucket_object.source.key}",
//     ]
//   }

//   statement {
//     effect = "Allow"

//     actions = [
//       "s3:ListBucket",
//       "s3:GetObject",
//       "s3:PutObject",
//     ]

//     resources = [
//       "arn:aws:s3:::${var.repo_bucket}",
//       "arn:aws:s3:::${var.repo_bucket}/*",
//     ]
//   }
// }

// # Attach the policy to the role.

// resource "aws_iam_policy_attachment" "codebuild" {
//   name       = "${var.codebuild_name}"
//   policy_arn = "${aws_iam_policy.codebuild.arn}"
//   roles      = ["${aws_iam_role.codebuild.id}"]
// }


// resource "aws_codebuild_project" "yum_repo" {
//   name          = "${var.codebuild_name}"
//   build_timeout = "${var.build_timeout}"
//   service_role  = "${aws_iam_role.codebuild.arn}"

//   source {
//     type     = "S3"
//     location = "${aws_s3_bucket_object.source.bucket}/${aws_s3_bucket_object.source.key}"
//   }

//   environment {
//     compute_type = "BUILD_GENERAL1_SMALL"
//     image        = "aws/codebuild/standard:1.0"
//     type         = "LINUX_CONTAINER"

//     environment_variable {
//       name  = "REPO_S3_URL"
//       value = "s3://${var.repo_bucket}/${var.repo_dir}"
//     }
//   }

//   artifacts {
//     type = "NO_ARTIFACTS"
//   }
// }

// data "archive_file" "source" {
//   type        = "zip"
//   source_file = "${path.module}/buildspec.yml"
//   output_path = ".terraform/terraform-aws-s3-yum-repo-${var.codebuild_name}.zip"
// }

// resource "aws_s3_bucket_object" "source" {
//   bucket = "${aws_s3_bucket.codebuild.bucket}"
//   key    = "source.zip"
//   source = "${data.archive_file.source.output_path}"
//   etag   = "${data.archive_file.source.output_md5}"
// }
