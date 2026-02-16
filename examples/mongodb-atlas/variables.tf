variable "name_prefix" {
  description = "Name prefix for all resources created by this example"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the Teleport agent instance (ARM-based, built with the companion Packer template)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the agent pool will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Auto Scaling Group"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "datadog_api_key_arn" {
  description = "ARN of the AWS Secrets Manager secret containing the DataDog API key"
  type        = string
}

variable "datadog_host_tags" {
  description = "DataDog Agent host tags in key:value,key:value format"
  type        = string
}

variable "teleport_auth_server" {
  description = "Teleport Proxy/Auth Server address (e.g. example.teleport.sh:443)"
  type        = string

  validation {
    condition     = can(regex("^.+:\\d+$", var.teleport_auth_server))
    error_message = "teleport_auth_server must include host and port (e.g. example.teleport.sh:443)"
  }
}
