# Main Terraform configuration for ECS Fargate CI/CD Infrastructure
# This file orchestrates all modules and defines the root configuration

# AWS Provider configuration with default tags for compliance
# Requirements: 10.6, 11.4
# All resources created by this provider will automatically receive these tags
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      # Mandatory compliance tags (NIST, SOC-2)
      # Requirements: 11.4
      Environment = var.environment
      Owner       = var.mandatory_tags.Owner
      CostCenter  = var.mandatory_tags.CostCenter
      Compliance  = var.mandatory_tags.Compliance

      # Infrastructure management tags
      ManagedBy = "Terraform"
      Project   = var.project_name

      # Environment-specific tags
      # Requirements: 10.6
      IsProduction    = var.environment == "prod" ? "true" : "false"
      SecurityLevel   = var.environment == "prod" ? "high" : "standard"
      ComplianceScope = var.environment == "prod" ? "full" : "limited"
      DataClass       = var.environment == "prod" ? "confidential" : "internal"
      BackupPolicy    = var.environment == "prod" ? "daily" : "weekly"
    }
  }
}

# Data source for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# Module Instantiations
# =============================================================================

# Networking Module - VPC, Subnets, Security Groups
# Requirements: 7.1, 7.2, 7.3, 7.4, 7.9, 10.4
module "networking" {
  source = "./modules/networking"

  environment        = var.environment
  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  # Production VPC isolation configuration
  # Requirements: 10.4
  is_production                    = local.is_production
  production_vpc_cidr_prefix       = var.production_vpc_cidr_prefix
  non_production_vpc_cidr_prefixes = var.non_production_vpc_cidr_prefixes

  # VPC Peering configuration for cross-environment communication
  enable_vpc_peering      = var.enable_vpc_peering
  vpc_peering_connections = var.vpc_peering_connections

  tags = local.common_tags
}

# Security Module - KMS Keys and IAM Roles
module "security" {
  source = "./modules/security"

  environment    = var.environment
  project_name   = var.project_name
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id

  # Environment-specific settings
  key_deletion_window_days   = var.kms_key_deletion_window_override != null ? var.kms_key_deletion_window_override : local.kms_key_deletion_window
  require_mfa_for_production = true

  tags = local.common_tags
}

# Secrets Module - Secrets Manager Configuration
module "secrets" {
  source = "./modules/secrets"

  environment  = var.environment
  project_name = var.project_name
  aws_region   = var.aws_region
  kms_key_arn  = module.security.kms_key_secrets_arn

  secrets = var.secrets
  # Environment-specific recovery window: 30 days for production, 7 days for non-production
  recovery_window_days = local.secrets_recovery_window

  tags = local.common_tags
}

# =============================================================================
# ECS Cluster Module
# Requirements: 2.8, 5.1, 10.1
# =============================================================================

module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  environment  = var.environment
  project_name = var.project_name

  # Container insights enabled for all environments
  enable_container_insights = true

  # Execute command logging for debugging
  enable_execute_command_logging     = true
  execute_command_log_retention_days = local.log_retention_days

  # Environment-specific capacity provider strategy
  # Production: 100% FARGATE for reliability (no spot interruptions)
  # Non-production: Mix of FARGATE and FARGATE_SPOT for cost savings
  fargate_weight      = local.fargate_weight
  fargate_spot_weight = local.fargate_spot_weight
  fargate_base        = local.is_production ? 2 : 1

  # KMS encryption for execute command logs
  kms_key_arn = module.security.kms_key_cloudwatch_arn

  tags = local.common_tags
}

# =============================================================================
# Monitoring Module
# Requirements: 2.6, 6.1, 6.2, 10.1
# =============================================================================

module "monitoring" {
  source = "./modules/monitoring"

  environment      = var.environment
  project_name     = var.project_name
  ecs_cluster_name = module.ecs_cluster.cluster_name
  ecs_cluster_arn  = module.ecs_cluster.cluster_arn
  kms_key_arn      = module.security.kms_key_cloudwatch_arn
  aws_account_id   = data.aws_caller_identity.current.account_id

