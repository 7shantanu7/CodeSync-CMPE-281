variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "service_name" {
  description = "Service name (e.g., api, websocket)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "task_sg_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "cpu" {
  description = "CPU units for task"
  type        = number
}

variable "memory" {
  description = "Memory for task in MB"
  type        = number
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
}

variable "min_capacity" {
  description = "Minimum number of tasks"
  type        = number
}

variable "max_capacity" {
  description = "Maximum number of tasks"
  type        = number
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
}

variable "alb_listener_arn" {
  description = "ALB listener ARN"
  type        = string
}

variable "alb_priority" {
  description = "ALB listener rule priority"
  type        = number
}

variable "path_pattern" {
  description = "Path pattern for ALB routing"
  type        = string
}

variable "enable_sticky_sessions" {
  description = "Enable sticky sessions"
  type        = bool
  default     = false
}

variable "environment_variables" {
  description = "Environment variables for container"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets from Secrets Manager"
  type        = map(string)
  default     = {}
}

