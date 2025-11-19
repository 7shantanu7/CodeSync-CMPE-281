variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cache_subnet_ids" {
  description = "Cache subnet IDs"
  type        = list(string)
}

variable "cache_subnet_group_name" {
  description = "Cache subnet group name"
  type        = string
}

variable "cache_sg_id" {
  description = "Cache security group ID"
  type        = string
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
}

variable "num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
}

