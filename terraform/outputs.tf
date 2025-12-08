# Root outputs for ECS Fargate CI/CD Infrastructure
# These outputs expose key resource identifiers for reference

# =============================================================================
# Account and Region Information
# =============================================================================

output "aws_account_id" {
  description = "AWS account ID where resources are deployed"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

output "environment" {
  description = "Current deployment environment"
  value       = var.environment
}



# =============================================================================
# Security Outputs
# =============================================================================

output "kms_key_arns" {
  description = "Map of KMS key ARNs by purpose"
  value       = module.security.kms_keys
}

output "iam_role_arns" {
  description = "Map of IAM role ARNs by purpose"
  value       = module.security.iam_roles
}

# =============================================================================
# Secrets Manager Outputs
# =============================================================================

output "secret_arns" {
  description = "Map of secret names to their ARNs"
  value       = module.secrets.secret_arns
}

output "secret_names" {
  description = "Map of secret keys to their full names in Secrets Manager"
  value       = module.secrets.secret_names
}

output "secret_read_policy_arn" {
  description = "ARN of the IAM policy for reading all secrets"
  value       = module.secrets.secret_read_policy_arn
}

output "service_secret_policy_arns" {
  description = "Map of service names to their secret access policy ARNs"
  value       = module.secrets.service_secret_policy_arns
}

output "secrets_with_rotation" {
  description = "List of secret names that have rotation enabled"
  value       = module.secrets.secrets_with_rotation
}

# =============================================================================
# Service Outputs (populated when services are deployed)
# =============================================================================

# output "services" {
#   description = "Map of deployed services with their details"
#   value = {
#     for name, service in module.services : name => {
#       service_arn        = service.service_arn
#       ecr_repository_url = service.ecr_repository_url
#       pipeline_name      = service.pipeline_name
#       task_role_arn      = service.task_role_arn
#       security_group_id  = service.security_group_id
#     }
#   }
# }

# =============================================================================
# Environment-Specific Configuration Outputs
# Requirements: 10.1, 10.5
# =============================================================================

output "environment_config" {
  description = "Environment-specific configuration settings"
  value       = local.environment_config
}

output "is_production" {
  description = "Whether this is a production environment"
  value       = local.is_production
}

output "effective_log_retention_days" {
  description = "Effective CloudWatch log retention in days"
  value       = local.log_retention_days
}

output "effective_deletion_protection" {
  description = "Whether deletion protection is enabled"
  value       = local.enable_deletion_protection
}

output "effective_kms_key_deletion_window" {
  description = "Effective KMS key deletion window in days"
  value       = local.kms_key_deletion_window
}

output "effective_capacity_provider_strategy" {
  description = "Effective Fargate capacity provider weights"
  value = {
    fargate_weight      = local.fargate_weight
    fargate_spot_weight = local.fargate_spot_weight
  }
}

output "production_iam_policies" {
  description = "Production-specific IAM policy ARNs (only populated in production)"
  value = local.is_production ? {
    production_access_policy     = module.security.production_access_policy_arn
    production_protection_policy = module.security.production_protection_policy_arn
    permissions_boundary_policy  = module.security.permissions_boundary_policy_arn
  } : null
}

# =============================================================================
# IAM Configuration Outputs
# Requirements: 10.5
# =============================================================================

output "iam_config" {
  description = "Environment-specific IAM configuration settings"
  value       = local.iam_config
}

output "resource_protection" {
  description = "Environment-specific resource protection settings"
  value       = local.resource_protection
}

# =============================================================================
# Resource Tagging Outputs
# Requirements: 10.6, 11.4
# =============================================================================

output "common_tags" {
  description = "Common tags applied to all resources (mandatory compliance + environment-specific)"
  value       = local.common_tags
}

output "environment_tags" {
  description = "Environment-specific tags"
  value       = local.environment_tags
}

output "mandatory_tags" {
  description = "Mandatory compliance tags (Environment, Owner, CostCenter, Compliance)"
  value = {
    Environment = var.environment
    Owner       = var.mandatory_tags.Owner
    CostCenter  = var.mandatory_tags.CostCenter
    Compliance  = var.mandatory_tags.Compliance
  }
}

# =============================================================================
# ECS Cluster Outputs
# =============================================================================

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs_cluster.cluster_arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs_cluster.cluster_name
}

# =============================================================================
# Networking Outputs
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  value       = module.networking.public_subnet_ids
}

# =============================================================================
# ALB Outputs
# =============================================================================

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_security_group_id" {
  description = "Security group ID for the ALB"
  value       = module.alb.security_group_id
}

