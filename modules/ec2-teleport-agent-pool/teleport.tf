data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  roles = compact([
    var.teleport_ssh_service.enabled ? "Node" : null,
    var.teleport_app_service.enabled ? "App" : null,
    var.teleport_db_service.enabled ? "Db" : null,
    var.teleport_discovery_service.enabled ? "Discovery" : null,
  ])
  token_name = "${var.name_prefix}-token"

  base_config = {
    version = "v3"
    teleport = {
      join_params = {
        method     = "iam"
        token_name = local.token_name
      }
      log = {
        format = {
          extra_fields = [
            "timestamp",
            "level",
            "component",
            "caller",
          ]
          output = "text"
        }
        output   = "stderr"
        severity = upper(var.log_level)
      }
      proxy_server = var.teleport_auth_server
      # https://goteleport.com/docs/management/diagnostics/metrics/
      diag_addr = "127.0.0.1:3000"
    }
    auth_service = {
      enabled = false
    }
    proxy_service = {
      enabled = false
    }
  }

  # refer to https://goteleport.com/docs/reference/config/#enabling-teleport-services
  teleport_config = yamlencode(
    merge(
      local.base_config,
      var.teleport_ssh_service.enabled ? {
        ssh_service = var.teleport_ssh_service
      } : null,
      var.teleport_app_service.enabled ? {
        app_service = var.teleport_app_service
      } : null,
      var.teleport_db_service.enabled ? {
        db_service = var.teleport_db_service
      } : null,
      var.teleport_discovery_service.enabled ? {
        discovery_service = var.teleport_discovery_service
      } : null,
    )
  )
}

resource "aws_ssm_parameter" "teleport_etc" {
  name           = "/${var.name_prefix}/teleport-etc/contents"
  description    = "${var.name_prefix} teleport agent config"
  type           = "String"
  tier           = var.ssm_tier
  insecure_value = local.teleport_config
  tags           = var.tags
}

resource "teleport_provision_token" "agent" {
  count = var.teleport_create_join_token && length(local.roles) > 0 ? 1 : 0
  # https://goteleport.com/docs/reference/terraform-provider/#teleport_provision_token
  version = "v2"
  metadata = {
    name = local.token_name
  }
  spec = {
    roles       = local.roles
    join_method = "iam"
    allow = [
      {
        aws_account = data.aws_caller_identity.current.account_id
        aws_arn     = "arn:${data.aws_partition.current.partition}:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${aws_iam_role.node.name}/i-*"
      },
    ]
  }
}
