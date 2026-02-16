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
# Locals — MongoDB Atlas configuration
# --------------------------------------------------------------------------

locals {
  # Path on the agent instance where the Atlas TLS CA certificate is stored.
  # MongoDB Atlas uses Let's Encrypt certificates; the ISRG Root X1 CA is
  # required for TLS verification.
  atlas_ca_cert = "/home/teleport/atlasCA.pem"

  # Access level variants — each entry maps to a MongoDB role and a
  # corresponding AWS IAM role ARN that the Teleport agent assumes via
  # STS AssumeRole to authenticate with Atlas.
  mongodb_access_map = {
    readonly = {
      suffix          = "ro"
      description     = "read-only"
      assume_role_arn = "arn:aws:iam::111122223333:role/mongodb-atlas-readonly"
    }
    readwrite = {
      suffix          = "rw"
      description     = "read-write"
      assume_role_arn = "arn:aws:iam::111122223333:role/mongodb-atlas-readwrite"
    }
  }

  # Shared template for all MongoDB static database entries.
  mongodb_static_template = {
    protocol = "mongodb"
    tls = {
      mode         = "verify-full"
      ca_cert_file = local.atlas_ca_cert
    }
  }

  # MongoDB Atlas cluster URIs per environment.
  mongodb_clusters = {
    staging = {
      uri = "mongodb+srv://your-cluster-staging.mongodb.net"
    }
    production = {
      uri = "mongodb+srv://your-cluster-production.mongodb.net"
    }
  }

  # setproduct produces every (environment x access_level) combination:
  #   [ {env="staging", access="readonly"}, {env="staging", access="readwrite"},
  #     {env="production", access="readonly"}, {env="production", access="readwrite"} ]
  mongodb_env_setproduct = [
    for pair in setproduct(keys(local.mongodb_clusters), keys(local.mongodb_access_map)) : {
      env    = pair[0]
      access = pair[1]
    }
  ]

  # Build the final map of static database configs keyed by a descriptive name
  # e.g. "myapp-staging-ro", "myapp-production-rw"
  mongodb_configs = {
    for combo in local.mongodb_env_setproduct :
    "myapp-${combo.env}-${local.mongodb_access_map[combo.access].suffix}" => merge(
      local.mongodb_static_template,
      {
        name        = "myapp-${combo.env}-${local.mongodb_access_map[combo.access].suffix}"
        description = "MongoDB Atlas ${combo.env} (${local.mongodb_access_map[combo.access].description})"
        uri         = local.mongodb_clusters[combo.env].uri
        static_labels = {
          "env"    = combo.env
          "engine" = "mongodb-atlas"
          "access" = combo.access
        }
        aws = {
          assume_role_arn = local.mongodb_access_map[combo.access].assume_role_arn
        }
      },
    )
  }
}

# --------------------------------------------------------------------------
# Teleport agent pool — MongoDB Atlas (static databases)
# --------------------------------------------------------------------------

module "mongodb_atlas_agent" {
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

  # Bootstrap — download the Let's Encrypt ISRG Root X1 CA certificate used by
  # MongoDB Atlas for TLS. This runs once at instance boot before the Teleport
  # agent starts.
  bootstrap_commands = [
    "curl -fsSL -o ${local.atlas_ca_cert} https://letsencrypt.org/certs/isrgrootx1.pem",
    "chown teleport:teleport ${local.atlas_ca_cert}",
    "chmod 0644 ${local.atlas_ca_cert}",
  ]

  # SSH service — keep enabled so the agent node itself is accessible for
  # troubleshooting.
  teleport_ssh_service = {
    enabled = true
    labels = {
      "role" = "mongodb-atlas"
    }
  }

  # Database service — static MongoDB Atlas databases built from the
  # setproduct of environments x access levels.
  teleport_db_service = {
    enabled   = true
    databases = values(local.mongodb_configs)
  }

  # IAM policy — allow the agent to assume the MongoDB Atlas access roles.
  # Each access level (readonly / readwrite) uses a dedicated IAM role for
  # AWS IAM authentication against Atlas.
  additional_inline_policies = {
    mongodb-atlas-assume-role = {
      policy = {
        MongoDBAtlasAssumeRole = {
          actions = ["sts:AssumeRole"]
          resources = [
            for access in local.mongodb_access_map : access.assume_role_arn
          ]
        }
      }
    }
  }
}
