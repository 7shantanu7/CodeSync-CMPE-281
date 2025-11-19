variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix"
  type        = string
}

variable "api_target_group_arn" {
  description = "API target group ARN suffix"
  type        = string
}

variable "ws_target_group_arn" {
  description = "WebSocket target group ARN suffix"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "api_service_name" {
  description = "API service name"
  type        = string
}

variable "ws_service_name" {
  description = "WebSocket service name"
  type        = string
}

variable "db_instance_id" {
  description = "RDS instance ID"
  type        = string
}

variable "redis_cluster_id" {
  description = "Redis cluster ID"
  type        = string
}

variable "alert_email" {
  description = "Email for alerts"
  type        = string
}

