output "service_id" {
  description = "ECS service ID"
  value       = aws_ecs_service.service.id
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.service.name
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.service.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch"
  value       = aws_lb_target_group.service.arn_suffix
}

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.service.name
}

