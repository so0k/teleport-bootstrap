variable "vpc_id" {
  description = "The VPC for EC2 image build"
  type        = string
}

variable "subnet_id" {
  description = "The subnet for EC2 image build"
  type        = string
}

variable "pr" {
  description = "Indicate if AMI was built from a PR"
  type        = bool
  default     = false
}

variable "architecture" {
  type    = string
  default = "arm64"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "The aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "aws_region" {
  description = "The AWS region for source AMI and output AMI"
  type        = string
  default     = "us-east-1"
}

variable "ami_regions" {
  description = "The AWS Regions to publish the AMI to"
  type        = list(string)
  default     = []
}

variable "ami_region_kms_key_ids" {
  description = "The KMS Key IDs for each region"
  type        = map(string)
  default     = {}
}

variable "ami_org_arns" {
  description = "The AWS Organizations to publish the AMI to"
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "Instance type to build ami on"
  type        = map(string)
  default = {
    "arm64"  = "t4g.medium"
    "x86_64" = "t3.micro"
  }
}

variable "confd_version" {
  description = "confd version"
  # https://github.com/abtreece/confd/releases
  type    = string
  default = "0.19.2"
}

variable "teleport_version" {
  description = "teleport version"
  type        = string
  # https://github.com/gravitational/teleport/releases
  default = "18.6.8"
}
