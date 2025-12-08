# AWS Config Module Outputs
# Exposes AWS Config resources for use by other modules
# Requirements: 11.5

# =============================================================================
# Config Recorder Outputs
# =============================================================================

output "config_recorder_id" {
  description = "ID of the AWS Config recorder"
  value       = aws_config_configuration_recorder.main.id
}

output "config_recorder_name" {
  description = "Name of the AWS Config recorder"
  value       = aws_config_configuration_recorder.main.name
}

output "config_recorder_role_arn" {
  description = "ARN of the IAM role used by the Config recorder"
  value       = aws_iam_role.config.arn
}

# =============================================================================
# Delivery Channel Outputs
# =============================================================================

output "delivery_channel_id" {
  description = "ID of the AWS Config delivery channel"
  value       = aws_config_delivery_channel.main.id
}

output "delivery_channel_name" {
  description = "Name of the AWS Config delivery channel"
  value       = aws_config_delivery_channel.main.name
}

# =============================================================================
# S3 Bucket Outputs
# =============================================================================

output "s3_bucket_id" {
  description = "ID of the S3 bucket for Config delivery"
  value       = aws_s3_bucket.config.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Config delivery"
  value       = aws_s3_bucket.config.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Config delivery"
  value       = aws_s3_bucket.config.bucket
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket for Config delivery"
  value       = aws_s3_bucket.config.bucket_domain_name
}

# =============================================================================
# SNS Topic Outputs
# =============================================================================

output "config_notifications_topic_arn" {
  description = "ARN of the SNS topic for Config notifications (null if disabled)"
  value       = length(aws_sns_topic.config) > 0 ? aws_sns_topic.config[0].arn : var.sns_topic_arn
}

output "compliance_alerts_topic_arn" {
  description = "ARN of the SNS topic for compliance alerts (null if disabled)"
  value       = length(aws_sns_topic.compliance_alerts) > 0 ? aws_sns_topic.compliance_alerts[0].arn : null
}

# =============================================================================
# Config Aggregator Outputs
# =============================================================================

output "aggregator_arn" {
  description = "ARN of the Config aggregator (null if not enabled)"
  value       = length(aws_config_configuration_aggregator.main) > 0 ? aws_config_configuration_aggregator.main[0].arn : null
}

output "aggregator_name" {
  description = "Name of the Config aggregator (null if not enabled)"
  value       = length(aws_config_configuration_aggregator.main) > 0 ? aws_config_configuration_aggregator.main[0].name : null
}

# =============================================================================
# Config Rules Outputs
# =============================================================================

output "ecs_config_rules" {
  description = "Map of ECS-related Config rule ARNs"
  value = {
    memory_hard_limit   = length(aws_config_config_rule.ecs_task_definition_memory_hard_limit) > 0 ? aws_config_config_rule.ecs_task_definition_memory_hard_limit[0].arn : null
    nonroot_user        = length(aws_config_config_rule.ecs_task_definition_nonroot_user) > 0 ? aws_config_config_rule.ecs_task_definition_nonroot_user[0].arn : null
    log_configuration   = length(aws_config_config_rule.ecs_task_definition_log_configuration) > 0 ? aws_config_config_rule.ecs_task_definition_log_configuration[0].arn : null
    readonly_access     = length(aws_config_config_rule.ecs_containers_readonly_access) > 0 ? aws_config_config_rule.ecs_containers_readonly_access[0].arn : null
  }
}

