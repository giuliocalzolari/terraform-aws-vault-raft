variable "vpc_id" {
  type        = string
  description = "VPC Id"
}

variable "environment" {
  default     = "dev"
  type        = string
  description = "Environment Name (e.g. dev, test, uat, prod, etc..)"
}

variable "app_name" {
  default     = "vault"
  type        = string
  description = "Application name N.1 (e.g. vault, secure, store, etc..)"
}

variable "prefix" {
  default     = ""
  type        = string
  description = "Prefix to add on all resources"
}

variable "suffix" {
  default     = ""
  type        = string
  description = "Suffix to add on all resources"
}

variable "sns_email" {
  default     = []
  type        = list(string)
  description = "list of email for SNS alarm"
}

variable "arch" {
  default     = "x86_64"
  type        = string
  description = "EC2 Architecture arm64/x86_64 (arm64 is suggested)"
  validation {
    condition = anytrue([
      var.arch == "arm64",
      var.arch == "x86_64"
    ])
    error_message = "EC2 Architecture can be 'arm64' or 'x86_64'."
  }
}

variable "vault_version" {
  type        = string
  description = "Vault version to install"
}

variable "vault_telemetry" {
  type        = string
  default     = "false"
  description = "enabling Vault Telemetry (Warning!!! AWS custom metric will increase the cost of the solution)"
}



variable "s3_bucket_name" {
  default     = ""
  type        = string
  description = "S3 Backup  name for Raft backup if empty will be automatically generated"
}

locals {
  base_name  = "${var.prefix}${var.app_name}${var.suffix}-${var.environment}"
  aws_region = data.aws_region.current.name
  kms_key_id = var.kms_key_id == "" ? aws_kms_key.key[0].key_id : var.kms_key_id
  s3_bucket  = var.s3_bucket_name == "" ? "${local.base_name}-${local.aws_region}-${random_uuid.uuid.result}" : var.s3_bucket_name
}

# Additional tags to apply to all tagged resources.
variable "extra_tags" {
  type        = map(string)
  description = "Additional Tag to add"
}

variable "internal" {
  default     = false
  type        = bool
  description = "ALB internal/public flag"
}

variable "ec2_subnets" {
  default     = []
  type        = list(string)
  description = "ASG Subnets"
}

variable "lb_subnets" {
  default     = []
  type        = list(string)
  description = "ALB Subnets"
}

variable "create_asg_service_linked_role" {
  type        = bool
  description = "Automatic creation of Autoscaling Service Linked Role"
  default     = true
}

variable "public_key" {
  default     = null
  type        = string
  description = "SSH public key to install in vault"
}

variable "zone_name" {
  type        = string
  description = "Public Route53 Zone name for DNS and ACM validation"
}

variable "kms_key_id" {
  type        = string
  description = "KMS Key Id for vault Auto-Unseal"
  default     = ""
}

variable "kms_key_deletion_window_in_days" {
  type        = string
  description = "The waiting period, specified in number of days. After the waiting period ends, AWS KMS deletes the KMS key. If you specify a value, it must be between 7 and 30, inclusive"
  default     = "7"
}



variable "instance_type" {
  type        = string
  description = "EC2 Instance Size"
}

variable "root_volume_size" {
  default     = "50"
  type        = string
  description = "EC2 ASG Disk Size"
}

variable "root_volume_type" {
  default     = "gp2"
  type        = string
  description = "The volume type. Can be standard, gp2, gp3, io1, io2, sc1 or st1 (Default: gp2)."
}

variable "ebs_optimized" {
  default     = false
  type        = bool
  description = "If true, the launched EC2 instance will be EBS-optimized."
}



variable "size" {
  description = "ASG Size"
  default     = "3"
  type        = string
}

variable "default_cooldown" {
  default     = "60"
  type        = string
  description = "ASG cooldown time"
}

variable "termination_policies" {
  type        = list(string)
  default     = ["Default"]
  description = "ASG Termination Policy"
}

variable "protect_from_scale_in" {
  default = false
  type    = bool
}

variable "health_check_type" {
  type        = string
  description = "'EC2' or 'ELB'. Controls how health checking is done."
  default     = "ELB"
}

variable "alb_ssl_policy" {
  type        = string
  description = "ALB ssl policy"
  default     = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
}

variable "admin_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "Admin CIDR Block to access SSH and internal Application ports"
}


variable "actions_alarm" {
  type        = list(string)
  default     = []
  description = "A list of actions to take when alarms are triggered. Will likely be an SNS topic for event distribution."
}

variable "actions_ok" {
  type        = list(string)
  default     = []
  description = "A list of actions to take when alarms are cleared. Will likely be an SNS topic for event distribution."
}
