# Complete Example — Kitchen Sink

This example deploys a single Teleport agent pool with **every supported service enabled**, making it a convenient reference for all module capabilities combined in one configuration.

## What's included

- **SSH service** — agent node is accessible via Teleport with custom labels (`role=complete-agent`, `env=production`)
- **App service** — proxies a local application (`internal-dashboard` at `http://localhost:8080`) through Teleport
- **Database service** with:
  - AWS auto-discovery matchers for **RDS** and **ElastiCache**
  - A **static MongoDB** database (e.g. MongoDB Atlas) with TLS CA certificate
- **Discovery service** — discovers RDS instances/clusters and ElastiCache replication groups by tag
- **ElastiCache IAM policies** — both auto-discovery and access policies enabled
- **Additional inline IAM policies** for:
  - `rds-db:connect` (RDS IAM authentication)
  - `rds:Describe*` (RDS discovery)
  - `sts:AssumeRole` (cross-account or dedicated MongoDB access role)
- **Bootstrap commands** — downloads a CA certificate for MongoDB TLS verification on instance boot
- **SSM Intelligent-Tiering** — automatically upgrades the SSM parameter to Advanced tier when the combined config exceeds 4 KB

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

## Prerequisites

- A Teleport cluster reachable at the address specified in `teleport_auth_server`
- A Teleport IAM join token named `terraform` for the Teleport Terraform provider
- An AMI built with the Teleport agent and DataDog agent (ARM/Graviton)
- An AWS Secrets Manager secret containing your DataDog API key
- Network connectivity from the agent subnets to your RDS, ElastiCache, and MongoDB endpoints

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `name_prefix` | Prefix applied to all resources | `string` | yes |
| `ami_id` | AMI ID for agent instances (ARM/Graviton) | `string` | yes |
| `vpc_id` | VPC ID for deployment | `string` | yes |
| `subnet_ids` | Subnet IDs for the Auto Scaling Group | `list(string)` | yes |
| `aws_region` | AWS region | `string` | no (default: `us-east-1`) |
| `datadog_api_key_arn` | Secrets Manager ARN for DataDog API key | `string` | yes |
| `datadog_host_tags` | DataDog host tags | `string` | no |
| `teleport_auth_server` | Teleport auth server address with port | `string` | yes |

## Outputs

| Name | Description |
|------|-------------|
| `asg_name` | Auto Scaling Group name |
| `role_arn` | IAM Role ARN for the agent instances |
| `security_group_id` | Security Group ID for the agent instances |
| `instance_profile_arn` | Instance Profile ARN for the agent instances |
