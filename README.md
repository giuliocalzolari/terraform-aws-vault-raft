# Hashicorp Vault using AWS Native

## Overview

[Hashicorp Vault](https://www.vaultproject.io/) is becoming one of the most popular tools for secret management, every company to improve their security but sometimes setting a Vault it requires some time and deep understanding on how to configure it. To make it easy the journey to AWS Cloud and increase the level of security of all application I've decided to create an out-of-the-box solution to configure the AWS infrastructure and setting up Vault in one click.

This implementation of Vault cluster is based on [Raft Storage Backend](https://www.vaultproject.io/docs/configuration/storage/raft) announced **tech preview** on [1.2.0 (July 30th, 2019)](https://github.com/hashicorp/vault/blob/master/CHANGELOG.md#120-july-30th-2019), introduced a **beta** on [1.3.0 (November 14th, 2019))](https://github.com/hashicorp/vault/blob/master/CHANGELOG.md#13-november-14th-2019) and promoted **out of beta** on [1.4.0 (April 7th, 2020)](https://github.com/hashicorp/vault/blob/master/CHANGELOG.md#140-april-7th-2020) and is relying on native AWS tool such as AWS KMS, AWS S3, AWS Cloudwatch.

>The Raft storage backend is used to persist Vault's data. Unlike other storage backends, Raft storage does not operate from a single source of data. Instead all the nodes in a Vault cluster will have a replicated copy of Vault's data. Data gets replicated across the all the nodes via the [Raft Consensus Algorithm](https://raft.github.io).
> - **High Availability** – the Raft storage backend supports high availability.
> - **HashiCorp Supported** – the Raft storage backend is officially supported by HashiCorp.


## Diagram


<p align="center">
  <img src="https://github.com/giuliocalzolari/terraform-aws-vault-raft/blob/main/diagram.png?raw=true">
</p>

Created using [CloudCraft](https://app.cloudcraft.co/view/3763faa4-3c8e-4891-986c-b2d5a7dae7d7?key=OrI3ksrGOEl9PaMX42Kmag)

# The solution
- [Packer](https://www.packer.io/plugins/builders/amazon/ebs) [script](../image/vault-amzn2-ami.pkr.hcl) to create a Golden Image with Vault
- AWS Autoscaling group with Userdata to configure Vault and AWS Cloudwatch Agent.
- AWS Cloudwatch Dashboard for monitoring
- Vault with AWSKMS Auto-Unseal
- AWS S3 for storing the raft snapshot
- Export of Vault sensitive parameters in AWS Parameters Store
- AWS KMS To encrypt all sensitive Parameters
- AWS Application LoadBalancer with AWS ACM integration
- Vault End-to-End encryption using local private CA and SSL dynamic creation
- Vault leader election intergrated with AWS Autoscaling group lifecycle using AWS Lambda
- (Optional) Using AWS ARM instances to save cost
- (Optional) AWS WAF to protect from malicious attack



## Terraform Version

This module support Terraform `>= 1.0`

Current module version  ![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/giuliocalzolari/terraform-aws-vault-raft)

# Module Overview
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | n/a |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 3.22.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.0.0 |
| <a name="provider_template"></a> [template](#provider\_template) | 2.2.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_alb.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb) | resource |
| [aws_alb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_listener) | resource |
| [aws_alb_listener.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_listener) | resource |
| [aws_alb_listener.redirect_http_to_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_listener) | resource |
| [aws_alb_target_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group) | resource |
| [aws_autoscaling_group.asg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_lifecycle_hook.ec2terminate](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook) | resource |
| [aws_cloudwatch_dashboard.dashboard](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_event_rule.asg_cw_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.event_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.lambda_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.lambda_log](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.alb_unhealty_host](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.asg_alarm_inservice](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.high_cpu_utilization](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.httpcode_lb_5xx_count](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.httpcode_target_5xx_count](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_alarm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.low_cpu_credit_balance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.target_response_time_average](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.vault_core_unsealed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.vault_raft_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_instance_profile.ec2_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.cw_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ec2_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cw_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ec2_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_service_linked_role.asg_service_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |
| [aws_key_pair.key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_kms_alias.key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lambda_function.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_launch_template.tpl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_route53_record.cname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.s3_alb_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_security_group.alb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.lambda_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.alb_egress_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_http_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_https_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_vault_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.asg_app_admin_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.asg_egress_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.asg_ssh_admin_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.asg_vault_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.lambda_asg_vault_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.lambda_egress_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.vault_node_ig](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_sns_topic.topic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.topic_email_subscription](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_ssm_parameter.admin_pass](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.root_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.ssh_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.vault_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.vault_ca](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.vault_ca_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.vault_init](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [random_uuid.uuid](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [tls_private_key.key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_private_key.vault-ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [tls_self_signed_cert.vault-ca](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/self_signed_cert) | resource |
| [archive_file.lambda](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_ami.ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cw_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ec2_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ec2_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.kms_key_policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.sns_topic_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_kms_key.by_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/kms_key) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [template_file.vault](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_actions_alarm"></a> [actions\_alarm](#input\_actions\_alarm) | A list of actions to take when alarms are triggered. Will likely be an SNS topic for event distribution. | `list(string)` | `[]` | no |
| <a name="input_actions_ok"></a> [actions\_ok](#input\_actions\_ok) | A list of actions to take when alarms are cleared. Will likely be an SNS topic for event distribution. | `list(string)` | `[]` | no |
| <a name="input_admin_cidr_blocks"></a> [admin\_cidr\_blocks](#input\_admin\_cidr\_blocks) | Admin CIDR Block to access SSH and internal Application ports | `list(string)` | `[]` | no |
| <a name="input_alb_ssl_policy"></a> [alb\_ssl\_policy](#input\_alb\_ssl\_policy) | ALB ssl policy | `string` | `"ELBSecurityPolicy-FS-1-2-Res-2020-10"` | no |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | Application name N.1 (e.g. vault, secure, store, etc..) | `string` | `"vault"` | no |
| <a name="input_arch"></a> [arch](#input\_arch) | EC2 Architecture arm64/x86\_64 (arm64 is suggested) | `string` | `"x86_64"` | no |
| <a name="input_create_asg_service_linked_role"></a> [create\_asg\_service\_linked\_role](#input\_create\_asg\_service\_linked\_role) | Automatic creation of Autoscaling Service Linked Role | `bool` | `true` | no |
| <a name="input_default_cooldown"></a> [default\_cooldown](#input\_default\_cooldown) | ASG cooldown time | `string` | `"60"` | no |
| <a name="input_ebs_optimized"></a> [ebs\_optimized](#input\_ebs\_optimized) | If true, the launched EC2 instance will be EBS-optimized. | `bool` | `false` | no |
| <a name="input_ec2_subnets"></a> [ec2\_subnets](#input\_ec2\_subnets) | ASG Subnets | `list(string)` | `[]` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment Name (e.g. dev, test, uat, prod, etc..) | `string` | `"dev"` | no |
| <a name="input_extra_tags"></a> [extra\_tags](#input\_extra\_tags) | Additional Tag to add | `map(string)` | n/a | yes |
| <a name="input_health_check_type"></a> [health\_check\_type](#input\_health\_check\_type) | 'EC2' or 'ELB'. Controls how health checking is done. | `string` | `"ELB"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 Instance Size | `string` | n/a | yes |
| <a name="input_internal"></a> [internal](#input\_internal) | ALB internal/public flag | `bool` | `false` | no |
| <a name="input_kms_key_deletion_window_in_days"></a> [kms\_key\_deletion\_window\_in\_days](#input\_kms\_key\_deletion\_window\_in\_days) | The waiting period, specified in number of days. After the waiting period ends, AWS KMS deletes the KMS key. If you specify a value, it must be between 7 and 30, inclusive | `string` | `"7"` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS Key Id for vault Auto-Unseal | `string` | `""` | no |
| <a name="input_lb_subnets"></a> [lb\_subnets](#input\_lb\_subnets) | ALB Subnets | `list(string)` | `[]` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix to add on all resources | `string` | `""` | no |
| <a name="input_protect_from_scale_in"></a> [protect\_from\_scale\_in](#input\_protect\_from\_scale\_in) | n/a | `bool` | `false` | no |
| <a name="input_public_key"></a> [public\_key](#input\_public\_key) | SSH public key to install in vault | `string` | `null` | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | EC2 ASG Disk Size | `string` | `"50"` | no |
| <a name="input_root_volume_type"></a> [root\_volume\_type](#input\_root\_volume\_type) | The volume type. Can be standard, gp2, gp3, io1, io2, sc1 or st1 (Default: gp2). | `string` | `"gp2"` | no |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | S3 Backup  name for Raft backup if empty will be automatically generated | `string` | `""` | no |
| <a name="input_size"></a> [size](#input\_size) | ASG Size | `string` | `"3"` | no |
| <a name="input_sns_email"></a> [sns\_email](#input\_sns\_email) | list of email for SNS alarm | `list(string)` | `[]` | no |
| <a name="input_suffix"></a> [suffix](#input\_suffix) | Suffix to add on all resources | `string` | `""` | no |
| <a name="input_termination_policies"></a> [termination\_policies](#input\_termination\_policies) | ASG Termination Policy | `list(string)` | <pre>[<br>  "Default"<br>]</pre> | no |
| <a name="input_vault_telemetry"></a> [vault\_telemetry](#input\_vault\_telemetry) | enabling Vault Telemetry (Warning!!! AWS custom metric will increase the cost of the solution) | `string` | `"false"` | no |
| <a name="input_vault_version"></a> [vault\_version](#input\_vault\_version) | Vault version to install | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC Id | `string` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Public Route53 Zone name for DNS and ACM validation | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_pass_arn"></a> [admin\_pass\_arn](#output\_admin\_pass\_arn) | SSM vault root password ARN |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ALB ARN |
| <a name="output_alb_hostname"></a> [alb\_hostname](#output\_alb\_hostname) | ALB DNS |
| <a name="output_ec2_iam_role_arn"></a> [ec2\_iam\_role\_arn](#output\_ec2\_iam\_role\_arn) | IAM EC2 role ARN |
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | KMS key ID |
| <a name="output_root_token_arn"></a> [root\_token\_arn](#output\_root\_token\_arn) | SSM vault root token ARN |
| <a name="output_sns_arn"></a> [sns\_arn](#output\_sns\_arn) | SNS ARN |
| <a name="output_vault_fqdn"></a> [vault\_fqdn](#output\_vault\_fqdn) | Vault DNS |
| <a name="output_vault_version"></a> [vault\_version](#output\_vault\_version) | Vault Version |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Why Not Fargate?

Fargate is a new AWS serverless technology for running Docker containers. It was
considered for this project but rejected for several reasons:

1. No support for `IPC_LOCK`. Vault tries to lock its memory so that secret data
   is never swapped to disk. Although it seems unlikely Fargate swaps to disk, the
   lock capability is not provided.

2. Running on EC2 makes configuring Vault easier. The Ansible playbooks or bash included
   with this terraform build the Vault configuration for each server. It would
   be much harder to do this in a Fargate environment with sidecar containers or
   custom Vault images.

3. Running on EC2 makes DNS configuration easier. The Vault redirection method
   means you need to know the separate DNS endpoint names and doing this on Fargate
   is complicated. With EC2 we register some ElasticIPs and use those for the
   individual servers.

Many of these problems could be solved by running Vault in a custom image. However,
it seemed valuable to use the Hashicorp Vault image instead of relying on custom
built ones, so EC2 was chosen as the ECS technology.

# Example

please check the [example folder](./example/).


## Test your solution

Do you want to test your deployment?
Just open your shell, adjust the DNS and kill the primary vault

```
for i in {1..500}
do
   RES=$(curl -s -o /dev/null -w "%{http_code}"  https://vault.[ YOUR DOMAIN ]/ui/)
   echo "[$(date +%T)] HTTP:$RES attemp:$i"
   sleep 1
done
```

in **less than a minute** the standby instance will be available and in **few minutes** the ASG will launch a new node


## pre-commit hook

this repo is using pre-commit hook to know more [click here](https://github.com/antonbabenko/pre-commit-terraform)
to manually trigger use this command

```
pre-commit install
pre-commit run --all-files
```

# Troubleshooting / Known Issue

- **Autoscaling Group** not encrypted EBS volume required to have a dedicated AMI already encrypted and required to have the proper service role for ASG to be albe to encrypt/decrypt the ebs volume

- **ASG Service Linked Role** Terraform on destruction phase can spit `│ Error: error waiting for IAM Service Linked Role (arn:aws:iam::XXXXXXX:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling) delete: unexpected state 'FAILED', wanted target 'SUCCEEDED'. last error: %!s(<nil>)` open issue on [terraform-provider-aws](https://github.com/hashicorp/terraform-provider-aws/issues/12937)

- **ACM** soft limit if you see this error `Error requesting certificate: LimitExceededException: Error: you have reached your limit of 20 certificates in the last year.` please increase the Limit using AWs Support of AWS Quota

- **Cloudwatch Logs** KMS Error `Error: Creating CloudWatch Log Group failed: InvalidParameterException: The specified KMS Key Id could not be found.`, double check if the KMS key have proper policy to allow the regional Cloudwatch logs Service Principle (e.g. `logs.eu-central-1.amazonaws.com`)


## License

this repo is licensed under the [WTFPL](LICENSE).
