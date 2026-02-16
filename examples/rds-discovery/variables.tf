# --------------------------------------------------------------------------
# General
# --------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix applied to all resources created by this example"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the Teleport agent EC2 instances (must be ARM/Graviton)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the agent instances will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Auto Scaling Group"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region for the provider and RDS discovery"
  type        = string
  default     = "us-east-1"
}

# --------------------------------------------------------------------------
# DataDog
# --------------------------------------------------------------------------

variable "datadog_api_key_arn" {
  description = "ARN of the AWS Secrets Manager secret containing the DataDog API key"
  type        = string
}

variable "datadog_host_tags" {
  description = "DataDog Agent host tags in comma-separated key:value format"
  type        = string
  default     = "env:prod,service:teleport-agent"
}

# --------------------------------------------------------------------------
# Teleport
# --------------------------------------------------------------------------

variable "teleport_auth_server" {
  description = "Teleport Auth Server address including port (e.g. example.teleport.sh:443)"
  type        = string

  validation {
    condition     = can(regex("^.+:\\d+$", var.teleport_auth_server))
    error_message = "teleport_auth_server must include host and port (e.g. example.teleport.sh:443)"
  }
}

# --------------------------------------------------------------------------
# RDS Discovery
# --------------------------------------------------------------------------

variable "rds_discovery_tags" {
  description = "AWS resource tags used to filter which RDS instances/clusters are discovered. Defaults to all."
  type        = map(string)
  default = {
    "*" = "*"
  }
}
