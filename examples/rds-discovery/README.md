# RDS Auto-Discovery Example

This example deploys a Teleport agent pool that automatically discovers and proxies AWS RDS databases.

It enables three Teleport services on the agent:

- **Discovery Service** -- scans AWS for RDS instances and Aurora clusters matching the configured tags and registers them in the Teleport cluster.
- **Database Service** -- proxies connections to the discovered databases so users can connect through `tsh db connect`.
- **SSH Service** -- keeps the agent node itself accessible for operational troubleshooting.

## Prerequisites

1. A running Teleport cluster (v18+) with a reachable auth server address.
2. A Teleport IAM join token named `terraform` configured to allow the agent instances to join.
3. An AMI built with the Teleport agent and DataDog agent installed (see `packer/` in this repository).
4. A VPC with private subnets that can reach both the Teleport auth server and the target RDS instances.
5. A DataDog API key stored in AWS Secrets Manager.
6. RDS instances configured for [IAM database authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html).

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real values

terraform init
terraform plan
terraform apply
```

After the agent instances launch and join the cluster, discovered databases will appear in `tsh db ls`.

## IAM Policies

The module attaches two additional inline policies to the agent instance role:

| Policy | Purpose |
|--------|---------|
| `rds-discovery` | Allows `rds:DescribeDBInstances` and `rds:DescribeDBClusters` so the Discovery Service can enumerate RDS resources. |
| `rds-connect` | Allows `rds-db:connect` so the Database Service can authenticate to RDS using IAM auth. The resource ARN is scoped to the deployment region and account. |

If you need to restrict which database users the agent can connect as, narrow the resource ARN in the `rds-connect` policy from `dbuser:*/*` to specific DB resource IDs and usernames.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `name_prefix` | Prefix for all created resources | -- |
| `ami_id` | AMI ID (ARM/Graviton) with Teleport agent | -- |
| `vpc_id` | VPC ID for deployment | -- |
| `subnet_ids` | Subnets for the ASG | -- |
| `aws_region` | AWS region | `us-east-1` |
| `datadog_api_key_arn` | Secrets Manager ARN for DataDog API key | -- |
| `datadog_host_tags` | DataDog host tags | `env:prod,service:teleport-agent` |
| `teleport_auth_server` | Teleport auth server address (host:port) | -- |
| `rds_discovery_tags` | AWS tags to filter discovered RDS instances | `{"*"="*"}` |

## Outputs

| Name | Description |
|------|-------------|
| `asg_name` | Auto Scaling Group name |
| `role_arn` | IAM Role ARN for the agent instances |
| `security_group_id` | Security Group ID for the agent instances |
