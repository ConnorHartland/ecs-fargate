# CloudTrail Module Outputs
# Exposes CloudTrail and S3 bucket information for use by other modules
# Requirements: 11.1, 11.2

# =============================================================================
# CloudTrail Outputs
# =============================================================================

output "cloudtrail_id" {
  description = "ID of the CloudTrail"
  value       = aws_cloudtrail.main.id
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail"
  value       = aws_cloudtrail.main.name
}

output "cloudtrail_home_region" {
  description = "Home region of the CloudTrail"
  value       = aws_cloudtrail.main.home_region
}

# =============================================================================
# S3 Bucket Outputs
# =============================================================================

output "s3_bucket_id" {
  description = "ID of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.bucket_domain_name
}

output "s3_bucket_versioning_enabled" {
  description = "Whether versioning is enabled on the S3 bucket"
  value       = aws_s3_bucket_versioning.cloudtrail.versioning_configuration[0].status == "Enabled"
}

output "s3_bucket_mfa_delete_enabled" {
  description = "Whether MFA delete is enabled on the S3 bucket"
  value       = aws_s3_bucket_versioning.cloudtrail.versioning_configuration[0].mfa_delete == "Enabled"
}

# =============================================================================
# CloudWatch Log Group Outputs
# =============================================================================

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for CloudTrail"
  value       = aws_cloudwatch_log_group.cloudtrail.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for CloudTrail"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}

# =============================================================================
# IAM Role Outputs
# =============================================================================

output "cloudtrail_cloudwatch_role_arn" {
  description = "ARN of the IAM role for CloudTrail to write to CloudWatch Logs"
  value       = aws_iam_role.cloudtrail_cloudwatch.arn
}

output "cloudtrail_cloudwatch_role_name" {
  description = "Name of the IAM role for CloudTrail to write to CloudWatch Logs"
  value       = aws_iam_role.cloudtrail_cloudwatch.name
}

# =============================================================================
# SNS Topic Outputs (for alerts)
# =============================================================================

output "cloudtrail_alerts_topic_arn" {
  description = "ARN of the SNS topic for CloudTrail alerts (null if alerts disabled)"
  value       = length(aws_sns_topic.cloudtrail_alerts) > 0 ? aws_sns_topic.cloudtrail_alerts[0].arn : null
}

output "cloudtrail_alerts_topic_name" {
  description = "Name of the SNS topic for CloudTrail alerts (null if alerts disabled)"
  value       = length(aws_sns_topic.cloudtrail_alerts) > 0 ? aws_sns_topic.cloudtrail_alerts[0].name : null
}

# =============================================================================
# Compliance Outputs
# =============================================================================

output "is_encrypted" {
  description = "Whether CloudTrail logs are encrypted with KMS"
  value       = aws_cloudtrail.main.kms_key_id != null
}

output "log_file_validation_enabled" {
  description = "Whether log file validation is enabled"
  value       = aws_cloudtrail.main.enable_log_file_validation
}

output "is_multi_region" {
  description = "Whether the trail is multi-region"
  value       = aws_cloudtrail.main.is_multi_region_trail
}

output "compliance_status" {
  description = "Compliance status summary for CloudTrail configuration"
  value = {
    kms_encryption_enabled     = aws_cloudtrail.main.kms_key_id != null
    log_file_validation        = aws_cloudtrail.main.enable_log_file_validation
    s3_versioning_enabled      = aws_s3_bucket_versioning.cloudtrail.versioning_configuration[0].status == "Enabled"
    s3_mfa_delete_enabled      = aws_s3_bucket_versioning.cloudtrail.versioning_configuration[0].mfa_delete == "Enabled"
    multi_region_trail         = aws_cloudtrail.main.is_multi_region_trail
    cloudwatch_logs_integrated = aws_cloudtrail.main.cloud_watch_logs_group_arn != null
  }
}
