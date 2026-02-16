# CLAUDE.md — Agent Guide for teleport-bootstrap

## What This Repo Is

Production-ready IaC toolkit for deploying [Teleport](https://goteleport.com/) agents on AWS. Targets **Teleport v18.6.8**. Three layers: Packer AMI build, Terraform modules, and runtime dynamic config via confd + SSM.

## Quick Reference

| Tool | Version Constraint | Notes |
|------|-------------------|-------|
| Terraform | >= 1.3 | HCL only, no CDKTF |
| AWS provider | ~> 5.0 | |
| Teleport provider | ~> 18.0 | Source: `terraform.releases.teleport.dev/gravitational/teleport` |
| Packer | ~> 1.9.0 | HCL format, Amazon EBS builder |
| Go | see `test/go.mod` | Terratest E2E tests |
| Target OS | Amazon Linux 2 | ARM64 (Graviton) by default |

## Repository Layout

```
packer/                         # AMI build
  build.pkr.hcl                 # Main template — AL2, ARM, IMDSv2, KMS encrypted
  variables.pkr.hcl             # 8 variables (vpc_id, subnet_id, aws_account_id, etc.)
  scripts/                      # Install scripts run during AMI build
    functions.sh                # Shared: _add_svc_user, _get_secrets, _install_github_release
    install-teleport.sh         # Creates teleport user, runs upstream installer
    install-confd.sh            # Downloads confd 0.19.2 binary
    install-datadog.sh          # YUM installs datadog-agent
    init-datadog.sh             # Runtime: fetches DD API key from Secrets Manager
  assets/                       # Config files baked into AMI at /tmp/build-assets
    confd/                      # confd daemon: systemd unit, config template, init script
    teleport-agent/             # Teleport: systemd watcher (.path + .service), confd templates, init
    datadog-agent/              # DataDog: journald + OpenMetrics check configs

modules/
  ec2-teleport-agent-pool/      # Primary module — ASG, IAM, SSM config, join token
    main.tf                     # Launch template, ASG (mixed instances), security group
    iam.tf                      # IAM role + policies (SSM, Secrets Manager, optional RDS/ElastiCache)
    teleport.tf                 # Builds teleport.yaml via yamlencode(merge(...)), SSM parameter, join token
    variables.tf                # 50+ variables — services toggled via object({ enabled = bool, ... })
    outputs.tf                  # security_group_id, role_arn, instance_profile_arn, asg_arn, etc.
    config/cloud-init.sh.tpl    # cloud-init user data (runs init scripts, starts confd + teleport)
  teleport-kube-agent/          # Secondary module — IRSA role + join token for EKS Helm deploys
    main.tf                     # Join token with service-scoped roles
    iam.tf                      # IRSA assume-role for EKS service accounts
    variables.tf                # 9 variables (eks_cluster_name, service enable flags)

examples/                       # 5 complete deployment examples
  rds-discovery/                # RDS auto-discovery + IAM auth
  elasticache-discovery/        # ElastiCache + managed IAM identities
  mongodb-atlas/                # Static MongoDB Atlas with TLS + setproduct pattern
  eks-kube-agent/               # EKS kube agent via IRSA + Helm
  complete/                     # All services combined in one deployment

test/                           # Terratest E2E
  e2e_test.go                   # Builds AMI, deploys module, validates agent join
  terraform/                    # Test fixture (no hardcoded values)
  Makefile                      # make setup/teardown for local Teleport cluster

.github/workflows/
  lint.yml                      # packer validate, terraform fmt/validate, shellcheck
  pr-test.yml                   # E2E test on PRs (build AMI + deploy + validate)
  build-and-publish.yml         # Build on main, publish cross-region, create AMI map PR
```

## Architecture — How It Works

```
Build time (Packer)     Deploy time (Terraform)     Runtime (EC2)
─────────────────────   ────────────────────────     ──────────────────────────
AL2 AMI with:           Creates:                     Boot sequence:
 - Teleport v18.6.8     - ASG + launch template      1. cloud-init runs init scripts
 - confd 0.19.2         - IAM role + policies         2. init-datadog.sh fetches DD key
 - DataDog agent         - SSM param (teleport.yaml)  3. confd starts, reads SSM param
 - systemd units         - teleport_provision_token    4. confd renders /etc/teleport.yaml
                                                       5. systemd path unit detects change
                                                       6. teleport.service starts
                                                       7. Agent joins via IAM method

Config update flow:
  terraform apply → SSM param updated → confd polls (60s) →
    /etc/teleport.yaml rewritten → systemd path triggers → teleport restarts
```

## Key Patterns

### Service toggles (ec2-teleport-agent-pool)
Services are enabled/disabled via typed objects. Only enabled services appear in the rendered YAML and join token roles:
```hcl
teleport_ssh_service       = { enabled = true, ... }
teleport_db_service        = { enabled = true, ... }
teleport_discovery_service = { enabled = false }  # omitted from config
```
The join token's `roles` list is built dynamically from which services are enabled (see `teleport.tf:5-10`).

### Config rendering (teleport.tf)
Full `teleport.yaml` is built in Terraform via `yamlencode(merge(base_config, ...conditional_services...))` and stored in SSM Parameter Store — not templated on the instance.

### IAM join method
Agents authenticate using their EC2 instance role ARN. The `teleport_provision_token` resource scopes access to `assumed-role/<role-name>/i-*`. No static secrets are distributed to instances.

### AMI paths
All scripts and assets live under `/opt/teleport/scripts/` on the AMI.

## Validation Commands

```bash
# Packer
cd packer && packer init . && packer validate -syntax-only .

# Terraform modules
cd modules/ec2-teleport-agent-pool && terraform init -backend=false && terraform validate
cd modules/teleport-kube-agent && terraform init -backend=false && terraform validate

# Examples (each needs its own init)
cd examples/rds-discovery && terraform init -backend=false && terraform validate

# Shell scripts
shellcheck packer/scripts/*.sh

# E2E tests (requires AWS creds + local Teleport cluster)
cd test && make setup && go test -v -timeout 30m && make teardown
```

## Conventions

- **Terraform style**: `terraform fmt` enforced in CI. Use `snake_case` for all resource names and variables.
- **Variable defaults**: Required variables have no default. Optional variables have sensible defaults. Validated with `validation {}` blocks where appropriate.
- **Examples**: Each example is self-contained with `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, and `README.md`. All use generic placeholder values (`myorg`, `example.teleport.sh`, `000000000000`).
- **Shell scripts**: Must pass `shellcheck`. Source shared functions from `/opt/teleport/scripts/functions.sh`.
- **No build tooling**: No projen, NX, MBT, or CDK wrappers. Pure HCL + shell + Go.
- **Provider source**: Teleport provider is at `terraform.releases.teleport.dev/gravitational/teleport`, not the HashiCorp registry.

## Sensitive Data — Do Not Introduce

This repo was sanitized from an internal codebase. Never add:
- Real AWS account IDs (use `000000000000` in examples)
- Real VPC/subnet IDs (use `vpc-example`, `subnet-example`)
- Company-specific names, domains, or org references
- Hardcoded ARNs with real account numbers

## Files You Can Ignore

- `TODO.md` — Internal extraction tracking doc, not part of the public project
- `docs/*.excalidraw` — Excalidraw source files for diagrams (PNGs are the rendered output)
- `docs/build-component-diagram.mjs` — Programmatic diagram generator script
- `manifest.json` — Packer build output (gitignored)
