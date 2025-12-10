# CodeSync Infrastructure

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # backend "s3" {
  #   bucket         = "codesync-terraform-state"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "codesync-terraform-locks"
  # }
}

# Secure Design Iteration: Resource Tagging Enforcement
# Added mandatory tags (Owner, CostCenter) for governance and accountability
# All resources automatically get these tags via provider default_tags
locals {
  mandatory_tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "Terraform"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.mandatory_tags
  }
}

# Secure Design Iteration: AWS Config Rule for Tag Enforcement
# Automatically checks that all resources have required tags (Project, Environment, Owner, ManagedBy)
# Non-compliant resources are flagged in AWS Config
resource "aws_config_config_rule" "required_tags" {
  name        = "${var.project_name}-${var.environment}-required-tags"
  description = "Checks whether resources have the required tags"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key   = "Project"
    tag2Key   = "Environment"
    tag3Key   = "Owner"
    tag4Key   = "ManagedBy"
  })

  scope {
    compliance_resource_types = [
      "AWS::EC2::Instance",
      "AWS::EC2::SecurityGroup",
      "AWS::EC2::Subnet",
      "AWS::EC2::VPC",
      "AWS::RDS::DBInstance",
      "AWS::ElastiCache::CacheCluster",
      "AWS::S3::Bucket",
      "AWS::ECS::Cluster",
      "AWS::ECS::Service",
      "AWS::ElasticLoadBalancingV2::LoadBalancer"
    ]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-required-tags-rule"
  }

}

resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-${var.environment}-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    resource_types = [
      "AWS::EC2::SecurityGroup",
      "AWS::EC2::Subnet",
      "AWS::EC2::VPC",
      "AWS::RDS::DBInstance",
      "AWS::S3::Bucket",
      "AWS::ECS::Cluster",
      "AWS::ECS::Service"
    ]
  }
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-${var.environment}-config-delivery"
  s3_bucket_name = module.storage.backups_bucket_name
  s3_key_prefix  = "aws-config"

  depends_on = [aws_config_configuration_recorder.main]
}

# IAM Role for AWS Config
resource "aws_iam_role" "config_role" {
  name_prefix = "${var.project_name}-${var.environment}-config-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-config-role"
  }
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3_policy" {
  name = "config-s3-delivery"
  role = aws_iam_role.config_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${module.storage.backups_bucket_arn}/aws-config/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketAcl"
        ]
        Resource = module.storage.backups_bucket_arn
      }
    ]
  })
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
  
  secrets = {
    DB_PASSWORD = module.database.db_password_secret_arn
    JWT_SECRET  = var.jwt_secret_arn
  }
  
  # Secure Design Iteration: Least Privilege - Specific S3 bucket ARN instead of wildcard
  s3_bucket_arns = [module.storage.documents_bucket_arn]
  s3_allowed_actions = [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject"
  ]
  
  # Secure Design Iteration: Resource Tagging - Owner and CostCenter for governance
  owner       = var.owner
  cost_center = var.cost_center
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
  
  secrets = {
    DB_PASSWORD = module.database.db_password_secret_arn
    JWT_SECRET  = var.jwt_secret_arn
  }
  
  # Secure Design Iteration: Least Privilege - WebSocket service has read-only S3 access
  s3_bucket_arns = [module.storage.documents_bucket_arn]
  s3_allowed_actions = [
    "s3:GetObject"
  ]
  
  # Secure Design Iteration: Resource Tagging - Owner and CostCenter for governance
  owner       = var.owner
  cost_center = var.cost_center
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