output "encryption_config_rules" {
  description = "Map of encryption-related Config rule ARNs"
  value = {
    s3_bucket_sse           = length(aws_config_config_rule.s3_bucket_server_side_encryption) > 0 ? aws_config_config_rule.s3_bucket_server_side_encryption[0].arn : null
    s3_bucket_ssl           = length(aws_config_config_rule.s3_bucket_ssl_requests_only) > 0 ? aws_config_config_rule.s3_bucket_ssl_requests_only[0].arn : null
    ecr_image_scanning      = length(aws_config_config_rule.ecr_private_image_scanning) > 0 ? aws_config_config_rule.ecr_private_image_scanning[0].arn : null
    cloudwatch_log_encrypted = length(aws_config_config_rule.cloudwatch_log_group_encrypted) > 0 ? aws_config_config_rule.cloudwatch_log_group_encrypted[0].arn : null
    kms_cmk_not_deleted     = length(aws_config_config_rule.kms_cmk_not_scheduled_for_deletion) > 0 ? aws_config_config_rule.kms_cmk_not_scheduled_for_deletion[0].arn : null
  }
}

output "iam_config_rules" {
  description = "Map of IAM-related Config rule ARNs"
  value = {
    root_access_key      = length(aws_config_config_rule.iam_root_access_key_check) > 0 ? aws_config_config_rule.iam_root_access_key_check[0].arn : null
    user_mfa_enabled     = length(aws_config_config_rule.iam_user_mfa_enabled) > 0 ? aws_config_config_rule.iam_user_mfa_enabled[0].arn : null
    no_admin_access      = length(aws_config_config_rule.iam_policy_no_admin_access) > 0 ? aws_config_config_rule.iam_policy_no_admin_access[0].arn : null
    unused_credentials   = length(aws_config_config_rule.iam_user_unused_credentials) > 0 ? aws_config_config_rule.iam_user_unused_credentials[0].arn : null
  }
}

output "vpc_config_rules" {
  description = "Map of VPC-related Config rule ARNs"
  value = {
    flow_logs_enabled       = length(aws_config_config_rule.vpc_flow_logs_enabled) > 0 ? aws_config_config_rule.vpc_flow_logs_enabled[0].arn : null
    default_sg_closed       = length(aws_config_config_rule.vpc_default_security_group_closed) > 0 ? aws_config_config_rule.vpc_default_security_group_closed[0].arn : null
    restricted_ssh          = length(aws_config_config_rule.restricted_ssh) > 0 ? aws_config_config_rule.restricted_ssh[0].arn : null
    restricted_common_ports = length(aws_config_config_rule.restricted_common_ports) > 0 ? aws_config_config_rule.restricted_common_ports[0].arn : null
  }
}

# =============================================================================
# Compliance Status Outputs
# =============================================================================

output "config_enabled" {
  description = "Whether AWS Config is enabled"
  value       = aws_config_configuration_recorder_status.main.is_enabled
}

output "compliance_status" {
  description = "Compliance status summary for AWS Config configuration"
  value = {
    config_recorder_enabled = aws_config_configuration_recorder_status.main.is_enabled
    s3_versioning_enabled   = aws_s3_bucket_versioning.config.versioning_configuration[0].status == "Enabled"
    s3_encryption_enabled   = true # Always true since we configure SSE
    sns_notifications       = var.enable_sns_notifications
    aggregator_enabled      = var.enable_aggregator
    managed_rules_enabled   = var.enable_managed_rules
    ecs_rules_count         = var.enable_ecs_rules ? 4 : 0
    encryption_rules_count  = var.enable_encryption_rules ? 5 : 0
    iam_rules_count         = var.enable_iam_rules ? 4 : 0
    vpc_rules_count         = var.enable_vpc_rules ? 4 : 0
  }
}

# =============================================================================
# IAM Role Outputs
# =============================================================================

output "config_role_arn" {
  description = "ARN of the IAM role for AWS Config"
  value       = aws_iam_role.config.arn
}

output "config_role_name" {
  description = "Name of the IAM role for AWS Config"
  value       = aws_iam_role.config.name
}

output "aggregator_role_arn" {
  description = "ARN of the IAM role for Config aggregator (null if not enabled)"
  value       = length(aws_iam_role.config_aggregator) > 0 ? aws_iam_role.config_aggregator[0].arn : null
}
