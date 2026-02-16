terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
  addr               = var.teleport_auth_server
  join_method        = "iam"
  join_token         = "terraform"
  is_terraform_cloud = false
}

# --------------------------------------------------------------------------
# Locals
# --------------------------------------------------------------------------

locals {
  # Define one entry per EKS cluster that should run a Teleport kube agent.
  # Toggle individual service flags to control which Teleport services the
  # agent advertises when it joins the cluster.
  kube_teleport_agent_bootstrap = {
    "my-eks-cluster-1" = {
      kube_service_enabled      = true
      app_service_enabled       = true
      db_service_enabled        = true
      discovery_service_enabled = true
      ssh_service_enabled       = false
    }
    "my-eks-cluster-2" = {
      kube_service_enabled      = true
      app_service_enabled       = false
      db_service_enabled        = false
      discovery_service_enabled = false
      ssh_service_enabled       = false
    }
  }
}

# --------------------------------------------------------------------------
# Module — one instance per EKS cluster
# --------------------------------------------------------------------------

module "kube_agent" {
  source   = "../../modules/teleport-kube-agent"
  for_each = local.kube_teleport_agent_bootstrap

  eks_cluster_name = each.key
  name_prefix      = "teleport-${each.key}"

  teleport_agent_namespace     = var.teleport_agent_namespace
  teleport_service_account_name = var.teleport_service_account_name

  teleport_kube_service_enabled      = lookup(each.value, "kube_service_enabled", false)
  teleport_app_service_enabled       = lookup(each.value, "app_service_enabled", false)
  teleport_db_service_enabled        = lookup(each.value, "db_service_enabled", false)
  teleport_discovery_service_enabled = lookup(each.value, "discovery_service_enabled", false)
  teleport_ssh_service_enabled       = lookup(each.value, "ssh_service_enabled", false)
}
