data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  roles = compact([
    var.teleport_ssh_service_enabled ? "Node" : null,
    var.teleport_app_service_enabled ? "App" : null,
    var.teleport_db_service_enabled ? "Db" : null,
    var.teleport_discovery_service_enabled ? "Discovery" : null,
    var.teleport_kube_service_enabled ? "Kube" : null,
  ])

  token_name = "${var.name_prefix}-token"
}

resource "teleport_provision_token" "agent" {
  count = var.teleport_create_join_token && length(local.roles) > 0 ? 1 : 0
  # https://goteleport.com/docs/reference/terraform-provider/#teleport_provision_token
  version = "v2"
  metadata = {
    name = var.overwrite_teleport_token_name == null ? local.token_name : var.overwrite_teleport_token_name
  }
  spec = {
    roles       = local.roles
    join_method = "iam"
    allow = [
      {
        aws_account = data.aws_caller_identity.current.account_id
        aws_arn     = "arn:${data.aws_partition.current.partition}:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${local.iam_role_name}/*"
      },
    ]
  }
}
