output "asg_name" {
  description = "Name of the Auto Scaling Group running the Teleport RDS discovery agents"
  value       = module.rds_discovery_agent.autoscaling_group_name
}

output "role_arn" {
  description = "IAM Role ARN used by the Teleport agent instances"
  value       = module.rds_discovery_agent.role_arn
}

output "security_group_id" {
  description = "Security Group ID attached to the Teleport agent instances"
  value       = module.rds_discovery_agent.security_group_id
}
