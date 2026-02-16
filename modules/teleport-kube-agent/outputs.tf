output "teleport_agent_iam_role_arn" {
  description = "The ARN of the IAM role for Service Accounts in EKS"
  value       = module.irsa.iam_role_arn
}

output "teleport_join_token_name" {
  description = "The Join Token Name required for the Teleport Agent to use IAM join method"
  value       = local.token_name
}
