terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.2"
    }
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "~> 18.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "teleport" {
  # Configure via environment variables or Teleport identity file.
  # See https://goteleport.com/docs/reference/terraform-provider/
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  # Labels used by the Discovery Service to tag discovered ElastiCache
  # resources and by the Database Service to match resources it should proxy.
  discovery_labels = merge(
    {
      "teleport.dev/cloud"  = "aws"
      "teleport.dev/origin" = "dynamic"
    },
    var.elasticache_discovery_tags,
  )
}

# ---------------------------------------------------------------------------
# Teleport Agent Pool — ElastiCache Discovery
# ---------------------------------------------------------------------------

module "elasticache_agents" {
  source = "../../modules/ec2-teleport-agent-pool"

  name_prefix = var.name_prefix
  ami_id      = var.ami_id
  vpc_id      = var.vpc_id
  subnet_ids  = var.subnet_ids

  # --- Teleport auth ---
  teleport_auth_server = var.teleport_auth_server

  # --- SSH Service (for node management / troubleshooting) ---
  teleport_ssh_service = {
    enabled = true
    labels = {
      "role"    = "elasticache-agent"
      "service" = "discovery"
    }
  }

  # --- Discovery Service ---
  teleport_discovery_service = {
    enabled         = true
    discovery_group = "${var.name_prefix}-elasticache"
    aws = [
      {
        types   = ["elasticache"]
        regions = [var.aws_region]
        tags    = var.elasticache_discovery_tags
      },
    ]
  }

  # --- Database Service ---
  # The Database Service picks up resources registered by the Discovery
  # Service above and acts as a proxy for client connections.
  teleport_db_service = {
    enabled = true
    resources = [
      {
        labels = local.discovery_labels
      },
    ]
  }

  # --- ElastiCache IAM policies ---
  elasticache_autodiscovery_policy_enabled = true
  elasticache_access_policy_enabled        = true

  # --- Managed IAM Identities ---
  # Let Teleport self-manage the agent role policy so it can dynamically
  # grant itself access to newly discovered ElastiCache clusters.
  # See: https://goteleport.com/docs/database-access/reference/aws/#teleport-managed-iam-identities-for-elasticachememorydb-access
  teleport_managed_identities_enabled = true

  # --- SSM Parameter Store ---
  # ElastiCache discovery config can exceed the 4 KB Standard tier limit.
  # Intelligent-Tiering automatically promotes to Advanced when needed.
  ssm_tier = "Intelligent-Tiering"

  # --- DataDog ---
  datadog_api_key_arn = var.datadog_api_key_arn
  datadog_host_tags   = var.datadog_host_tags

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Service     = "teleport-elasticache-discovery"
  }
}
