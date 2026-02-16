#!/bin/bash -ex

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

# ref: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html
imds_token=$(curl -fsX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
export AWS_DEFAULT_REGION=$(curl -LfsH "X-aws-ec2-metadata-token: $${imds_token}" http://169.254.169.254/latest/meta-data/placement/region)

/opt/teleport/scripts/init-datadog.sh \
  -k ${datadog_api_key_arn} \
  -t ${datadog_host_tags}
/home/teleport/init.sh
/home/confd/init.sh -p ${name_prefix}

# Restart datadog-agent to pick up configuration changes
systemctl restart datadog-agent

%{ for command in bootstrap_commands ~}
${command}
%{ endfor ~}
