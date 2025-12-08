# AWS Config Module Variables
# Input variables for AWS Config configuration
# Requirements: 11.5

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
# =============================================================================

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for S3 bucket encryption"
}

# =============================================================================
# S3 Bucket Configuration
# =============================================================================

variable "config_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for Config delivery (optional, will be created if not provided)"
  default     = null
}

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain Config snapshots before transitioning to Glacier"
  default     = 90

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 365
    error_message = "Log retention must be between 30 and 365 days"
  }
}

# =============================================================================
# Config Recorder Configuration
# =============================================================================

variable "recording_frequency" {
  type        = string
  description = "Recording frequency for Config recorder (CONTINUOUS or DAILY)"
  default     = "CONTINUOUS"

  validation {
    condition     = contains(["CONTINUOUS", "DAILY"], var.recording_frequency)
    error_message = "Recording frequency must be CONTINUOUS or DAILY"
  }
}

variable "include_global_resources" {
  type        = bool
  description = "Whether to include global resources (IAM) in recording"
  default     = true
}

variable "resource_types" {
  type        = list(string)
  description = "List of resource types to record (empty list means all resources)"
  default     = []
}

# =============================================================================
# Config Rules Configuration
# =============================================================================

variable "enable_managed_rules" {
  type        = bool
  description = "Enable AWS managed Config rules for compliance checks"
  default     = true
}

variable "enable_ecs_rules" {
  type        = bool
  description = "Enable ECS-specific Config rules"
  default     = true
}

variable "enable_encryption_rules" {
  type        = bool
  description = "Enable encryption-related Config rules"
  default     = true
}

variable "enable_iam_rules" {
  type        = bool
  description = "Enable IAM-related Config rules"
  default     = true
}

variable "enable_vpc_rules" {
  type        = bool
  description = "Enable VPC-related Config rules"
  default     = true
}

# =============================================================================
# Config Aggregator Configuration
# =============================================================================

variable "enable_aggregator" {
  type        = bool
  description = "Enable Config aggregator for multi-account/multi-region"
  default     = false
}

variable "aggregator_account_ids" {
  type        = list(string)
  description = "List of account IDs to aggregate (for multi-account setup)"
  default     = []
}

variable "aggregator_regions" {
  type        = list(string)
  description = "List of regions to aggregate (for multi-region setup)"
  default     = []
}

# =============================================================================
# SNS Notifications
# =============================================================================

variable "enable_sns_notifications" {
  type        = bool
  description = "Enable SNS notifications for Config events"
  default     = true
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN of existing SNS topic for notifications (optional, will be created if not provided)"
  default     = null
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
