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

provider "cloudinit" {}

provider "teleport" {
  addr               = var.teleport_auth_server
  join_method        = "iam"
  join_token         = "terraform"
  is_terraform_cloud = false
}

# --------------------------------------------------------------------------
# Locals
# --------------------------------------------------------------------------

locals {
  # Labels applied to discovery matchers so the db_service only picks up
  # databases that were found by *this* discovery group.
  discovery_labels = {
    "teleport.dev/origin" = "dynamic"
  }
}

# --------------------------------------------------------------------------
# Data sources
# --------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# --------------------------------------------------------------------------
# Teleport agent pool — RDS discovery
# --------------------------------------------------------------------------

module "rds_discovery_agent" {
  source = "../../modules/ec2-teleport-agent-pool"

  name_prefix = var.name_prefix
  ami_id      = var.ami_id
  vpc_id      = var.vpc_id
  subnet_ids  = var.subnet_ids

  # DataDog
  datadog_api_key_arn = var.datadog_api_key_arn
  datadog_host_tags   = var.datadog_host_tags

  # Teleport auth
  teleport_auth_server = var.teleport_auth_server

  # SSH service — keep enabled so the agent node itself is accessible for
  # troubleshooting.
  teleport_ssh_service = {
    enabled = true
    labels = {
      "role" = "rds-discovery"
    }
  }

  # Discovery service — finds RDS instances/clusters by tag.
  teleport_discovery_service = {
    enabled         = true
    discovery_group = "${var.name_prefix}-rds"
    aws = [
      {
        types   = ["rds"]
        regions = [var.aws_region]
        tags    = var.rds_discovery_tags
      },
    ]
  }

  # Database service — proxies the databases discovered above.
  teleport_db_service = {
    enabled = true
    resources = [
      {
        labels = local.discovery_labels
      },
    ]
  }

  # IAM policies required for RDS auto-discovery and IAM authentication.
  additional_inline_policies = {
    rds-discovery = {
      policy = {
        RDSDescribe = {
          actions = [
            "rds:DescribeDBInstances",
            "rds:DescribeDBClusters",
          ]
          resources = ["*"]
        }
      }
    }
    rds-connect = {
      policy = {
        RDSConnect = {
          actions = [
            "rds-db:connect",
          ]
          resources = [
            "arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.current.account_id}:dbuser:*/*",
          ]
        }
      }
    }
  }
}
