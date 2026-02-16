# Teleport Bootstrap — Open Source Extraction Tasks

---

## Task 1: Scaffold teleport-bootstrap repository [DONE]

- [x] Create directory structure (packer/, modules/, examples/, test/, .github/, docs/)
- [x] `git init`
- [x] Write `.gitignore`, `LICENSE` (MIT), `LICENSE_NOTICE.md`

**What exists on disk:** `teleport-bootstrap/.gitignore`, `LICENSE`, `LICENSE_NOTICE.md`, empty directory tree

---

## Task 2: Extract & sanitize EC2 Agent Pool module [DONE]

**Source:** `modules/ec2-teleport-agent-pool/`
**Target:** `teleport-bootstrap/modules/ec2-teleport-agent-pool/`

Copy these files with sanitizations:

- [x] `main.tf` — no internal refs, copy as-is
- [x] `iam.tf` — no internal refs, copy as-is
- [x] `teleport.tf` — no internal refs, copy as-is
- [x] `variables.tf` — **SANITIZE**: removed internal defaults i.e. `"foo.teleport.sh:443"` → required input with validation
- [x] `outputs.tf` — no internal refs, copy as-is
- [x] `versions.tf` — **UPDATE**: teleport provider `~> 15.0` → `~> 18.0`
- [x] `CHANGELOG.md` — **SANITIZE**: removed account ID, role name refs, projen/NX changelog entries; added v3.0.0 entry
- [x] `README.md` — **SANITIZE**: updated AMI source path, removed TODO comment

---

## Task 3: Extract & clean Kube Agent module [DONE]

**Source:** `modules/teleport-kube-agent/`
**Target:** `teleport-bootstrap/modules/teleport-kube-agent/`

- [x] Copy: main.tf, iam.tf, variables.tf, outputs.tf, versions.tf
- [x] Copy: CHANGELOG.md, README.md
- [x] **REMOVE**: package.json, project.json, .mbt.yml, .projen/ (build tooling) — not copied
- [x] **UPDATE**: teleport provider `~> 15.0` → `~> 18.0`
- [x] **SANITIZE**: grep for foo/internal refs — none found in source

---

## Task 4: Extract & sanitize Packer build [DONE]

**Source:** `packer/teleport-agent/`
**Target:** `teleport-bootstrap/packer/`

- [x] `build.pkr.hcl` — **SANITIZE**: removed account ID default, updated to v18.6.8, flattened paths, updated `/opt/teleport/scripts`
- [x] Extract variable blocks into `variables.pkr.hcl` — with validation on aws_account_id
- [x] `.auto.pkrvars.hcl` → `.auto.pkrvars.hcl.example` with placeholder VPC/subnet
- [x] `publish.pkrvars.hcl` → `publish.pkrvars.hcl.example` — all account IDs, org IDs, KMS ARNs replaced with `111111111111` placeholders
- [x] Copy `Makefile` — adjusted for flat layout (removed common.mk include)
- [x] Copy `assets/` tree — all `/opt/foo/` refs → `/opt/teleport/` in init.sh files
- [x] Copy `docs/teleport-agent.png`
- [x] `README.md` — sanitized: removed Google Drive link, updated version refs to v18.6.8, updated paths

---

## Task 5: Inline shared scripts [DONE]

- [x] `functions.sh` — kept only: `_add_svc_user()`, `_get_secrets()`, `_install_github_release()`. Removed `_install_awscli`, `_install_golang`, `_install_gh_cli_deb`.
- [x] `init-datadog.sh` — `source /opt/teleport/scripts/functions.sh`
- [x] `install-confd.sh` — `source /opt/teleport/scripts/functions.sh`
- [x] `install-teleport.sh` — `source /opt/teleport/scripts/functions.sh`
- [x] `install-datadog.sh` — no source path (standalone script), copied as-is
- [x] `assets/confd/init.sh` — `source /opt/teleport/scripts/functions.sh`
- [x] `assets/teleport-agent/init.sh` — `source /opt/teleport/scripts/functions.sh`

---

## Task 6: Adapt E2E tests [DONE]

**Source:** `packer/teleport-agent/test/`
**Target:** `teleport-bootstrap/test/`

- [x] `e2e_test.go` — adjusted `WorkingDir` to `../packer`, `Template` to `build.pkr.hcl`, `VarFiles` to `.auto.pkrvars.hcl`
- [x] `terraform/main.tf` — removed `foo.teleport.sh:443` (now variable), removed internal tags, updated module source to `../../modules/ec2-teleport-agent-pool`, updated teleport provider to `~> 18.0`
- [x] `terraform/variables.tf` — removed all default values for vpc_id, subnet_ids, datadog_api_key_arn (now required); added teleport_auth_server variable
- [x] `go.mod` — updated module name to `github.com/teleport-bootstrap/test`
- [x] `go.sum` — copied as-is
- [x] `Makefile` — removed `include .scripts/common.mk`; inlined REPO_ROOT/WORKING_DIR; updated packer init path
- [x] `teleport/terraform.yaml` — copied as-is (no internal refs)

