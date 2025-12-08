# Environment-Specific Configuration
# Centralizes environment-specific settings for production vs non-production
# Requirements: 10.1, 10.5

# =============================================================================
# Local Variables for Environment-Specific Settings
# =============================================================================

locals {
  # Determine if this is a production environment
  is_production = var.environment == "prod"

  # Determine if this is a non-production environment
  is_non_production = contains(["develop", "test", "qa"], var.environment)

  # =============================================================================
  # Log Retention Configuration
  # Production: 90 days minimum for compliance (NIST AU-9, SOC-2 CC7.2)
  # Non-production: 30 days for cost optimization
  # =============================================================================
  log_retention_days = local.is_production ? 90 : 30

  # =============================================================================
  # Resource Limits Configuration
  # Production: Higher limits for reliability
  # Non-production: Lower limits for cost optimization
  # =============================================================================
  default_cpu             = local.is_production ? 512 : 256
  default_memory          = local.is_production ? 1024 : 512
  default_desired_count   = local.is_production ? 2 : 1
  default_autoscaling_min = local.is_production ? 2 : 1
  default_autoscaling_max = local.is_production ? 20 : 5

  # =============================================================================
  # Deletion Protection Configuration
  # Production: Always enabled to prevent accidental deletion
  # Non-production: Disabled for easier cleanup
  # =============================================================================
  enable_deletion_protection = local.is_production ? true : false

  # =============================================================================
  # Security Configuration
  # Production: Stricter security settings
  # Non-production: Relaxed for development flexibility
  # =============================================================================

  # KMS key deletion window (days)
  # Production: 30 days for recovery time
  # Non-production: 7 days for faster cleanup
  kms_key_deletion_window = local.is_production ? 30 : 7

  # Secrets recovery window (days)
  # Production: 30 days for recovery time
  # Non-production: 7 days for faster cleanup
  secrets_recovery_window = local.is_production ? 30 : 7

  # =============================================================================
  # Capacity Provider Strategy
  # Production: 100% FARGATE for reliability (no spot interruptions)
  # Non-production: Mix of FARGATE and FARGATE_SPOT for cost savings
  # =============================================================================
  fargate_weight      = local.is_production ? 100 : 70
  fargate_spot_weight = local.is_production ? 0 : 30

  # =============================================================================
  # Deployment Configuration
  # Production: More conservative deployment settings
  # Non-production: Faster deployments
  # =============================================================================
  deployment_minimum_healthy_percent = local.is_production ? 100 : 50
  deployment_maximum_percent         = local.is_production ? 200 : 200

  # =============================================================================
  # Monitoring Configuration
  # Production: More aggressive alerting
  # Non-production: Relaxed thresholds
  # =============================================================================
  cpu_alarm_threshold      = local.is_production ? 70 : 80
  memory_alarm_threshold   = local.is_production ? 70 : 80
  alarm_evaluation_periods = local.is_production ? 2 : 3

  # =============================================================================
  # S3 Lifecycle Configuration
  # Production: Longer retention for compliance
  # Non-production: Shorter retention for cost savings
  # =============================================================================
  s3_log_expiration_days        = local.is_production ? 365 : 90
  s3_transition_to_ia_days      = local.is_production ? 30 : 30
  s3_transition_to_glacier_days = local.is_production ? 90 : 60

  # =============================================================================
  # Environment-Specific Tags
  # =============================================================================
  environment_tags = {
    Environment     = var.environment
    IsProduction    = tostring(local.is_production)
    SecurityLevel   = local.is_production ? "high" : "standard"
    ComplianceScope = local.is_production ? "full" : "limited"
  }
}

# =============================================================================
# Environment Configuration Output for Modules
# =============================================================================

# This local map can be passed to modules for consistent environment configuration
locals {
  environment_config = {
    # Environment identification
    environment       = var.environment
    is_production     = local.is_production
    is_non_production = local.is_non_production

    # Log retention
    log_retention_days = local.log_retention_days

    # Resource limits
    default_cpu             = local.default_cpu
    default_memory          = local.default_memory
    default_desired_count   = local.default_desired_count
    default_autoscaling_min = local.default_autoscaling_min
    default_autoscaling_max = local.default_autoscaling_max

    # Security settings
    enable_deletion_protection = local.enable_deletion_protection
    kms_key_deletion_window    = local.kms_key_deletion_window
    secrets_recovery_window    = local.secrets_recovery_window

    # Capacity provider strategy
    fargate_weight      = local.fargate_weight
    fargate_spot_weight = local.fargate_spot_weight

    # Deployment configuration
    deployment_minimum_healthy_percent = local.deployment_minimum_healthy_percent
    deployment_maximum_percent         = local.deployment_maximum_percent

    # Monitoring thresholds
    cpu_alarm_threshold      = local.cpu_alarm_threshold
    memory_alarm_threshold   = local.memory_alarm_threshold
    alarm_evaluation_periods = local.alarm_evaluation_periods

    # S3 lifecycle
    s3_log_expiration_days        = local.s3_log_expiration_days
    s3_transition_to_ia_days      = local.s3_transition_to_ia_days
    s3_transition_to_glacier_days = local.s3_transition_to_glacier_days

    # Tags
    environment_tags = local.environment_tags
  }
}
