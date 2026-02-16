variable "aws_region" {
  description = "AWS region where the EKS clusters reside"
  type        = string
  default     = "us-east-1"
}

variable "teleport_auth_server" {
  description = "Address of the Teleport Auth/Proxy server (e.g. teleport.example.com:443)"
  type        = string
}

variable "teleport_agent_namespace" {
  description = "Kubernetes namespace where the Teleport agent pods will be deployed"
  type        = string
  default     = "teleport-agent"
}

variable "teleport_service_account_name" {
  description = "Kubernetes service account name used by the Teleport agent pods (must match the Helm release)"
  type        = string
  default     = "teleport-agent"
}
