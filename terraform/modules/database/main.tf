# RDS PostgreSQL Database Module

# Random password for database
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name_prefix             = "${var.project_name}-${var.environment}-db-password-"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-db-password"
  }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# RDS Instance with Multi-AZ
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-db"

  # Engine
  engine         = "postgres"
  engine_version = "15.4"

  # Instance
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  # Database
  db_name  = replace("${var.project_name}${var.environment}", "-", "_")
  username = var.db_username
  password = random_password.db_password.result

  # Network
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.database_sg_id]
  publicly_accessible    = false

  # Multi-AZ for high availability
  multi_az = var.multi_az

  # Backup
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Performance Insights
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = true
  performance_insights_retention_period = 7

  # Auto minor version upgrades
  auto_minor_version_upgrade = true

  # Deletion protection
  deletion_protection = false # Set to true in production
  skip_final_snapshot = true  # Set to false in production
  # final_snapshot_identifier = "${var.project_name}-${var.environment}-final-snapshot"

  tags = {
    Name = "${var.project_name}-${var.environment}-db"
  }
}

# CloudWatch Alarms for Database
resource "aws_cloudwatch_metric_alarm" "database_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-db-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}

resource "aws_cloudwatch_metric_alarm" "database_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-db-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 256000000 # 256 MB
  alarm_description   = "This metric monitors RDS freeable memory"
  alarm_actions       = []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }
}

