#!/bin/bash
yum -y check-update
yum update -y
yum install -q -y wget unzip bind-utils ruby rubygems jq amazon-efs-utils awscli nano


echo "Install Chrony"
yum -y install chrony

cat << EOF > /etc/chrony.conf
pool 2.rhel.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
keyfile /etc/chrony.keys
leapsectz right/UTC
logdir /var/log/chrony
server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4
EOF
systemctl enable chronyd.service
systemctl start chronyd.service
# chronyc tracking
# chronyc sources



REGION=$(curl --silent http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
ARCH=$(uname -m)
if [[ $ARCH == "aarch64" ]]; then
    URL="https://s3.$REGION.amazonaws.com/amazon-ssm-$REGION/latest/linux_arm64/amazon-ssm-agent.rpm"
elif [[ $ARCH == "x86_64" ]]; then
    URL="https://s3.$REGION.amazonaws.com/amazon-ssm-$REGION/latest/linux_amd64/amazon-ssm-agent.rpm"
else
    echo "arch $ARCH not supported"
    exit 1
fi

echo "Install AWS SSM Agent from: $URL"
yum install -y $URL

echo "Install Cloudwatch"
yum install amazon-cloudwatch-agent -y
echo "Config Cloudwatch Agent"

cat << EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 300,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "logs": {
        "force_flush_interval": 15,
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/vault_audit.log",
                        "log_group_name": "#APP_NAME-#APP_ENV-vaultaudit",
                        "log_stream_name": "{instance_id}",
                        "timezone": "Local"
                    },
                    {
                        "file_path": "/var/log/secure",
                        "log_group_name": "#APP_NAME-#APP_ENV-secure",
                        "log_stream_name": "{instance_id}",
                        "timezone": "Local"
                    },
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "#APP_NAME-#APP_ENVE-messages",
                        "log_stream_name": "{instance_id}",
                        "timezone": "Local"
                    }
                ]
            }
        }
    },
  "metrics": {
    "namespace": "#CW-NS",
    "metrics_collected": {
      "statsd":{
        "service_address":"127.0.0.1:8125",
        "metrics_collection_interval":60,
        "metrics_aggregation_interval":300
      },
      "disk": {
        "metrics_collection_interval": 600,
        "resources": [
          "/"
        ],
        "measurement": [
          {"name": "disk_free", "rename": "DISK_FREE", "unit": "Gigabytes"}
        ]
      },
      "mem": {
        "metrics_collection_interval": 600,
        "measurement": [
          {"name": "mem_free", "rename": "MEM_FREE", "unit": "Megabytes"},
          {"name": "mem_total", "rename": "MEM_TOTAL", "unit": "Megabytes"},
          {"name": "mem_used", "rename": "MEM_USED", "unit": "Megabytes"}
        ]
      }
    },
    "append_dimensions": {
      "ImageId": "%${aws:ImageId}",
      "InstanceId": "%${aws:InstanceId}",
      "InstanceType": "%${aws:InstanceType}",
      "AutoScalingGroupName": "%${aws:AutoScalingGroupName}"
    },
    "aggregation_dimensions" : [["AutoScalingGroupName"], ["InstanceId", "InstanceType"],[]]

  }
}
EOF
systemctl enable amazon-cloudwatch-agent.service



# Disable Core Dumps
echo 'ulimit -c 0 > /dev/null 2>&1' > /etc/profile.d/disable-coredumps.sh
# Adjusting ulimits for vault user
cat << EOF > /etc/security/limits.conf
vault          soft    nofile          65536
vault          hard    nofile          65536
vault          soft    nproc           65536
vault          hard    nproc           65536
EOF

cat << EOF > /etc/sysctl.d/99-custom.conf
net.ipv4.ip_forward=0
net.ipv4.route.flush=1
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.log_martians=1
net.ipv4.conf.default.secure_redirects=0
net.ipv6.route.flush=1
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.all.forwarding=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.default.accept_source_route=0
EOF
sysctl -p -q /etc/sysctl.d/99-custom.conf


# echo "Install AWS Inspector"
# curl -Ls https://inspector-agent.amazonaws.com/linux/latest/install
# chmod +x ./install-inspector
# ./install-inspector
# rm -f ./install-inspector
