# ElastiCache Redis Module

resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.project_name}-${var.environment}-redis"
  replication_group_description = "Redis cluster for ${var.project_name}"

  # Engine
  engine               = "redis"
  engine_version       = "7.0"
  port                 = 6379
  parameter_group_name = "default.redis7"

  # Node configuration
  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_nodes

  # Network
  subnet_group_name  = var.cache_subnet_group_name
  security_group_ids = [var.cache_sg_id]

  # High Availability
  automatic_failover_enabled = var.num_cache_nodes > 1
  multi_az_enabled           = var.num_cache_nodes > 1

  # Maintenance
  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_window          = "03:00-04:00"
  snapshot_retention_limit = 5

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false # Set to true in production (requires auth token)

  # Auto minor version upgrades
  auto_minor_version_upgrade = true

  # Notifications
  notification_topic_arn = ""

  tags = {
    Name = "${var.project_name}-${var.environment}-redis"
  }
}

