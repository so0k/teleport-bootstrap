terraform {
  required_version = ">=1.3.0"

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

provider "cloudinit" {}

# https://github.com/gravitational/teleport-plugins/blob/v18.6.8/terraform/provider/provider.go
# set TF_TELEPORT_IDENTITY_FILE_PATH
# set TF_TELEPORT_ADDR
provider "teleport" {}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      project = "teleport-bootstrap"
      gitPath = "test/terraform"
    }
  }
}

module "teleport_agent_pool" {
  source = "../../modules/ec2-teleport-agent-pool"

  # under test
  name_prefix = var.name_prefix
  ami_id      = var.ami_id

  # fixtures
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.subnet_ids
  datadog_api_key_arn        = var.datadog_api_key_arn
  datadog_host_tags          = "env:e2e-tests,service:teleport-agent"
  teleport_auth_server       = var.teleport_auth_server
  teleport_create_join_token = false

  # sample ssh service config
  teleport_ssh_service = {
    enabled = true
    labels = {
      env = "e2e-tests"
    }
    commands = [
      {
        name    = "arch"
        command = ["uname", "-p"]
        period  = "1h0m0s"
      }
    ]
  }

  # sample app service config
  teleport_app_service = {
    enabled = true
    apps = [
      {
        name = "web-app"
        uri  = "http://localhost:8080"
      }
    ]
  }

  # sample db service config
  teleport_db_service = {
    enabled = true
    aws = [
      {
        types   = ["rds", "elasticache"]
        regions = [var.aws_region]
        tags = {
          "*" = "*"
        }
      }
    ]
  }

  # sample discovery service config
  teleport_discovery_service = {
    enabled         = true
    discovery_group = "disc-group"
    aws = [
      {
        types   = ["ec2", "eks"]
        regions = [var.aws_region]
      }
    ]
  }

  # simplify debug
  userdata_gzip = false
}
