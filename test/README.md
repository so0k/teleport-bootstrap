# E2E Testing

End-to-end test for the Teleport agent bootstrap toolkit. Builds a Packer AMI, deploys it via Terraform, and validates the full boot chain (cloud-init → confd → teleport).

## Prerequisites

- AWS credentials for a sandbox account
- Teleport v18.6.8 binary installed locally
- Packer >= 1.9.0
- Terraform >= 1.3

## AWS Setup

The sandbox account needs a KMS key for encrypted AMI builds and a mock Secrets Manager secret for DataDog.

### 1. Create KMS key for Packer EBS encryption

```bash
# Create the key
aws kms create-key --description "Packer EBS encryption for teleport-bootstrap" --region us-east-1

# Note the KeyId from the output, then create the alias
aws kms create-alias --alias-name "alias/packer-ebs" --target-key-id <key-id> --region us-east-1
```

### 2. Grant ASG service-linked role access to KMS key

The ASG service-linked role needs `kms:CreateGrant` to launch instances with KMS-encrypted AMIs:

```bash
aws kms create-grant \
  --key-id <key-id> \
  --grantee-principal "arn:aws:iam::<account-id>:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling" \
  --operations "Encrypt" "Decrypt" "ReEncryptFrom" "ReEncryptTo" "GenerateDataKey" "GenerateDataKeyWithoutPlaintext" "DescribeKey" "CreateGrant" \
  --region us-east-1
```

### 3. Create mock DataDog API key secret

```bash
aws secretsmanager create-secret \
  --name "teleport-bootstrap/e2e/datadog-api-key" \
  --secret-string "mock-datadog-api-key-for-testing" \
  --region us-east-1
```

Note the ARN from the output — it goes into `test/terraform/terraform.tfvars`.

## Running the Test

### 1. Build the AMI

```bash
cd packer
packer init .
packer build -var "vpc_id=<vpc-id>" -var "subnet_id=<subnet-id>" -var "aws_account_id=<account-id>" .
```

Note the AMI ID from the output.

### 2. Start local Teleport cluster

```bash
cd test
make setup
```

This starts a local Teleport v18.6.8 auth server and generates `test/terraform/teleport-identity`.

### 3. Create terraform.tfvars

```bash
cat > test/terraform/terraform.tfvars <<'TFVARS'
vpc_id             = "<vpc-id>"
subnet_ids         = ["<subnet-id-1>", "<subnet-id-2>"]
datadog_api_key_arn = "<secret-arn-from-step-3>"
TFVARS
```

### 4. Deploy and validate

```bash
cd test/terraform
terraform init
TF_TELEPORT_IDENTITY_FILE_PATH=./teleport-identity TF_TELEPORT_ADDR=0.0.0.0:3025 \
  terraform apply -var "name_prefix=e2e-sandbox" -var "ami_id=<ami-id>"
```

### 5. Validate SSM parameter locally

```bash
aws ssm get-parameter --name "/<name-prefix>/teleport-etc/contents" \
  --query 'Parameter.Value' --output text --region us-east-1 > /tmp/teleport-e2e.yaml
teleport configure --test /tmp/teleport-e2e.yaml
```

### 6. Validate runtime via SSM

```bash
aws ssm send-command \
  --instance-ids "<instance-id>" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cloud-init status","systemctl status confd --no-pager","systemctl status teleport --no-pager","systemctl status teleport-watcher.path --no-pager","ls -la /etc/teleport.yaml","ls -la /opt/teleport/scripts/"]' \
  --region us-east-1 \
  --query 'Command.CommandId' --output text

# Retrieve output
aws ssm get-command-invocation \
  --command-id "<command-id>" \
  --instance-id "<instance-id>" \
  --region us-east-1 \
  --query '[Status, StandardOutputContent]' --output text
```

Expected: cloud-init done, confd active, teleport-watcher.path active, teleport active, all scripts executable.

## Cleanup

```bash
# Terraform resources
cd test/terraform
TF_TELEPORT_IDENTITY_FILE_PATH=./teleport-identity TF_TELEPORT_ADDR=0.0.0.0:3025 \
  terraform destroy -var "name_prefix=e2e-sandbox" -var "ami_id=<ami-id>"

# Local Teleport cluster
cd test && make teardown

# Packer AMI
aws ec2 deregister-image --image-id <ami-id> --region us-east-1
aws ec2 describe-snapshots --owner-ids self --filters "Name=description,Values=*<ami-id>*" \
  --query 'Snapshots[*].SnapshotId' --output text --region us-east-1 \
  | xargs -I{} aws ec2 delete-snapshot --snapshot-id {} --region us-east-1

# Secrets Manager
aws secretsmanager delete-secret --secret-id "teleport-bootstrap/e2e/datadog-api-key" \
  --force-delete-without-recovery --region us-east-1

# KMS key (schedules deletion in 7 days)
aws kms delete-alias --alias-name "alias/packer-ebs" --region us-east-1
aws kms schedule-key-deletion --key-id <key-id> --pending-window-in-days 7 --region us-east-1
```