---

## Task 7: Create example deployments [DONE]

**Target:** `teleport-bootstrap/examples/`

Each example needs: `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`, `README.md`
All use generic names: `myorg`, `example.teleport.sh`, `your-cluster.mongodb.net`, `111111111111` as account ID.

- [x] `rds-discovery/`
  - RDS auto-discovery, IAM auth, `rds-db:connect` policy
- [x] `elasticache-discovery/`
  - ElastiCache autodiscovery, managed IAM identities
  - Note v18 ElastiCache Serverless support
- [x] `mongodb-atlas/`
  - Static MongoDB, TLS CA cert bootstrap, `setproduct` for multi-env configs
- [x] `eks-kube-agent/`
  - IRSA setup, Helm chart reference, kube service
- [x] `complete/` — combined: SSH + RDS + ElastiCache + App service in one deployment

---

## Task 8: Adapt GitHub Actions workflows [DONE]

**Target:** `teleport-bootstrap/.github/workflows/`

- [x] `pr-test.yml` — from `.github/workflows/pr-packer-teleport-agent.yml`
  - Standalone trigger (not `workflow_call`)
  - AWS role ARN → `${{ secrets.AWS_ROLE_ARN_E2E }}`
  - Remove account ID from test variables, use `111111111111` placeholder
  - Update Teleport setup action to v18.6.8
  - Adjust working directories for flat layout
- [x] `build-and-publish.yml` — from `.github/workflows/packer-build-generic.yml` + `packer-all.yml`
  - Single-template (no generic dispatch)
  - AWS role ARN → secret
  - AMI map output to `ami_map.yaml` at repo root
  - Remove Slack webhook or gate on secret existence
  - Use standard `GITHUB_TOKEN` instead of GitHub App token
- [x] `lint.yml` — NEW
  - `packer validate`, `terraform fmt -check`, `terraform validate`, `shellcheck`

---

## Task 9: Write documentation [DONE]

- [x] `README.md` — project overview, architecture diagram, quickstart, prerequisites
- [x] `docs/architecture.md` — confd + SSM + systemd watcher pattern
- [x] `docs/datadog-integration.md` — DataDog setup (journald, OpenMetrics :3000/metrics)
- [x] `docs/terraform-cloud.md` — TF Cloud workspace setup, Teleport Machine ID for provider auth, variable mapping, VCS-driven workflows, when to use TFC Agents
- [x] `docs/upgrading-teleport.md` — v15→v16→v17→v18 path, breaking changes, compatibility rules
- [x] Document v18 features: ElastiCache Serverless, Multi-cluster discovery, Scoped join tokens, DiscoveryConfig in TF (covered in upgrading-teleport.md)

---

## Task 10: Final sanitization sweep [DONE]

Run greps against `teleport-bootstrap/` — ALL internal references must return zero hits:

Also verify:
- [ ] `packer validate` passes in `packer/`
- [ ] `terraform validate` passes for `modules/ec2-teleport-agent-pool/`
- [ ] `terraform validate` passes for `modules/teleport-kube-agent/`
- [ ] `terraform validate` passes for each `examples/*/`
- [ ] `shellcheck` passes for all `.sh` files

## Version Targets

| Component | From | To |
|-----------|------|----|
| Teleport agent (Packer) | `15.1.4` | `18.6.8` |
| Teleport TF provider | `~> 15.0` | `~> 18.0` |
| `teleport-actions/setup` (GHA) | v1 + `15.1.4` | v1 + `18.6.8` |
| confd | `0.19.2` | `0.19.2` (unchanged) |

---

## Future Work

### Upgrade base AMI from Amazon Linux 2 to Amazon Linux 2023

Amazon Linux 2 reaches end of standard support on June 30, 2025 (extended support available until 2028).

**What needs to change:**

- `packer/build.pkr.hcl` — update `source_ami_filter` from `amzn2-ami-minimal-*` to `al2023-ami-minimal-*`
- `packer/scripts/install-datadog.sh` — replace `yum` with `dnf` (AL2023 uses dnf natively)
- `packer/scripts/install-teleport.sh` — verify upstream install script supports AL2023
- `packer/scripts/install-confd.sh` — verify binary compatibility (should work as-is)
- `packer/assets/confd/confd.service` — verify systemd unit compatibility
- `packer/assets/datadog-agent/conf.d/journald.d/conf.yaml` — verify journal path (may change)
- Test all init scripts for shell compatibility (AL2023 uses bash 5.2+)
- Update `packer/README.md` to reflect new base image
