variable "name_prefix" {
  description = "Prefix to use for all resources in this integration test"
  type        = string
}

variable "ami_id" {
  description = "AMI for e2e test"
  type        = string
}

# fixtures — override these via environment variables or tfvars
variable "vpc_id" {
  description = "VPC to test in"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet to test in"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region to test in"
  type        = string
  default     = "us-east-1"
}

variable "datadog_api_key_arn" {
  description = "ARN to AWS Secrets Manager secret containing DataDog API Key for end to end testing"
  type        = string
}

variable "teleport_auth_server" {
  description = "Teleport Auth Server address (e.g. example.teleport.sh:443)"
  type        = string
  default     = "localhost:3025"
}
