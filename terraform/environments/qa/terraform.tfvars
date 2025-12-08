# =============================================================================
# Terraform Variables for QA Environment
# =============================================================================
# Production-like configuration for final validation before production
# Requirements: 10.1 - Environment-specific configurations
# =============================================================================

# =============================================================================
# Environment Configuration
# =============================================================================

environment  = "qa"
aws_region   = "us-east-1"
project_name = "ecs-fargate"

# =============================================================================
# Network Configuration
# =============================================================================
# Requirements: 10.4 - Non-production VPC uses distinct CIDR (10.2.x.x) from production (10.100.x.x)

vpc_cidr           = "10.2.0.0/16"
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
enable_deletion_protection = true

# =============================================================================
# Environment-Specific Resource Configuration
# =============================================================================
# Requirements: 10.1 - Environment-specific settings
# QA environment mirrors production settings for final validation

# CloudWatch Log Retention
# QA: 60 days (longer retention for compliance validation)
log_retention_days_override = 60

# Deletion Protection
# QA: Enabled (protect stable QA environment)
enable_deletion_protection_override = true

# KMS Key Deletion Window
# QA: 14 days (moderate protection)
kms_key_deletion_window_override = 14

# Default ECS Task Resources
# QA: Production-equivalent resources for accurate validation
default_cpu_override          = 512  # Production-equivalent CPU
default_memory_override       = 1024 # Production-equivalent memory
default_desired_count_override = 2    # Multiple tasks like production

# Fargate Spot
# QA: Partially enabled (70% Spot, 30% On-Demand for stability)
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
# QA environment enables Config for compliance validation

enable_config_aggregator      = false
config_aggregator_account_ids = []
config_aggregator_regions     = []

# =============================================================================
# Compliance Tags
# =============================================================================
# Requirements: 10.6, 11.4 - Mandatory tags for all resources

mandatory_tags = {
  Owner      = "DevOps Team"
  CostCenter = "QA"
  Compliance = "SOC-2"
}

# =============================================================================
# Secrets Configuration
# =============================================================================
# Example secrets configuration - update with actual secrets needed
# Secrets are created in AWS Secrets Manager with KMS encryption

secrets = {
  # Example database secret
  # "qa-db-credentials" = {
  #   description   = "Database credentials for QA environment"
  #   secret_type   = "database"
  #   service_name  = "example-service"
  #   initial_value = {
  #     username = "qauser"
  #     password = "CHANGE_ME_IN_AWS_CONSOLE"
  #     host     = "db.qa.internal"
  #     port     = "5432"
  #     database = "qa_db"
  #   }
  #   enable_rotation = true
  #   rotation_days   = 30
  # }
  
  # Example API key secret
  # "qa-api-key" = {
  #   description   = "API key for external service (QA)"
  #   secret_type   = "api_key"
  #   service_name  = "example-service"
  #   initial_value = {
  #     api_key = "CHANGE_ME_IN_AWS_CONSOLE"
  #   }
  #   enable_rotation = false
  # }
}
