# Terraform Cloud Integration

This guide covers deploying the Teleport modules using [Terraform Cloud](https://www.hashicorp.com/products/terraform/cloud) (TFC) workspaces.

## Challenge: Teleport Provider Authentication

The `ec2-teleport-agent-pool` module uses the [Teleport Terraform provider](https://goteleport.com/docs/reference/terraform-provider/) to create `teleport_provision_token` resources directly in your Teleport cluster. This requires the Terraform runner to authenticate with Teleport.

Locally, you might use `tsh login` or an identity file. In Terraform Cloud, the runner is ephemeral — you need a persistent, renewable credential.

## Recommended: Teleport Machine ID

[Machine ID](https://goteleport.com/docs/machine-id/introduction/) provides automated, renewable credentials for CI/CD systems.

### Setup

1. **Create a Machine ID bot** in your Teleport cluster:
   ```bash
   tctl bots add terraform-cloud --roles=terraform-provider
   ```

2. **Create a role** with the minimum permissions needed:
   ```yaml
   kind: role
   version: v7
   metadata:
     name: terraform-provider
   spec:
     allow:
       rules:
         - resources: [token]
           verbs: [list, create, read, update, delete]
   ```

3. **Configure the bot to use IAM join** (recommended for AWS-hosted TFC agents) or **token join** (for TFC-managed runners).

4. **Set provider configuration** in your Terraform:
   ```hcl
   provider "teleport" {
     addr               = "teleport.example.com:443"
     join_method        = "iam"       # or use identity_file_path
     join_token         = "terraform"
     is_terraform_cloud = true        # Important: enables TFC-compatible auth
   }
   ```

### Provider Variables

Set these in your TFC workspace variables:

| Variable | Type | Description |
|----------|------|-------------|
| `TF_VAR_teleport_auth_server` | Terraform | Teleport proxy address (`host:443`) |
| `TELEPORT_IDENTITY_FILE` | Environment | Path to Machine ID identity file (if using file-based auth) |

## Workspace Configuration

### VCS-Driven Workflow

For a VCS-driven workspace pointing at this repository:

```hcl
# Example workspace settings
terraform_working_directory = "examples/rds-discovery"
```

**Variable sets** work well for shared values across multiple agent pool workspaces:

| Variable | Scope | Example |
|----------|-------|---------|
| `teleport_auth_server` | Variable Set (shared) | `teleport.example.com:443` |
| `datadog_api_key_arn` | Variable Set (shared) | `arn:aws:secretsmanager:...` |
| `ami_id` | Workspace | `ami-0123456789abcdef0` |
| `vpc_id` | Workspace | `vpc-0123456789abcdef0` |
| `subnet_ids` | Workspace | `["subnet-aaa", "subnet-bbb"]` |
| `name_prefix` | Workspace | `myapp-prod-rds-agents` |

### AWS Authentication

Use [dynamic provider credentials](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration) (OIDC) for AWS authentication:

1. Create an IAM OIDC provider for `app.terraform.io`
2. Create an IAM role with trust policy for your TFC organization
3. Set `TFC_AWS_PROVIDER_AUTH=true` and `TFC_AWS_RUN_ROLE_ARN` in workspace environment variables

### Variable Mapping

Map the module's required variables to TFC workspace variables:

```hcl
# terraform.auto.tfvars (committed, non-sensitive)
name_prefix = "prod-rds-agents"
aws_region  = "us-east-1"

# TFC workspace variables (sensitive)
# ami_id             = "ami-..."
# vpc_id             = "vpc-..."
# subnet_ids         = '["subnet-...", "subnet-..."]'
# datadog_api_key_arn = "arn:aws:secretsmanager:..."
# teleport_auth_server = "teleport.example.com:443"
```

## When to Use TFC Agents

By default, TFC runs Terraform in HashiCorp-managed runners. If your infrastructure requires **private network access** (e.g., the Teleport auth server is not publicly accessible), use [TFC Agents](https://developer.hashicorp.com/terraform/cloud-docs/agents):

**Use TFC Agents when:**
- Your Teleport cluster is in a private VPC (no public proxy endpoint)
- AWS resources (VPC, subnets) are not reachable from the public internet
- You need to run `packer build` from within your network
- Security policy requires all Terraform operations to originate from your infrastructure

**Use standard runners when:**
- Your Teleport proxy has a public endpoint (common with Teleport Cloud)
- AWS API calls don't require VPC-level network access
- You prefer the simplicity of managed infrastructure

### Agent Pool Setup

```bash
# Create an agent pool in TFC
# Then run the agent in your VPC (ECS, EKS, or EC2)
tfc-agent -name "teleport-infra" -token "<agent-token>"
```

## Multiple Agent Pools

A common pattern is one TFC workspace per agent pool (per AWS account/region/purpose):

```
workspaces/
├── prod-us-east-1-rds-agents/      # RDS discovery in us-east-1
├── prod-eu-west-1-rds-agents/      # RDS discovery in eu-west-1
├── prod-elasticache-agents/         # ElastiCache discovery
├── staging-all-agents/              # Staging (all services)
└── eks-kube-agents/                 # EKS kube agent IRSA
```

Use **variable sets** to share common values (Teleport address, DataDog ARN) across all workspaces, and workspace-specific variables for VPC, subnet, and name prefix.

## CI/CD Pipeline

For AMI builds that feed into agent pool deployments:

1. **Build AMI** (GitHub Actions workflow in this repo) — outputs `ami_id`
2. **Update TFC variable** — set `ami_id` in each workspace
3. **Trigger TFC run** — apply the new AMI to rolling-refresh the ASG

The `build-and-publish.yml` workflow can output an `ami_map.yaml` artifact. Use the [TFC API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/workspace-variables) or [tfc-operator](https://github.com/hashicorp/terraform-cloud-operator) to automate variable updates.
