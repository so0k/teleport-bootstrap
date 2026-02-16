# ElastiCache Discovery Example

This example deploys a pool of Teleport agents that automatically discover and
proxy AWS ElastiCache (Redis) clusters using the Teleport Discovery Service and
Database Service.

## What it does

1. **Discovery Service** continuously scans the target AWS region for
   ElastiCache replication groups matching the configured tags and registers
   them with the Teleport cluster.
2. **Database Service** picks up the dynamically registered ElastiCache
   databases and acts as a proxy so that users can connect via `tsh db connect`.
3. **Managed IAM Identities** allow Teleport to self-manage the agent's IAM
   role policy, dynamically granting access to newly discovered clusters without
   manual IAM changes.
4. **SSH Service** is enabled on each agent node for operational access and
   troubleshooting.

## Teleport v18 ElastiCache Serverless support

Starting with Teleport v18, the Discovery Service can auto-discover
**ElastiCache Serverless** caches in addition to classic replication-group-based
clusters. No extra configuration is required -- the `elasticache` discovery type
covers both variants. Ensure the agent AMI runs Teleport v18+ and that the IAM
policies created by this module (autodiscovery and access) are enabled.

See the upstream documentation for details:
<https://goteleport.com/docs/database-access/guides/aws-elasticache/>

## Prerequisites

- A running Teleport cluster (v18+) with a reachable proxy address.
- A Teleport agent AMI built for ARM/Graviton (see the `packer/` directory).
- A VPC with private subnets that have outbound internet access (NAT gateway or
  VPC endpoints) so agents can reach the Teleport proxy and AWS APIs.
- ElastiCache clusters tagged with the discovery tags (default:
  `teleport-discovery = enabled`).
- An AWS Secrets Manager secret containing your DataDog API key.
- The Teleport Terraform provider configured via environment variables or an
  identity file.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

## IAM policies created

| Policy | Purpose |
|--------|---------|
| ElastiCache Autodiscovery | `elasticache:Describe*`, `ListTagsForResource` for cluster enumeration |
| ElastiCache Access | `elasticache:Connect`, `elasticache:DescribeUsers`, `elasticache:ModifyUser` for authentication and password rotation |
| Managed IAM Identities | `iam:GetRolePolicy`, `iam:PutRolePolicy`, `iam:DeleteRolePolicy` scoped to the agent role, so Teleport can self-manage access policies |

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name_prefix` | Prefix for all created resources | `string` | -- |
| `ami_id` | Teleport agent AMI (ARM) | `string` | -- |
| `vpc_id` | VPC ID | `string` | -- |
| `subnet_ids` | Subnets for the ASG | `list(string)` | -- |
| `aws_region` | AWS region | `string` | `us-east-1` |
| `datadog_api_key_arn` | Secrets Manager ARN for DataDog API key | `string` | -- |
| `datadog_host_tags` | DataDog host tags | `string` | -- |
| `teleport_auth_server` | Teleport proxy address (host:port) | `string` | -- |
| `elasticache_discovery_tags` | AWS tags used to filter discovered clusters | `map(string)` | `{"teleport-discovery" = "enabled"}` |

## Outputs

| Name | Description |
|------|-------------|
| `asg_name` | Auto Scaling Group name |
| `role_arn` | IAM role ARN for the agent instances |
| `security_group_id` | Security group ID for the agent instances |
