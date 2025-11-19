variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "frontend_bucket_id" {
  description = "Frontend S3 bucket ID"
  type        = string
}

variable "frontend_bucket_arn" {
  description = "Frontend S3 bucket ARN"
  type        = string
}

variable "frontend_bucket_domain" {
  description = "Frontend S3 bucket domain name"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN (must be in us-east-1)"
  type        = string
  default     = ""
}