  # Environment-specific log retention
  # Production: 90 days for compliance (NIST AU-9, SOC-2 CC7.2)
  # Non-production: 30 days for cost optimization
  log_retention_days = local.log_retention_days

  # Environment-specific alarm thresholds
  # Production: More aggressive alerting (70%)
  # Non-production: Relaxed thresholds (80%)
  cpu_utilization_threshold    = local.cpu_alarm_threshold
  memory_utilization_threshold = local.memory_alarm_threshold
  alarm_evaluation_periods     = local.alarm_evaluation_periods

  # SNS notifications
  enable_sns_notifications = true

  # Dashboard
  enable_dashboard = true

  # Services to monitor (empty initially, populated when services are deployed)
  services = {}

  tags = local.common_tags
}

# =============================================================================
# ALB Module (for public-facing services)
# Requirements: 6.3, 8.4, 8.5, 10.1
# =============================================================================

module "alb" {
  source = "./modules/alb"

  environment  = var.environment
  project_name = var.project_name

  # Network configuration
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids

  # Security configuration
  allowed_cidr_blocks = var.allowed_cidr_blocks

  # Environment-specific deletion protection
  # Production: Always enabled to prevent accidental deletion
  # Non-production: Disabled for easier cleanup
  enable_deletion_protection = local.enable_deletion_protection

  # Access logging with encryption
  # Temporarily disabled to troubleshoot bucket permission issues
  enable_access_logs = false
  kms_key_s3_arn     = module.security.kms_key_s3_arn

  # TLS configuration - enforce TLS 1.2 minimum
  ssl_policy = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  # Certificate ARN (must be provided via variable)
  certificate_arn = var.certificate_arn

  # Target groups (empty initially, populated when services are deployed)
  target_groups = {}

  tags = local.common_tags
}

# =============================================================================
# CloudTrail Module
# Requirements: 11.1, 11.2
# =============================================================================

module "cloudtrail" {
  source = "./modules/cloudtrail"

  environment    = var.environment
  project_name   = var.project_name
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id

  # KMS encryption configuration
  # Requirements: 11.1 - Encryption enabled
  kms_key_arn            = module.security.kms_key_s3_arn
  kms_key_cloudwatch_arn = module.security.kms_key_cloudwatch_arn

  # S3 bucket configuration
  # Requirements: 11.2 - Versioning and MFA delete
  enable_mfa_delete  = local.resource_protection.enable_s3_mfa_delete
  log_retention_days = local.log_retention_days

  # CloudTrail configuration
  is_multi_region_trail           = true
  enable_s3_data_events           = local.is_production
  enable_advanced_event_selectors = false
  enable_insights                 = local.is_production

  # CloudWatch alerts for security events
  enable_cloudtrail_alerts         = true
  unauthorized_api_calls_threshold = local.is_production ? 3 : 5
  iam_policy_changes_threshold     = local.is_production ? 1 : 3
  security_group_changes_threshold = local.is_production ? 3 : 5

  tags = local.common_tags
}


# =============================================================================
# AWS Config Module
# Requirements: 11.5 - Track configuration changes for compliance auditing
# =============================================================================

module "config" {
  source = "./modules/config"

  environment    = var.environment
  project_name   = var.project_name
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id

  # KMS encryption for S3 bucket
  kms_key_arn = module.security.kms_key_s3_arn

  # Recording configuration
  recording_frequency      = "CONTINUOUS"
  include_global_resources = true

  # Log retention - same as other compliance logs
  log_retention_days = local.log_retention_days

  # Enable all managed rules for comprehensive compliance
  enable_managed_rules    = true
  enable_ecs_rules        = true
  enable_encryption_rules = true
  enable_iam_rules        = true
  enable_vpc_rules        = true

  # Config aggregator for multi-account (disabled by default)
  # Enable if using AWS Organizations or multiple accounts
  enable_aggregator      = var.enable_config_aggregator
  aggregator_account_ids = var.config_aggregator_account_ids
  aggregator_regions     = var.config_aggregator_regions

  # SNS notifications for compliance alerts
  enable_sns_notifications = true

  tags = local.common_tags
}
