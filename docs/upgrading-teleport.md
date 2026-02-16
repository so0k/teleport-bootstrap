# Upgrading Teleport

This guide covers upgrading the Teleport agent infrastructure across major versions.

## Version Compatibility Rules

Teleport enforces strict version compatibility between the auth server (cluster) and agents:

- **Agents must be the same major version or one major version behind the auth server.** For example, a v18 auth server supports v18 and v17 agents, but not v16.
- **Always upgrade the auth server (cluster) first**, then upgrade agents.
- **Never skip major versions** when upgrading agents. Go v15 → v16 → v17 → v18, not v15 → v18.

## Current Target

This repository targets **Teleport v18.6.8**.

## Upgrade Path: v15 → v18

If you're running v15 agents, you must upgrade through each major version:

### Step 1: v15 → v16

**Breaking changes in v16:**

- **License change**: Teleport v16+ requires a commercial license for Enterprise features. Community Edition remains Apache 2.0. See [LICENSE_NOTICE.md](../LICENSE_NOTICE.md).
- **Deprecated `teleport configure` flags** removed. If your setup used CLI-generated configs, verify compatibility.
- **Database protocol changes**: Some database protocol handlers were refactored. Test database access after upgrade.

**Upgrade steps:**

1. Update the Packer variable: `teleport_version = "16.x.x"` (use latest v16 patch)
2. Build a new AMI: `packer build .`
3. Update the Terraform provider constraint: `version = "~> 16.0"`
4. Update `ami_id` in your Terraform variables
5. `terraform apply` — the ASG will perform a rolling refresh

### Step 2: v16 → v17

**Breaking changes in v17:**

- **Config v3 required**: The `version: v3` config format is mandatory. Earlier formats are rejected. This repository already uses v3.
- **`discovery_service` changes**: Discovery groups became mandatory for multi-agent setups. The module already sets `discovery_group` from `name_prefix`.
- **Removed legacy join methods**: Only `iam`, `ec2`, `token`, and other documented methods are supported.

**Upgrade steps:**

Same as v15 → v16 — update version, rebuild AMI, update Terraform provider and `ami_id`, apply.

### Step 3: v17 → v18

**New features in v18:**

- **ElastiCache Serverless** discovery support — the module's `elasticache` discovery type now finds Serverless clusters in addition to replication groups
- **Scoped join tokens** — tokens are restricted to only the roles (Node, Db, App, Discovery) that are enabled, reducing blast radius
- **DiscoveryConfig as Terraform resource** — `teleport_discovery_config` lets you manage discovery configuration declaratively (alternative to the `discovery_service` block in agent config)
- **Managed IAM identities for ElastiCache/MemoryDB** — Teleport can self-manage the agent's IAM policy to grant access to newly discovered caches
- **Multi-cluster discovery** — a single discovery agent can discover resources across multiple AWS accounts/regions

**Breaking changes in v18:**

- **Minimum Go version** bumped for the Terraform provider. Ensure your Terraform version is >= 1.3.
- **Deprecated `db_service.databases[].aws.redshift` fields** removed. Use `redshift-serverless` type instead.
- **Token `spec.allow` format** tightened — ARN patterns must be valid.

**Upgrade steps:**

Same as above — update version, rebuild AMI, update Terraform, apply.

## Upgrade Procedure (Detailed)

### 1. Update Packer build

In `packer/variables.pkr.hcl` (or your `.auto.pkrvars.hcl`):

```hcl
teleport_version = "18.6.8"  # Target version
```

Build and test:

```bash
cd packer/
packer init .
packer build .
# Note the AMI ID from the output
```

### 2. Update Terraform modules

In your deployment (e.g., `examples/rds-discovery/main.tf`), ensure the provider version matches:

```hcl
teleport = {
  source  = "terraform.releases.teleport.dev/gravitational/teleport"
  version = "~> 18.0"
}
```

Update the `ami_id` variable to the newly built AMI.

### 3. Plan and apply

```bash
terraform plan    # Review changes — expect ASG launch template update
terraform apply   # Rolling refresh replaces instances with new AMI
```

The ASG's rolling instance refresh strategy ensures:
- New instances launch with the new AMI
- Old instances are terminated gradually
- The agent pool maintains capacity throughout the upgrade

### 4. Verify

```bash
# Check agent versions in the Teleport cluster
tctl nodes ls --format=json | jq '.[].spec.version'

# Check database agents
tctl db ls --format=json | jq '.[].spec.version'

# Verify discovery is working
tctl db ls  # Should show discovered databases
```

## Rollback

If an upgrade causes issues:

1. **Revert `ami_id`** to the previous AMI in Terraform
2. `terraform apply` — ASG performs rolling refresh back to old AMI
3. Agents rejoin the cluster with the previous version

The AMI-based approach makes rollback straightforward — there's no in-place upgrade to undo.

## Testing Upgrades

Use the E2E test suite to validate upgrades before production:

```bash
cd test/
# Build AMI with new version and deploy against a local Teleport cluster
go test -v -timeout 30m
```

The test spins up a local Teleport cluster, builds an AMI, deploys it via the EC2 module, and verifies the agent joins successfully.

## Version Matrix

| Component | v15 | v16 | v17 | v18 |
|-----------|-----|-----|-----|-----|
| Teleport agent binary | 15.x.x | 16.x.x | 17.x.x | 18.6.8 |
| Terraform provider | ~> 15.0 | ~> 16.0 | ~> 17.0 | ~> 18.0 |
| Config format | v2/v3 | v3 | v3 | v3 |
| ElastiCache Serverless | No | No | No | Yes |
| Managed IAM identities | Partial | Yes | Yes | Yes |
| Scoped join tokens | No | No | Partial | Yes |
| DiscoveryConfig TF resource | No | No | No | Yes |
