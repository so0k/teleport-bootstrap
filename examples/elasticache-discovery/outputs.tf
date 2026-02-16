output "asg_name" {
  description = "Name of the Auto Scaling Group running the Teleport ElastiCache discovery agents."
  value       = module.elasticache_agents.autoscaling_group_name
}

output "role_arn" {
  description = "ARN of the IAM role attached to the Teleport agent instances."
  value       = module.elasticache_agents.role_arn
}

output "security_group_id" {
  description = "ID of the security group attached to the Teleport agent instances."
  value       = module.elasticache_agents.security_group_id
}
