#!/bin/bash


useradd --system --home /opt/vault --shell /bin/false vault


export AUDIT_LOG_PATH=/var/log/vault_audit.log
RAFT_PATH="/opt/vault/data/"


cat << EOF > /etc/logrotate.d/vault
$AUDIT_LOG_PATH {
  daily
  su root syslog
  create 640 vault vault
  rotate 7
  notifempty
  missingok
  compress
  delaycompress
  postrotate
    /bin/systemctl reload vault 2> /dev/null || true
  endscript
  create 0644 vault vault
}
EOF


#INITIALIZE FOLDERS & FILES
touch $AUDIT_LOG_PATH
chown vault:vault $AUDIT_LOG_PATH
mkdir -p /opt/vault/{etc,bin,tls} $RAFT_PATH

echo "Download vault binary from $VAULT_URL"
curl --silent --output /tmp/vault.zip $VAULT_URL
unzip -o /tmp/vault.zip -d /sbin/

echo "Giving Vault permission to use the mlock syscall"
setcap cap_ipc_lock=+ep /sbin/vault

cat << EOF > /lib/systemd/system/vault.service
[Unit]
Description="HashiCorp Vault on AWS"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/opt/vault/etc/vault.hcl

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/sbin/vault server -config=/opt/vault/etc/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

chown -R vault:vault /opt/vault
systemctl daemon-reload
systemctl enable vault


cat << 'EOF' > "/opt/vault/bin/raft-peer-remove"
#!/bin/bash
set -e
if [ -z "$1" ]; then
  echo "No argument supplied"
  exit 1
else
  NODE_TO_REMOVE=$1
fi
CFG="/opt/vault/etc/config.json"
VAULT_DOMAIN=$(jq -r .vault_domain $CFG)
REGION=$(jq -r .region $CFG)

export VAULT_TOKEN=$(vault login -format=json -method=aws header_value=$VAULT_DOMAIN role=vault_util | jq -r .auth.client_token)
export VAULT_ADDR=https://127.0.0.1:8200

vault operator raft list-peers

TOPO=$(vault operator raft list-peers -format json | jq .data.config)
NODE_IDS=$(echo $TOPO | jq -r .servers[].node_id)

FOUND="False"
for NODE in $NODE_IDS; do
    if [[ "$NODE" == "$NODE_TO_REMOVE" ]]; then
        echo "Executing Step Down"
        /opt/vault/bin/step-down
        echo "Removing Memeber Node $NODE_TO_REMOVE"
        vault operator raft remove-peer $NODE_TO_REMOVE
        FOUND="True"
    fi
done
if [[ "$FOUND" == "False" ]]; then
    echo "Node $NODE_TO_REMOVE NOT Found"
fi

EOF
chmod +x /opt/vault/bin/raft-peer-remove

