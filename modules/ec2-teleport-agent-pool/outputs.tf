output "security_group_id" {
  description = "The ID of the security group used by teleport-agent instances"
  value       = aws_security_group.node.id
}

output "role_arn" {
  description = "The ARN of the role used by the teleport-agent instance profile"
  value       = aws_iam_role.node.arn
}

output "instance_profile_arn" {
  description = "The ARN of the instance profile used by the teleport-agent instances"
  value       = aws_iam_instance_profile.node.arn
}

output "launch_template_id" {
  description = "The ID of the launch template used to spawn teleport-agent instances"
  value       = aws_launch_template.node.arn
}

output "autoscaling_group_arn" {
  description = "The ARN of the autoscaling group"
  value       = aws_autoscaling_group.node.arn
}

output "autoscaling_group_name" {
  description = "The ARN of the autoscaling group"
  value       = aws_autoscaling_group.node.name
}
