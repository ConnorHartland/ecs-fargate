# =============================================================================
# Terraform Variables for Develop Environment
# =============================================================================
# Lower resource limits, relaxed security for development
# Requirements: 10.1 - Environment-specific configurations
# =============================================================================

# =============================================================================
# Environment Configuration
# =============================================================================

environment  = "develop"
aws_region   = "us-east-1"
project_name = "ecs-fargate"

# =============================================================================
# Network Configuration
# =============================================================================
# Requirements: 10.4 - Non-production VPC uses distinct CIDR (10.0.x.x) from production (10.100.x.x)

vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# =============================================================================
# VPC Isolation Configuration
# =============================================================================
# Production uses 10.100.x.x range, non-production uses 10.0-2.x.x ranges

production_vpc_cidr_prefix       = "10.100."
non_production_vpc_cidr_prefixes = ["10.0.", "10.1.", "10.2."]

# VPC Peering Configuration (for cross-environment communication if needed)
enable_vpc_peering      = false
vpc_peering_connections = []

# =============================================================================
# Kafka Configuration
# =============================================================================
# Update with actual broker endpoints when available

kafka_brokers           = []
kafka_security_group_id = ""

# =============================================================================
# Security Configuration
# =============================================================================

allowed_cidr_blocks        = ["0.0.0.0/0"]
enable_deletion_protection = false

# =============================================================================
# Environment-Specific Resource Configuration
# =============================================================================
# Requirements: 10.1 - Environment-specific settings
# Develop environment uses lower resource limits for cost optimization

# CloudWatch Log Retention
# Develop: 30 days (lower retention for cost savings)
log_retention_days_override = 30

# Deletion Protection
# Develop: Disabled (allows easy cleanup of test resources)
enable_deletion_protection_override = false

# KMS Key Deletion Window
# Develop: 7 days (minimum, faster cleanup)
kms_key_deletion_window_override = 7

# Default ECS Task Resources
# Develop: Lower CPU/memory for cost optimization
default_cpu_override          = 256  # Minimum Fargate CPU
default_memory_override       = 512  # Minimum memory for 256 CPU
default_desired_count_override = 1    # Single task for development

# Fargate Spot
# Develop: Enabled (up to 70% cost savings for non-critical workloads)
fargate_spot_enabled = true

# =============================================================================
# ALB Configuration
# =============================================================================
# Update with actual ACM certificate ARN for HTTPS

certificate_arn = "" # Add ACM certificate ARN for HTTPS listener

# =============================================================================
# AWS Config Configuration
# =============================================================================
# Requirements: 11.5 - AWS Config for compliance tracking

enable_config_aggregator      = false
config_aggregator_account_ids = []
config_aggregator_regions     = []

# =============================================================================
# Compliance Tags
# =============================================================================
# Requirements: 10.6, 11.4 - Mandatory tags for all resources

mandatory_tags = {
  Owner      = "DevOps Team"
  CostCenter = "Development"
  Compliance = "Internal"
}

# =============================================================================
# Secrets Configuration
# =============================================================================
# Example secrets configuration - update with actual secrets needed
# Secrets are created in AWS Secrets Manager with KMS encryption

secrets = {
  # Example database secret
  # "example-db-credentials" = {
  #   description   = "Database credentials for example service"
  #   secret_type   = "database"
  #   service_name  = "example-service"
  #   initial_value = {
  #     username = "admin"
  #     password = "CHANGE_ME_IN_AWS_CONSOLE"
  #     host     = "db.develop.internal"
  #     port     = "5432"
  #     database = "example_db"
  #   }
  #   enable_rotation = false
  # }
  
  # Example API key secret
  # "example-api-key" = {
  #   description   = "API key for external service"
  #   secret_type   = "api_key"
  #   service_name  = "example-service"
  #   initial_value = {
  #     api_key = "CHANGE_ME_IN_AWS_CONSOLE"
  #   }
  #   enable_rotation = false
  # }
}
