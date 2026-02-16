# DataDog Integration

The Teleport agent AMI ships with DataDog Agent 7 pre-installed and pre-configured. Only the API key is injected at runtime.

## How It Works

### Build time (Packer)

The `install-datadog.sh` script runs during the AMI build:

1. Adds the official DataDog YUM repository
2. Installs `datadog-agent` package
3. Adds `dd-agent` to the `systemd-journal` group (required for journald log collection)
4. Copies pre-built config files from the `assets/datadog-agent/` directory

### Runtime (cloud-init)

The `init-datadog.sh` script runs on every instance boot:

```bash
/opt/teleport/scripts/init-datadog.sh \
  -k ${datadog_api_key_arn} \
  -t ${datadog_host_tags}
```

It fetches the API key from AWS Secrets Manager and writes it to `/etc/datadog-agent/datadog.yaml`. Host tags are converted from comma-separated format to YAML array.

After confd and Teleport are initialized, cloud-init restarts the DataDog agent to pick up any final config changes.

## Monitoring Configuration

### Journald Logs

**Config:** `packer/assets/datadog-agent/conf.d/journald.d/conf.yaml`

```yaml
logs:
  - type: journald
    path: /var/log/journal/
    include_units:
      - confd.service
      - teleport.service
```

Collects logs from the `confd` and `teleport` systemd units. The `dd-agent` user must be in the `systemd-journal` group (handled by the install script).

### OpenMetrics (Teleport Metrics)

**Config:** `packer/assets/datadog-agent/conf.d/openmetrics/conf.yaml`

```yaml
init_config: {}
instances:
  - service: 'teleport-agent'
    openmetrics_endpoint: 'http://127.0.0.1:3000/metrics'
    metrics:
      - '.+'
    exclude_metrics:
      - '^go_.+'
```

Teleport exposes Prometheus-compatible metrics on its diagnostic endpoint (`diag_addr: 127.0.0.1:3000`). The DataDog agent scrapes all metrics except Go runtime metrics (`go_*`).

**Key metrics available:**

| Metric | Description |
|--------|-------------|
| `teleport_connected_resources` | Number of resources connected through the agent |
| `teleport_reverse_tunnels_connected` | Reverse tunnel connection count |
| `teleport_cache_events` | Auth cache event counters |
| `teleport_db_connections_active` | Active database proxy connections |
| `teleport_audit_*` | Audit log event counters |

### Base DataDog Config

**Config:** `packer/assets/datadog-agent/datadog.yaml`

The base config has placeholder values for `api_key` and `tags` that are replaced at runtime by `init-datadog.sh`. Key settings:

- `logs_enabled: true` — required for journald collection
- `process_config.enabled: true` — process-level monitoring
- API key and tags injected via `sed` at boot

## Terraform Variables

The EC2 agent pool module exposes two DataDog-related variables:

```hcl
variable "datadog_api_key_arn" {
  description = "ARN of the Secrets Manager secret containing the DataDog API key"
  type        = string
}

variable "datadog_host_tags" {
  description = "Comma-separated DataDog host tags"
  type        = string
  default     = "env:production,service:teleport-agent"
}
```

The module automatically grants the instance role `secretsmanager:GetSecretValue` on the specified ARN.

## Custom Checks

To add custom DataDog checks, either:

1. **At build time:** Add config files to `packer/assets/datadog-agent/conf.d/` before building the AMI.
2. **At runtime:** Use `bootstrap_commands` in the Terraform module to write check configs and restart the agent:
   ```hcl
   bootstrap_commands = [
     "cat > /etc/datadog-agent/conf.d/custom_check.d/conf.yaml <<'EOF'\ninit_config: {}\ninstances:\n  - name: my-check\nEOF",
     "systemctl restart datadog-agent",
   ]
   ```

## Disabling DataDog

DataDog is integral to the AMI — the agent is always installed. If you don't use DataDog, provide a dummy Secrets Manager ARN (the init script will fail gracefully) or build a custom AMI without the DataDog install step.

The Terraform module always requires `datadog_api_key_arn` as an input. To make it truly optional, you would need to fork the module and conditionally skip the DataDog initialization in the cloud-init template.
