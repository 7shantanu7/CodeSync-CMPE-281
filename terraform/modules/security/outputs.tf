output "alb_sg_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "ecs_task_sg_id" {
  description = "ECS tasks security group ID"
  value       = aws_security_group.ecs_tasks.id
}

output "database_sg_id" {
  description = "Database security group ID"
  value       = aws_security_group.database.id
}

output "cache_sg_id" {
  description = "Cache security group ID"
  value       = aws_security_group.cache.id
}

