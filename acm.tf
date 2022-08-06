data "aws_route53_zone" "zone" {
  name         = "${var.zone_name}."
  private_zone = false
}


resource "aws_acm_certificate" "vault" {
  domain_name       = "${local.base_name}.${var.zone_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${local.base_name}-acm"
    },
  )

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }
}


resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.vault.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.zone.zone_id
}


resource "aws_acm_certificate_validation" "vault" {
  certificate_arn         = aws_acm_certificate.vault.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

resource "aws_route53_record" "cname" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "${local.base_name}.${data.aws_route53_zone.zone.name}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_alb.main.dns_name]
}


resource "tls_private_key" "vault-ca" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_self_signed_cert" "vault-ca" {
  private_key_pem = tls_private_key.vault-ca.private_key_pem

  subject {
    common_name  = "vault.local"
    organization = "CA"
  }

  validity_period_hours = 8760
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "digital_signature",
    "key_encipherment",
  ]
}


resource "aws_ssm_parameter" "vault_ca_key" {
  name   = "/${var.prefix}${var.app_name}${var.suffix}/${var.environment}/tls/ca-key"
  type   = "SecureString"
  value  = tls_private_key.vault-ca.private_key_pem
  key_id = local.kms_key_id
  tags   = var.extra_tags
}

resource "aws_ssm_parameter" "vault_ca" {
  name   = "/${var.prefix}${var.app_name}${var.suffix}/${var.environment}/tls/ca"
  type   = "SecureString"
  value  = tls_self_signed_cert.vault-ca.cert_pem
  key_id = local.kms_key_id
  tags   = var.extra_tags
}
