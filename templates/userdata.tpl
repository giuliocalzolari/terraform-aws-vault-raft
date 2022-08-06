#!/bin/bash
ssm_put() {
  aws ssm put-parameter \
    --name "$${1}" \
    --value "$${2}" \
    --type SecureString --key-id "${kms_key}" \
    --region ${aws_region} --overwrite 2>&1 > /dev/null
}

ssm_get() {
  aws ssm get-parameter \
    --name "$${1}" \
    --with-decryption --region ${aws_region} | jq .Parameter.Value -r
}

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION="${aws_region}"
SELF_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
SELF_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" 169.254.169.254/latest/meta-data/instance-id)
SSM_PATH="/${app_name}/${environment}"

CW_CFG="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
sed -i 's/#APP_NAME/${app_name}/g' $CW_CFG
sed -i 's/#APP_ENV/${environment}/g' $CW_CFG
sed -i 's/#CW-NS/${app_name}-${environment}-n/g' $CW_CFG
amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file://$CW_CFG -s

cat << EOF > /opt/vault/etc/config.json
{
  "app_name":"${app_name}",
  "app_env":"${environment}",
  "s3":"${s3_bucket}",
  "region":"${aws_region}",
  "kms_id":"${kms_key}",
  "uuid":"${uuid}",
  "vault_domain":"${vault_domain}"
}
EOF

echo "Creating Vault certs"
/opt/vault/bin/cert-utils "${vault_domain}"

cat << EOF > /opt/vault/etc/vault.hcl
disable_cache = true
disable_mlock = true
ui            = true
log_level     = "Info"
cluster_name  = "${app_name}-${environment}"

seal "awskms" {
  region     = "${aws_region}"
  kms_key_id = "${kms_key}"
}

listener "tcp" {
  address = "[::]:8200"
  cluster_address = "[::]:8201"
  tls_cert_file = "/opt/vault/tls/vault-server.pem"
  tls_key_file = "/opt/vault/tls/vault-server-key.pem"
  tls_min_version = "tls12"
  x_forwarded_for_authorized_addrs = ["10.0.0.0/8"]
  tls_prefer_server_cipher_suites  = true
  tls_cipher_suites = "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_AES_128_GCM_SHA256,TLS_CHACHA20_POLY1305_SHA256,TLS_AES_256_GCM_SHA384"
}

api_addr = "https://$SELF_IP:8200"
cluster_addr = "https://$SELF_IP:8201"
performance_multiplier = 1

##telemetry {
##  statsd_address = "127.0.0.1:8125"
##  disable_hostname = true
##}

backend "raft" {
  path = "/opt/vault/data/"
  node_id = "$SELF_ID"
  performance_multiplier = 1
  retry_join {
    auto_join = "provider=aws addr_type=private_v4 region=${aws_region} tag_key=Uuid tag_value=${uuid}"
    auto_join_scheme = "https"
    auto_join_port = 8200
    leader_ca_cert_file = "/opt/vault/tls/vault-ca.pem"
  }
}
EOF

if [[ "${vault_telemetry}" == "true" ]]; then
  sed -i -e 's/^##//g' /opt/vault/etc/vault.hcl
fi

chown -R vault:vault /opt/vault
systemctl start vault

