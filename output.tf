

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_alb.main.arn
}

output "alb_hostname" {
  description = "ALB DNS"
  value       = aws_alb.main.dns_name
}

output "vault_fqdn" {
  description = "Vault DNS"
  value       = "${local.base_name}.${data.aws_route53_zone.zone.name}"
}

output "vault_version" {
  description = "Vault Version"
  value       = var.vault_version
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = local.kms_key_id
}

output "ec2_iam_role_arn" {
  description = "IAM EC2 role ARN"
  value       = aws_iam_role.ec2_instance.arn
}

output "admin_pass_arn" {
  description = "SSM vault root password ARN"
  value       = aws_ssm_parameter.admin_pass.arn
}

output "root_token_arn" {
  description = "SSM vault root token ARN"
  value       = aws_ssm_parameter.root_token.arn
}

output "sns_arn" {
  description = "SNS ARN"
  value       = aws_sns_topic.topic.arn
}
