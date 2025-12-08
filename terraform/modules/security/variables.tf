# Security Module Variables
# Input variables for KMS keys and IAM roles

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
  description = "AWS region for resource ARN construction"
  default     = "us-east-1"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID for resource ARN construction"
}

variable "enable_key_rotation" {
  type        = bool
  description = "Enable automatic key rotation for KMS keys"
  default     = true
}

variable "key_deletion_window_days" {
  type        = number
  description = "Number of days before KMS key deletion (7-30). Production should use 30, non-production can use 7."
  default     = null # Will be set based on environment if not provided

  validation {
    condition     = var.key_deletion_window_days == null || (var.key_deletion_window_days >= 7 && var.key_deletion_window_days <= 30)
    error_message = "Key deletion window must be between 7 and 30 days"
  }
}

variable "require_mfa_for_production" {
  type        = bool
  description = "Require MFA for IAM policies accessing production resources"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
