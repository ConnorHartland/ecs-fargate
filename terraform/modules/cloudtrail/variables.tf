# CloudTrail Module Variables
# Input variables for CloudTrail configuration
# Requirements: 11.1, 11.2

variable "environment" {
  type        = string
  description = "Deployment environment (develop, test, qa, prod)"

  validation {
    condition     = contains(["develop", "test", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: develop, test, qa, prod"
  }
}

variable "project_name" {
  type        = string
  description = "Project name used for resource naming"
}

variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "us-east-1"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID for resource ARN construction"
}

# =============================================================================
# KMS Configuration
# Requirements: 11.1 - Encryption enabled
# =============================================================================

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for CloudTrail and S3 encryption"
}

variable "kms_key_cloudwatch_arn" {
  type        = string
  description = "ARN of the KMS key for CloudWatch Logs encryption"
}

# =============================================================================
# S3 Bucket Configuration
# Requirements: 11.2 - Versioning and MFA delete
# =============================================================================

variable "enable_mfa_delete" {
  type        = bool
  description = "Enable MFA delete on CloudTrail S3 bucket (requires root credentials to enable)"
  default     = false # Set to false by default as it requires root credentials
}

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain CloudTrail logs before transitioning to Glacier"
  default     = 90

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 365
    error_message = "Log retention must be between 30 and 365 days"
  }
}


# =============================================================================
# CloudTrail Configuration
# Requirements: 11.1 - Log file validation
# =============================================================================

variable "is_multi_region_trail" {
  type        = bool
  description = "Whether the trail is created in all regions or just the current region"
  default     = true
}

variable "enable_s3_data_events" {
  type        = bool
  description = "Enable logging of S3 data events (increases log volume and cost)"
  default     = false
}

variable "enable_advanced_event_selectors" {
  type        = bool
  description = "Enable advanced event selectors for more granular event filtering"
  default     = false
}

variable "enable_insights" {
  type        = bool
  description = "Enable CloudTrail Insights for anomaly detection (production only)"
  default     = true
}

# =============================================================================
# CloudWatch Alerts Configuration
# =============================================================================

variable "enable_cloudtrail_alerts" {
  type        = bool
  description = "Enable CloudWatch alarms for CloudTrail security events"
  default     = true
}

variable "unauthorized_api_calls_threshold" {
  type        = number
  description = "Threshold for unauthorized API calls alarm"
  default     = 5
}

variable "iam_policy_changes_threshold" {
  type        = number
  description = "Threshold for IAM policy changes alarm"
  default     = 1
}

variable "security_group_changes_threshold" {
  type        = number
  description = "Threshold for security group changes alarm"
  default     = 5
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