echo "waiting vault boot"
echo ""
while true
do
  STATUS=$(curl -s -o /dev/null -w '%%{http_code}' https://127.0.0.1:8200/v1/sys/seal-status)
  if [ $STATUS -eq 200 ]; then
    echo "vault is online"
    break
  else
    printf '.'
  fi
  sleep 2
done

export VAULT_ADDR=https://127.0.0.1:8200
INITIALIZE="False"
SSM_INIT=$(ssm_get "$SSM_PATH/root/init")
STATUS=$(vault status -format=json)
if [[ "$(echo $STATUS | jq .initialized)" == "false"  && $SSM_INIT == "init" ]]; then
  ssm_put '/${app_name}/${environment}/root/init' "$SELF_ID"
  RN=$[ ( $RANDOM % 15 )  + 5 ]s
  echo "Sleeping $RN before 2nd check"
  sleep $RN
  STATUS=$(vault status -format=json)
  SSM_INIT=$(ssm_get "$SSM_PATH/root/init")
  if [[ "$(echo $STATUS | jq .initialized)" == "false"  && $SSM_INIT == "$SELF_ID" ]]; then
    echo "I am the first node and I will initialize the vault"
    INITIALIZE="True"
  fi
fi

if [[ "$(echo $STATUS | jq .initialized)" == "false"  && $SSM_INIT == "recovery" ]]; then
  ssm_put '/${app_name}/${environment}/root/init' "$SELF_ID"
  RN=$[ ( $RANDOM % 15 )  + 5 ]s
  echo "Sleeping $RN before 2nd check"
  sleep $RN
  STATUS=$(vault status -format=json)
  SSM_INIT=$(ssm_get "$SSM_PATH/root/init")

  if [[ "$(echo $STATUS | jq .initialized)" == "false"  && $SSM_INIT == "$SELF_ID" ]]; then
    SNAPSHOT=$(ssm_get "$SSM_PATH/sys/last_backup")
    echo "I am the first node and I will restore the vault using snapshot $SNAPSHOT"

    INIT=$(vault operator init -format=json)
    export VAULT_TOKEN="$(echo $INIT | jq .root_token -r)"

    echo "Download snpshot s3://${s3_bucket}/$SNAPSHOT"
    aws s3 cp s3://${s3_bucket}/$SNAPSHOT /tmp/raft.snap
    for ((i=0; i<4; i++)); do
      vault operator raft snapshot restore /tmp/raft.snap
      if [ $? -eq 0 ]; then
        echo "[$i] Restoring Snapshot Success"
        break
      else
        echo "[$i] Restoring Snapshot Faild"
        sleep 2
      fi
    done

    INIT_HISTORY=$(aws ssm get-parameter-history --name "$SSM_PATH/root/init" --region ${aws_region}  --with-decryption  | jq '.Parameters | reverse ')
    FOUND="False"
    for INIT_ROW in $(echo "$INIT_HISTORY" | jq -r '.[] | @base64'); do
        RES=$(echo $INIT_ROW | base64 --decode | jq -r  '.Value')
        if jq -e . >/dev/null 2>&1 <<<"$RES"; then
            FOUND="True"
            echo "Restoring INIT version $(echo $INIT_ROW | base64 --decode | jq -r  '.Version')"
            ssm_put "$SSM_PATH/root/init" "$RES"
            sleep 5
            break
        fi
    done

    if [[ $FOUND == "False" ]]; then
      echo "WARNING!!! no suitable INIT config found on ssm $SSM_PATH/root/init to restore"
    fi
  fi
fi

STATUS=$(vault status -format=json)
if [[ "$(echo $STATUS | jq .initialized)" == "false" && $INITIALIZE == "True" ]]; then
  echo "booting vault"
  until [[ "$( vault status -format=json | jq .storage_type -r )" == "raft" ]] ; do
    sleep 1
  done
  echo "initializing vault"
  INIT=$(vault operator init -format=json)
  echo "Saving init data on ssm://$SSM_PATH/root/init"
  ssm_put "$SSM_PATH/root/init" "$INIT"
  ROOT_TOKEN="$(echo $INIT | jq .root_token -r)"
  STATUS2=$(vault status -format=json )
  if [[ "$(echo $STATUS2 | jq .sealed)" == "false" ]]; then
      echo "vault setup completed"
      export VAULT_TOKEN=$ROOT_TOKEN
      echo "Setting Audit file"
      until vault audit enable file file_path=/var/log/vault_audit.log; do
        sleep 1
      done

      echo "vault operator raft list-peers"
      vault operator raft list-peers
      echo "Creating Admin Policy"
      vault policy write admin <( echo 'path "*" { capabilities = ["create", "read", "update", "delete", "list", "sudo"]}')
      echo "Enabling userpass"
      vault auth enable userpass
      echo "setting admin user"
      PASS=$(openssl rand -base64 18)
      echo "setting vault admin username and passwd"
      vault write auth/userpass/users/admin password="$PASS" policies=admin,default

      echo "Saving root token on ssm://$SSM_PATH/root/token"
      ssm_put "$SSM_PATH/root/token" "$ROOT_TOKEN"

      echo "Saving admin password on ssm://$SSM_PATH/admin/pass"
      ssm_put "$SSM_PATH/admin/pass" "$PASS"

      echo "Setting Vault Util AWS role"
      vault auth enable aws
      vault policy write util_remove_peer <( echo 'path "sys/storage/raft/remove-peer" { capabilities = ["create","update","delete" ]} path "sys/storage/raft/configuration" { capabilities = ["read" ]}')
      vault policy write util_backup <( echo 'path "sys/storage/raft/snapshot" { capabilities = ["read"]}')
      vault policy write util_stepdown <( echo 'path "sys/step-down" { capabilities = ["update","sudo"]}')
      vault write auth/aws/role/vault_util \
        auth_type=iam \
        policies=util_backup,util_remove_peer,util_stepdown \
        max_ttl=1h \
        bound_iam_principal_arn=${ec2_role_arn}

      vault write auth/aws/role/lambda_util \
        auth_type=iam \
        policies=util_remove_peer,util_stepdown \
        max_ttl=1h \
        bound_iam_principal_arn=${lambda_role_arn}

      vault write auth/aws/config/client iam_server_id_header_value=${vault_domain}

      echo "Creating sample data"
      vault secrets enable -path=kv kv-v2
      vault kv put kv/test testsecret=supersecret123

      # echo "Removing Root Token"
      # ROOT_TOKEN_ACCESSOR=$(vault token lookup -format=json | jq .data.accessor -r)
      # vault token revoke -accessor $ROOT_TOKEN_ACCESSOR
      echo "unset VAULT_TOKEN"
      unset VAULT_TOKEN
      echo "Create initial backup"
      /opt/vault/bin/raft-backup
  else
    echo "Error on vault setup"
    echo $STATUS2
  fi

else
  echo "Current Vault Status"
  echo $STATUS
fi
