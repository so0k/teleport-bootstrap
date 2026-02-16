output "asg_name" {
  description = "Name of the Auto Scaling Group running the Teleport MongoDB Atlas agents"
  value       = module.mongodb_atlas_agent.autoscaling_group_name
}

output "role_arn" {
  description = "ARN of the IAM role attached to the Teleport agent instances"
  value       = module.mongodb_atlas_agent.role_arn
}

output "security_group_id" {
  description = "ID of the security group attached to the Teleport agent instances"
  value       = module.mongodb_atlas_agent.security_group_id
}
