output "teleport_agent_role_arns" {
  description = "Map of EKS cluster name to the IAM role ARN created for IRSA"
  value = {
    for k, v in module.kube_agent : k => v.teleport_agent_iam_role_arn
  }
}

output "teleport_join_token_names" {
  description = "Map of EKS cluster name to the Teleport provision token name"
  value = {
    for k, v in module.kube_agent : k => v.teleport_join_token_name
  }
}
