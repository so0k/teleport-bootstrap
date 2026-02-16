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
# Data sources
# --------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

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
# Teleport agent pool — complete (all services)
# --------------------------------------------------------------------------

module "complete_agent" {
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

  # Use Intelligent-Tiering because the combined config exceeds 4 KB.
  ssm_tier = "Intelligent-Tiering"

  # ---------------------------------------------------------------------------
  # SSH service
  # ---------------------------------------------------------------------------

  teleport_ssh_service = {
    enabled = true
    labels = {
      "role" = "complete-agent"
      "env"  = "production"
    }
  }

  # ---------------------------------------------------------------------------
  # App service — proxy a local application through Teleport
  # ---------------------------------------------------------------------------

  teleport_app_service = {
    enabled   = true
    debug_app = false
    apps = [
      {
        name = "internal-dashboard"
        uri  = "http://localhost:8080"
        labels = {
          "env"  = "production"
          "team" = "platform"
        }
      },
    ]
  }

  # ---------------------------------------------------------------------------
  # Database service — AWS discovery matchers + static MongoDB
  # ---------------------------------------------------------------------------

  teleport_db_service = {
    enabled = true

    # Match databases created by the discovery service.
    resources = [
      {
        labels = local.discovery_labels
      },
    ]

    # AWS auto-discovery matchers (db_service registers discovered databases).
    aws = [
      {
        types   = ["rds"]
        regions = [var.aws_region]
        tags    = { "*" = "*" }
      },
      {
        types   = ["elasticache"]
        regions = [var.aws_region]
        tags    = { "*" = "*" }
      },
    ]

    # Static database: MongoDB Atlas (or self-hosted MongoDB).
    databases = [
      {
        name        = "mongodb-atlas-prod"
        description = "Production MongoDB Atlas cluster"
        protocol    = "mongodb"
        uri         = "mongodb+srv://cluster0.example.mongodb.net:27017"
        tls = {
          mode         = "verify-full"
          ca_cert_file = "/opt/teleport/scripts/mongodb-atlas-ca.crt"
        }
        static_labels = {
          "env"    = "production"
          "engine" = "mongodb"
        }
      },
    ]
  }

  # ---------------------------------------------------------------------------
  # Discovery service — finds RDS + ElastiCache resources by tag
  # ---------------------------------------------------------------------------

  teleport_discovery_service = {
    enabled         = true
    discovery_group = "${var.name_prefix}-all"
    aws = [
      {
        types   = ["rds"]
        regions = [var.aws_region]
        tags    = { "*" = "*" }
      },
      {
        types   = ["elasticache"]
        regions = [var.aws_region]
        tags    = { "*" = "*" }
      },
    ]
  }

  # ---------------------------------------------------------------------------
  # ElastiCache IAM policies
  # ---------------------------------------------------------------------------

  elasticache_autodiscovery_policy_enabled = true
  elasticache_access_policy_enabled        = true

  # ---------------------------------------------------------------------------
  # Additional IAM policies
  # ---------------------------------------------------------------------------

  additional_inline_policies = {
    # RDS IAM authentication
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

    # RDS discovery permissions
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

    # Assume role for MongoDB Atlas access (if using cross-account or
    # AWS IAM-based authentication with a dedicated role).
    mongodb-assume-role = {
      policy = {
        MongoDBAssumeRole = {
          actions = [
            "sts:AssumeRole",
          ]
          resources = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-mongodb-access",
          ]
        }
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Bootstrap commands — download MongoDB Atlas CA certificate
  # ---------------------------------------------------------------------------

  bootstrap_commands = [
    "mkdir -p /opt/teleport/scripts",
    "curl -fsSL -o /opt/teleport/scripts/mongodb-atlas-ca.crt https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem",
  ]

  tags = {
    Example = "complete"
  }
}
