# Packer - Vault

Builds AWS AMI images for [Vault](https://www.vaultproject.io) using [Packer](https://www.packer.io/) based on the official Amazon Linux 2 AMI image in the eu-west-1 for both `arm64` and `x86_64` architecture.

This is unconfigured, to configure it place the
[Vault configuration file](https://www.vaultproject.io/docs/configuration/index.html) into `/opt/vault/etc/`, terraform is going to configure the auto scaling group using [user data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html) using the [template](../templates/userdata.tpl).

The reason for this is for implementing the idea of immutable infrastructure, where updates and upgrade a baked into the AMI and the updated version is deployed to replace the existing servers. This is done as a
rolling update, where a new server is brought into service, checked that it has joined the cluster successfully, then an old one is terminated. This is repeated until all servers in the cluster is running the latest AMI.

## Usage

```
packer build vault-amzn2-ami.pkr.hcl
```

additional script to cleaup the old AMI si provided as part of the repository (it use python3 and boto3)

```
python3 ./cleaup_ami.py
```
