# CodeSync Infrastructure - Main Configuration

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Backend configuration for state management
  # Uncomment and configure for production use
  # backend "s3" {
  #   bucket         = "codesync-terraform-state"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "codesync-terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "CodeSync"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# Security Groups
module "security" {
  source = "./modules/security"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

# RDS PostgreSQL Database
module "database" {
  source = "./modules/database"
  
  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  database_subnet_ids    = module.vpc.database_subnet_ids
  db_subnet_group_name   = module.vpc.db_subnet_group_name
  database_sg_id         = module.security.database_sg_id
  db_username            = var.db_username
  db_instance_class      = var.db_instance_class
  db_allocated_storage   = var.db_allocated_storage
  multi_az               = var.multi_az
}

# ElastiCache Redis
module "cache" {
  source = "./modules/cache"
  
  project_name           = var.project_name
  environment            = var.environment
  cache_subnet_ids       = module.vpc.cache_subnet_ids
  cache_subnet_group_name = module.vpc.cache_subnet_group_name
  cache_sg_id            = module.security.cache_sg_id
  node_type           = var.redis_node_type
  num_cache_nodes     = var.redis_num_nodes
}

# S3 Buckets
module "storage" {
  source = "./modules/storage"
  
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

# Application Load Balancer
module "alb" {
  source = "./modules/alb"
  
  project_name    = var.project_name
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnet_ids
  alb_sg_id       = module.security.alb_sg_id
  certificate_arn = var.certificate_arn
}

# ECS Cluster
module "ecs_cluster" {
  source = "./modules/ecs-cluster"
  
  project_name = var.project_name
  environment  = var.environment
}

# API Service
module "api_service" {
  source = "./modules/ecs-service"
  
  project_name       = var.project_name
  environment        = var.environment
  service_name       = "api"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_cluster_id     = module.ecs_cluster.cluster_id
  ecs_cluster_name   = module.ecs_cluster.cluster_name
  task_sg_id         = module.security.ecs_task_sg_id
  
  # Task configuration
  cpu                = var.api_cpu
  memory             = var.api_memory
  desired_count      = var.api_desired_count
  min_capacity       = var.api_min_capacity
  max_capacity       = var.api_max_capacity
  
  # Container configuration
  container_port     = 3000
  health_check_path  = "/health"
  
  # ALB configuration
  alb_listener_arn   = module.alb.http_listener_arn
  alb_priority       = 100
  path_pattern       = "/api/*"
  
  # Environment variables
  environment_variables = {
    NODE_ENV           = var.environment
    DB_HOST            = module.database.db_endpoint
    DB_NAME            = module.database.db_name
    DB_USERNAME        = module.database.db_username
    REDIS_HOST         = module.cache.redis_endpoint
    REDIS_PORT         = "6379"
    S3_BUCKET          = module.storage.documents_bucket_name
    AWS_REGION         = var.aws_region
  }
  
  # Secrets
  secrets = {
    DB_PASSWORD = module.database.db_password_secret_arn
    JWT_SECRET  = var.jwt_secret_arn
  }
}

# WebSocket Service
module "websocket_service" {
  source = "./modules/ecs-service"
  
  project_name       = var.project_name
  environment        = var.environment
  service_name       = "websocket"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_cluster_id     = module.ecs_cluster.cluster_id
  ecs_cluster_name   = module.ecs_cluster.cluster_name
  task_sg_id         = module.security.ecs_task_sg_id
  
  # Task configuration
  cpu                = var.websocket_cpu
  memory             = var.websocket_memory
  desired_count      = var.websocket_desired_count
  min_capacity       = var.websocket_min_capacity
  max_capacity       = var.websocket_max_capacity
  
  # Container configuration
  container_port     = 3001
  health_check_path  = "/health"
  
  # ALB configuration with sticky sessions for WebSocket
  alb_listener_arn   = module.alb.http_listener_arn
  alb_priority       = 200
  path_pattern       = "/socket/*"
  enable_sticky_sessions = true
  
  # Environment variables
  environment_variables = {
    NODE_ENV           = var.environment
    DB_HOST            = module.database.db_endpoint
    DB_NAME            = module.database.db_name
    DB_USERNAME        = module.database.db_username
    REDIS_HOST         = module.cache.redis_endpoint
    REDIS_PORT         = "6379"
    AWS_REGION         = var.aws_region
  }
  
  # Secrets
  secrets = {
    DB_PASSWORD = module.database.db_password_secret_arn
    JWT_SECRET  = var.jwt_secret_arn
  }
}

# CloudFront for Frontend
module "cloudfront" {
  source = "./modules/cloudfront"
  
  project_name          = var.project_name
  environment           = var.environment
  frontend_bucket_id    = module.storage.frontend_bucket_id
  frontend_bucket_arn   = module.storage.frontend_bucket_arn
  frontend_bucket_domain = module.storage.frontend_bucket_domain
  alb_dns_name          = module.alb.alb_dns_name
  certificate_arn       = var.cloudfront_certificate_arn
}

# Monitoring and Alarms
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name         = var.project_name
  environment          = var.environment
  alb_arn_suffix       = module.alb.alb_arn_suffix
  api_target_group_arn = module.api_service.target_group_arn_suffix
  ws_target_group_arn  = module.websocket_service.target_group_arn_suffix
  ecs_cluster_name     = module.ecs_cluster.cluster_name
  api_service_name     = module.api_service.service_name
  ws_service_name      = module.websocket_service.service_name
  db_instance_id       = module.database.db_instance_id
  redis_cluster_id     = module.cache.redis_cluster_id
  alert_email          = var.alert_email
}

