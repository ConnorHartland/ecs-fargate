# =============================================================================
# Terraform Variables for Production Environment
# =============================================================================
# Full security controls, higher resource limits, stricter access controls
# Requirements: 10.1, 10.5 - Environment-specific configurations with enhanced security
# =============================================================================

# =============================================================================
# Environment Configuration
# =============================================================================

environment  = "prod"
aws_region   = "us-east-1"
project_name = "ecs-fargate"

# =============================================================================
# Network Configuration
# =============================================================================
# Requirements: 10.4 - Production VPC uses distinct CIDR (10.100.x.x) from non-production (10.0-2.x.x)

vpc_cidr           = "10.100.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# =============================================================================
# VPC Isolation Configuration
# =============================================================================
# Production uses 10.100.x.x range, non-production uses 10.0-2.x.x ranges

production_vpc_cidr_prefix       = "10.100."
non_production_vpc_cidr_prefixes = ["10.0.", "10.1.", "10.2."]

# VPC Peering Configuration (for cross-environment communication if needed)
# Set enable_vpc_peering = true and configure vpc_peering_connections to enable
# Example:
# enable_vpc_peering = true
# vpc_peering_connections = [
#   {
#     peer_vpc_id      = "vpc-xxxxxxxxx"  # Non-production VPC ID
#     peer_vpc_cidr    = "10.0.0.0/16"    # Non-production VPC CIDR
#     name             = "prod-to-develop"
#     allow_remote_dns = true
#   }
# ]
enable_vpc_peering      = false
vpc_peering_connections = []

# =============================================================================
# Kafka Configuration
# =============================================================================
# Update with actual production broker endpoints

kafka_brokers           = []
kafka_security_group_id = ""

# =============================================================================
# Security Configuration
# =============================================================================
# Requirements: 10.5 - Stricter access controls for production

allowed_cidr_blocks        = ["0.0.0.0/0"]
enable_deletion_protection = true

# =============================================================================
# Environment-Specific Resource Configuration
# =============================================================================
# Requirements: 10.1, 10.5 - Production-specific settings with enhanced security
# Production environment uses higher resource limits and stricter security

# CloudWatch Log Retention
# Production: 90 days (compliance requirement for audit trails)
# Requirements: 2.6 - Minimum 90 days retention for production
log_retention_days_override = 90

# Deletion Protection
# Production: Enabled (prevent accidental deletion of critical resources)
enable_deletion_protection_override = true

# KMS Key Deletion Window
# Production: 30 days (maximum protection, allows recovery from mistakes)
kms_key_deletion_window_override = 30

# Default ECS Task Resources
# Production: Higher CPU/memory for performance and reliability
default_cpu_override          = 512  # Higher CPU for production workloads
default_memory_override       = 1024 # Higher memory for production workloads
default_desired_count_override = 2    # Multiple tasks for high availability

# Fargate Spot
# Production: Disabled (use only On-Demand for maximum reliability)
# Fargate Spot can be interrupted, not suitable for production
fargate_spot_enabled = false

# =============================================================================
# ALB Configuration
# =============================================================================
# Requirements: 2.2, 8.5 - TLS encryption with ACM certificate

certificate_arn = "" # REQUIRED: Add production ACM certificate ARN for HTTPS listener

# =============================================================================
# AWS Config Configuration
# =============================================================================
# Requirements: 11.5 - AWS Config for compliance tracking
# Production enables Config for comprehensive compliance auditing

enable_config_aggregator      = false
config_aggregator_account_ids = []
config_aggregator_regions     = []

# Enable multi-account/multi-region aggregation if needed:
# enable_config_aggregator = true
# config_aggregator_account_ids = ["123456789012", "234567890123"]
# config_aggregator_regions = ["us-east-1", "us-west-2"]

# =============================================================================
# Compliance Tags
# =============================================================================
# Requirements: 10.6, 11.4 - Mandatory tags for all resources
# Production requires comprehensive compliance tags

mandatory_tags = {
  Owner      = "Platform Team"
  CostCenter = "Production"
  Compliance = "NIST-SOC2"
}

# =============================================================================
# Secrets Configuration
# =============================================================================
# Example secrets configuration - update with actual production secrets
# Requirements: 9.1, 9.2, 9.4, 9.5 - Secrets Manager with encryption and rotation
# All production secrets MUST have rotation enabled where supported

secrets = {
  # Example database secret with rotation
  # "prod-db-credentials" = {
  #   description         = "Production database credentials"
  #   secret_type         = "database"
  #   service_name        = "example-service"
  #   initial_value = {
  #     username = "produser"
  #     password = "CHANGE_ME_IN_AWS_CONSOLE"
  #     host     = "db.prod.internal"
  #     port     = "5432"
  #     database = "prod_db"
  #   }
  #   enable_rotation     = true
  #   rotation_days       = 30
  #   rotation_lambda_arn = "arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRotation"
  # }
  
  # Example API key secret
  # "prod-api-key" = {
  #   description   = "Production API key for external service"
  #   secret_type   = "api_key"
  #   service_name  = "example-service"
  #   initial_value = {
  #     api_key = "CHANGE_ME_IN_AWS_CONSOLE"
  #   }
  #   enable_rotation = true
  #   rotation_days   = 90
  # }
  
  # Example OAuth credentials
  # "prod-oauth-credentials" = {
  #   description   = "OAuth credentials for third-party integration"
  #   secret_type   = "oauth"
  #   service_name  = "example-service"
  #   initial_value = {
  #     client_id     = "CHANGE_ME_IN_AWS_CONSOLE"
  #     client_secret = "CHANGE_ME_IN_AWS_CONSOLE"
  #     token_url     = "https://oauth.example.com/token"
  #   }
  #   enable_rotation = false
  # }
}
