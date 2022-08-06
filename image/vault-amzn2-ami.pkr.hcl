variable "region" {
  description="The AWS region you're using"
  type=string
  default= "eu-west-1"
}

variable "vault_version" {
  description="The build number"
  type=string
  default="1.11.0"
}

locals {
  timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())
  tags = {
        "Name" : "packer-vault-${var.vault_version}-${local.timestamp}-ami"
        "vault_version": "${var.vault_version}"
        "AppName": "packer"
        "AppEnv" : "baseami"
        "Uuid"   : "00000000-0000-0000-0000-000000000000"
        "AppS3"  : "packer"
    }
}

source "amazon-ebs" "vault_x86_64" {
    ami_description = "vault ${var.vault_version} AMI"
    ami_name        = "vault-${var.vault_version}-x86_64-${local.timestamp}-ami"
    region          = var.region
    instance_type   = "t3.medium"
    ssh_username    = "ec2-user"

    run_tags = local.tags
    source_ami_filter {
        filters = {
            architecture: "x86_64"
            virtualization-type= "hvm"
            name= "amzn2-ami-*"
            root-device-type= "ebs"
        }
        most_recent=true
        owners= ["amazon"]
    }
}


source "amazon-ebs" "vault_arm64" {
    ami_description = "vault ${var.vault_version} AMI"
    ami_name        = "vault-${var.vault_version}-arm64-${local.timestamp}-ami"
    region          = var.region
    instance_type   = "t4g.medium"
    ssh_username    = "ec2-user"

    run_tags = local.tags
    source_ami_filter {
        filters = {
            architecture: "arm64"
            virtualization-type= "hvm"
            name= "amzn2-ami-*"
            root-device-type= "ebs"
        }
        most_recent=true
        owners= ["amazon"]
    }
}



build {
    sources=["source.amazon-ebs.vault_x86_64"]
    provisioner "shell" {
        execute_command="{{.Vars}} sudo -E -S bash '{{.Path}}'"
        scripts=["${path.root}/install-utils.sh"]
    }
    provisioner "shell" {
        execute_command="{{.Vars}} sudo -E -S bash '{{.Path}}'"
        scripts=["${path.root}/install-vault.sh"]
        environment_vars = [
            "VAULT_URL=https://releases.hashicorp.com/vault/${var.vault_version}/vault_${var.vault_version}_linux_amd64.zip"
        ]
    }
}

build {
    sources=["source.amazon-ebs.vault_arm64"]
    provisioner "shell" {
        execute_command="{{.Vars}} sudo -E -S bash '{{.Path}}'"
        scripts=["${path.root}/install-utils.sh"]
    }
    provisioner "shell" {
        execute_command="{{.Vars}} sudo -E -S bash '{{.Path}}'"
        scripts=["${path.root}/install-vault.sh"]
        environment_vars = [
            "VAULT_URL=https://releases.hashicorp.com/vault/${var.vault_version}/vault_${var.vault_version}_linux_arm64.zip"
        ]
    }
}
