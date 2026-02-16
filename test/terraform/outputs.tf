output "asg_name" {
  description = "The name of the ASG that manages Teleport agent pool."
  value       = module.teleport_agent_pool.autoscaling_group_name
  sensitive   = false
}

output "role_arn" {
  description = "The name of the Teleport Agent Pool IAM role."
  value       = module.teleport_agent_pool.role_arn
  sensitive   = false
}
