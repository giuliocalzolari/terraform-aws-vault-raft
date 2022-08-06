export AWS_DEFAULT_REGION=eu-west-1
export STAGE=${1:uat}
export MODE=${2:init}


KMS_ID=$(aws kms describe-key  --key-id alias/$STAGE-vault-kms | jq -r .KeyMetadata.KeyId)

echo "Setting on Mode $MODE"
aws ssm put-parameter \
    --name "/vault/$STAGE/root/init" \
    --value $MODE \
    --type SecureString --key-id $KMS_ID \
    --overwrite


EC2s=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$STAGE-vault-asg" \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text)
for id in $EC2s
do
    echo "Terminating Instance $id"
  aws ec2 terminate-instances  --instance-ids $id
done

# aws autoscaling delete-auto-scaling-group --auto-scaling-group-name    dev-vault-asg  --region eu-central-1 --force-delete


# aws ec2 describe-instances --region eu-west-1 --instance-ids $(aws autoscaling describe-auto-scaling-instances --region eu-west-1 --output text \
#  --query "AutoScalingInstances[?AutoScalingGroupName=='dev-vault-asg'].InstanceId") --query "Reservations[].Instances[].PublicIpAddress"

# aws ssm get-parameter --name "/vault/dev/root/token" --with-decryption --region eu-central-1 | jq .Parameter.Value -r | pbcopy
# aws ssm get-parameter --name "/vault/dev/admin/pass" --with-decryption --region eu-central-1 | jq .Parameter.Value -r | pbcopy


# export VAULT_TOKEN=$(vault login -format=json -method=aws header_value=vault.test.cloud role=vault_util | jq -r .auth.client_token)
# vault operator raft list-peers