cat << 'EOF' > "/opt/vault/bin/raft-backup"
#!/bin/bash
if [[ $(curl -s https://localhost:8200/v1/sys/leader -k | jq .is_self) == false ]]; then
  echo "skipping backup, I am not the leader"
  exit 0;
fi

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
SELF_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" 169.254.169.254/latest/meta-data/instance-id)

CFG="/opt/vault/etc/config.json"
APP_NAME=$(jq -r .app_name $CFG)
APP_ENV=$(jq -r .app_env $CFG)
APP_S3=$(jq -r .s3 $CFG)
APP_UUID=$(jq -r .uuid $CFG)
VAULT_DOMAIN=$(jq -r .vault_domain $CFG)
REGION=$(jq -r .region $CFG)
KMS_ID=$(jq -r .kms_id $CFG)

export VAULT_ADDR=https://127.0.0.1:8200
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
export VAULT_TOKEN=$(vault login -format=json -method=aws header_value=$VAULT_DOMAIN role=vault_util | jq -r .auth.client_token)
BACKUP_NAME=raft_${APP_NAME}_${APP_ENV}_${SELF_ID}_${APP_UUID}_${TIMESTAMP}.snapshot
vault operator raft snapshot save /tmp/${BACKUP_NAME}
aws s3 cp /tmp/${BACKUP_NAME} s3://${APP_S3}
if [ $? -eq 0 ]; then
    echo "Backup ${BACKUP_NAME} to S3 completed"
    aws ssm put-parameter \
      --name "/$APP_NAME/$APP_ENV/sys/last_backup" \
      --value "$BACKUP_NAME" \
      --type SecureString --key-id "$KMS_ID" \
      --region $REGION --overwrite
    # StatD message sent to Cloudwatch Agent to store as CW Metric
    echo "vault.raft.backup_to_s3:1.000000|c" > /dev/udp/127.0.0.1/8125
    rm -f /tmp/${BACKUP_NAME}
else
    logger -s "Error on Backup ${BACKUP_NAME} to S3"
fi

EOF
chmod +x /opt/vault/bin/raft-backup


cat << 'EOF' > "/opt/vault/bin/step-down"
#!/bin/bash
set -e
SELF_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
LEADER_IP=$(curl -sk https://127.0.0.1:8200/v1/sys/leader | jq .leader_cluster_address -r | cut -f 2 -d":"  | tr -d "/")
CFG="/opt/vault/etc/config.json"
VAULT_DOMAIN=$(jq -r .vault_domain $CFG)
#echo "my IP: $SELF_IP leader IP: $LEADER_IP"

if [[ "${SELF_IP}" == "${LEADER_IP}" ]]; then
  export VAULT_ADDR=https://127.0.0.1:8200
  export VAULT_TOKEN=$(vault login -format=json -method=aws header_value=$VAULT_DOMAIN role=vault_util | jq -r .auth.client_token)
  echo "Current raft Peers"
  vault operator raft list-peers
  echo "Executing Step Down"
  vault operator step-down
  if [ $? -eq 0 ]; then
      echo "Step Down Action completed"
      echo "New raft Peers"
      vault operator raft list-peers
  else
      logger -s "Error on Step Down Action"
      exit 1
  fi
else
  echo "skipping step down, I am not the leader"
fi
EOF
chmod +x /opt/vault/bin/step-down


echo "42 * * * * root /bin/bash -lc /opt/vault/bin/raft-backup" > /etc/cron.d/vault-raft-backup


cat << 'EOF' > /opt/vault/bin/cert-utils
#!/bin/bash
set -e

if [ "$1" == "" ]; then
    echo "argument not provided"
    exit 1
fi

CFG="/opt/vault/etc/config.json"
APP_NAME=$(jq -r .app_name $CFG)
APP_ENV=$(jq -r .app_env $CFG)
APP_S3=$(jq -r .s3 $CFG)
APP_UUID=$(jq -r .uuid $CFG)
REGION=$(jq -r .region $CFG)

SELF_IP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)

LOCAL_CA_FILE=/etc/pki/ca-trust/source/anchors/vault-ca.pem
if [ ! -f "${LOCAL_CA_FILE}" ]; then
  echo "Get CA Cert"
  aws ssm get-parameter --name "/${APP_NAME}/${APP_ENV}/tls/ca" --with-decryption --region ${REGION} | jq .Parameter.Value -r > "/opt/vault/tls/vault-ca.pem"
  echo "update local CA"
  update-ca-trust force-enable
  ln -s /opt/vault/tls/vault-ca.pem ${LOCAL_CA_FILE}
  update-ca-trust extract
fi

echo "Get CA Key"
aws ssm get-parameter --name "/${APP_NAME}/${APP_ENV}/tls/ca-key" --with-decryption --region ${REGION} | jq .Parameter.Value -r > "/opt/vault/tls/vault-ca.key"

echo "Create a CSR"
openssl req -newkey rsa:2048 -nodes -sha256 -keyout \
   /opt/vault/tls/vault-server-key.pem -out /opt/vault/tls/vault.csr -subj "/CN=$1"

echo "Sign the CSR, resulting in CRT and add the v3 SAN extension"
openssl x509 -req -in /opt/vault/tls/vault.csr -out /opt/vault/tls/vault-server.pem \
    -CA /opt/vault/tls/vault-ca.pem -CAkey /opt/vault/tls/vault-ca.key -CAcreateserial \
    -sha256 -days 3650 \
    -extensions SAN -extfile <(printf "[SAN]\nsubjectAltName = @san_names\nbasicConstraints = CA:FALSE\nkeyUsage = nonRepudiation, digitalSignature, keyEncipherment\n[san_names]\nDNS.1 = vault\nDNS.2 = ${APP_NAME}.${APP_ENV}\nDNS.3 = $1\nIP.1 = 127.0.0.1\nIP.2 = ${SELF_IP}\n")

echo "cleanup CA"
rm -f /opt/vault/tls/vault-ca.key

EOF
chmod +x /opt/vault/bin/cert-utils
chown -R vault:vault /opt/vault/tls

vault -version

cat << EOF >  /etc/profile.d/vault.sh
export VAULT_ADDR=https://127.0.0.1:8200
EOF