output "alb_listener_arn" {
  description = "ARN of the ALB listener (HTTPS if certificate provided, otherwise HTTP)"
  value       = module.alb.https_listener_arn != null ? module.alb.https_listener_arn : module.alb.http_listener_arn
}

output "alb_https_listener_arn" {
  description = "ARN of the HTTPS listener (null if no certificate)"
  value       = module.alb.https_listener_arn
}

output "alb_http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = module.alb.http_listener_arn
}

# =============================================================================
# Monitoring Outputs
# =============================================================================

output "monitoring_sns_topics" {
  description = "SNS topic ARNs for monitoring notifications"
  value = {
    critical_alarms        = module.monitoring.critical_alarms_topic_arn
    warning_alarms         = module.monitoring.warning_alarms_topic_arn
    pipeline_notifications = module.monitoring.pipeline_notifications_topic_arn
  }
}

output "cluster_log_group_name" {
  description = "CloudWatch log group name for the ECS cluster"
  value       = module.monitoring.cluster_log_group_name
}

# =============================================================================
# VPC Isolation Outputs
# Requirements: 10.4
# =============================================================================

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.networking.vpc_cidr_block
}

output "vpc_isolation_validated" {
  description = "Whether VPC isolation validation passed (production uses distinct CIDR from non-production)"
  value       = module.networking.vpc_isolation_validated
}

output "is_production_vpc" {
  description = "Whether this VPC is configured as a production VPC"
  value       = module.networking.is_production_vpc
}

output "vpc_peering_connection_ids" {
  description = "List of VPC peering connection IDs (if VPC peering is enabled)"
  value       = module.networking.vpc_peering_connection_ids
}

output "vpc_peering_connection_statuses" {
  description = "Map of VPC peering connection names to their status"
  value       = module.networking.vpc_peering_connection_statuses
}

# =============================================================================
# CloudTrail Outputs
# Requirements: 11.1, 11.2
# =============================================================================

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = module.cloudtrail.cloudtrail_arn
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail"
  value       = module.cloudtrail.cloudtrail_name
}

output "cloudtrail_s3_bucket_arn" {
  description = "ARN of the S3 bucket for CloudTrail logs"
  value       = module.cloudtrail.s3_bucket_arn
}

output "cloudtrail_s3_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  value       = module.cloudtrail.s3_bucket_name
}

output "cloudtrail_cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for CloudTrail"
  value       = module.cloudtrail.cloudwatch_log_group_arn
}

output "cloudtrail_compliance_status" {
  description = "Compliance status summary for CloudTrail configuration"
  value       = module.cloudtrail.compliance_status
}

output "cloudtrail_alerts_topic_arn" {
  description = "ARN of the SNS topic for CloudTrail security alerts"
  value       = module.cloudtrail.cloudtrail_alerts_topic_arn
}


# =============================================================================
# AWS Config Outputs
# Requirements: 11.5
# =============================================================================

output "config_recorder_id" {
  description = "ID of the AWS Config recorder"
  value       = module.config.config_recorder_id
}

output "config_recorder_name" {
  description = "Name of the AWS Config recorder"
  value       = module.config.config_recorder_name
}

output "config_delivery_channel_id" {
  description = "ID of the AWS Config delivery channel"
  value       = module.config.delivery_channel_id
}

output "config_s3_bucket_arn" {
  description = "ARN of the S3 bucket for Config delivery"
  value       = module.config.s3_bucket_arn
}

output "config_s3_bucket_name" {
  description = "Name of the S3 bucket for Config delivery"
  value       = module.config.s3_bucket_name
}

output "config_notifications_topic_arn" {
  description = "ARN of the SNS topic for Config notifications"
  value       = module.config.config_notifications_topic_arn
}

output "config_compliance_alerts_topic_arn" {
  description = "ARN of the SNS topic for compliance alerts"
  value       = module.config.compliance_alerts_topic_arn
}

output "config_aggregator_arn" {
  description = "ARN of the Config aggregator (null if not enabled)"
  value       = module.config.aggregator_arn
}

output "config_enabled" {
  description = "Whether AWS Config is enabled"
  value       = module.config.config_enabled
}

output "config_compliance_status" {
  description = "Compliance status summary for AWS Config configuration"
  value       = module.config.compliance_status
}

output "config_rules" {
  description = "Map of all Config rule ARNs by category"
  value = {
    ecs        = module.config.ecs_config_rules
    encryption = module.config.encryption_config_rules
    iam        = module.config.iam_config_rules
    vpc        = module.config.vpc_config_rules
  }
}
