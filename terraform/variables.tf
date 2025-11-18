# General Variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "codesync"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Database Configuration
variable "db_username" {
  description = "Master username for RDS database"
  type        = string
  default     = "codesync_admin"
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = true
}

# Cache Configuration
variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 2
}

# API Service Configuration
variable "api_cpu" {
  description = "CPU units for API service (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "api_memory" {
  description = "Memory for API service in MB"
  type        = number
  default     = 1024
}

variable "api_desired_count" {
  description = "Desired number of API service tasks"
  type        = number
  default     = 2
}

variable "api_min_capacity" {
  description = "Minimum number of API service tasks"
  type        = number
  default     = 2
}

variable "api_max_capacity" {
  description = "Maximum number of API service tasks"
  type        = number
  default     = 10
}

# WebSocket Service Configuration
variable "websocket_cpu" {
  description = "CPU units for WebSocket service"
  type        = number
  default     = 512
}

variable "websocket_memory" {
  description = "Memory for WebSocket service in MB"
  type        = number
  default     = 1024
}

variable "websocket_desired_count" {
  description = "Desired number of WebSocket service tasks"
  type        = number
  default     = 2
}

variable "websocket_min_capacity" {
  description = "Minimum number of WebSocket service tasks"
  type        = number
  default     = 2
}

variable "websocket_max_capacity" {
  description = "Maximum number of WebSocket service tasks"
  type        = number
  default     = 10
}

# SSL/TLS Configuration
variable "certificate_arn" {
  description = "ARN of ACM certificate for ALB (optional)"
  type        = string
  default     = ""
}

variable "cloudfront_certificate_arn" {
  description = "ARN of ACM certificate for CloudFront (must be in us-east-1)"
  type        = string
  default     = ""
}

# Secrets
variable "jwt_secret_arn" {
  description = "ARN of JWT secret in Secrets Manager"
  type        = string
  sensitive   = true
}

# Monitoring
variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
}

