# Infrastructure Outputs

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${module.alb.alb_dns_name}"
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.cloudfront_domain_name
}

output "cloudfront_url" {
  description = "CloudFront URL for frontend"
  value       = "https://${module.cloudfront.cloudfront_domain_name}"
}

output "frontend_bucket_name" {
  description = "S3 bucket name for frontend static files"
  value       = module.storage.frontend_bucket_name
}

output "documents_bucket_name" {
  description = "S3 bucket name for document storage"
  value       = module.storage.documents_bucket_name
}

output "db_endpoint" {
  description = "RDS database endpoint"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.cache.redis_endpoint
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

output "api_service_name" {
  description = "API service name"
  value       = module.api_service.service_name
}

output "websocket_service_name" {
  description = "WebSocket service name"
  value       = module.websocket_service.service_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = module.monitoring.sns_topic_arn
}

