variable "eks_cluster_name" {
  description = "EKS Cluster name"
  type        = string
}

variable "name_prefix" {
  description = "name prefix for resources created"
  type        = string
}

variable "teleport_service_account_name" {
  description = "Service account name for Teleport Kube agents, must be matched in k8s deployment."
  type        = string
  default     = "teleport-agent"
}

variable "teleport_agent_namespace" {
  description = "Namespace for Teleport Kube agents"
  type        = string
  default     = "teleport-agent"
}

variable "teleport_create_join_token" {
  description = "Create join token for Teleport Agents in Teleport cluster"
  type        = bool
  default     = true
}

variable "teleport_ssh_service_enabled" {
  description = "Enable SSH service for Teleport Agents in EKS cluster"
  type        = bool
  default     = false
}

variable "teleport_app_service_enabled" {
  description = "Enable App service for Teleport Agents in EKS cluster"
  type        = bool
  default     = false
}

variable "teleport_db_service_enabled" {
  description = "Enable DB service for Teleport Agents in EKS cluster"
  type        = bool
  default     = false
}

variable "teleport_discovery_service_enabled" {
  description = "Enable Discovery service for Teleport Agents in EKS cluster"
  type        = bool
  default     = false
}

variable "teleport_kube_service_enabled" {
  description = "Enable Kube service for Teleport Agents in EKS cluster"
  type        = bool
  default     = false
}

variable "overwrite_teleport_token_name" {
  description = "overwrite the teleport_provision_token name"
  type        = string
  default     = null
}
