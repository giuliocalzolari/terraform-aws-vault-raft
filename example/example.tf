terraform {
  required_version = ">= 1.0"
  backend "local" {}
}


variable "region" {
  default = "eu-west-1"
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.64.0"

  enable_dns_hostnames = true
  enable_dns_support   = true

  name = "vault-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    CreatedBy = "Terraform"
    App       = "vault"
  }
}

module "vault" {
  source = "../"
  vpc_id = module.vpc.vpc_id

  environment = "uat"

  lb_subnets  = module.vpc.public_subnets
  ec2_subnets = module.vpc.private_subnets

  zone_name = "test.cloud"


  instance_type = "t3a.medium"
  arch = "x86_64"

  # instance_type = "t4g.medium"
  # arch          = "arm64"

  vault_version = "1.11.0"

  sns_email = [
    "vault-alert@example.com"
  ]

  size              = 3
  admin_cidr_blocks = ["1.2.3.4/32"]

  vault_telemetry = "true"

  extra_tags = {
    CreatedBy = "Terraform"
    App       = "vault"
  }
}

output "module_vault" {
  value = module.vault
}
