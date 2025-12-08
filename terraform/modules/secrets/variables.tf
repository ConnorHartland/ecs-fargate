# Secrets Manager Module Variables
# Input variables for Secrets Manager configuration

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

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key to use for encrypting secrets"
}

variable "recovery_window_days" {
  type        = number
  description = "Number of days before secret deletion (7-30 for prod, 0 for immediate in non-prod)"
  default     = 30

  validation {
    condition     = var.recovery_window_days >= 0 && var.recovery_window_days <= 30
    error_message = "Recovery window must be between 0 and 30 days"
  }
}

variable "secrets" {
  type = map(object({
    description         = string
    secret_type         = string # database, api_key, oauth, certificate, generic
    service_name        = optional(string, "shared")
    initial_value       = map(string)
    enable_rotation     = optional(bool, false)
    rotation_lambda_arn = optional(string)
    rotation_days       = optional(number, 30)
    rotation_schedule   = optional(string)
    resource_policy     = optional(string)
  }))
  description = "Map of secrets to create with their configurations"
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.secrets : contains(["database", "api_key", "oauth", "certificate", "generic"], v.secret_type)
    ])
    error_message = "Secret type must be one of: database, api_key, oauth, certificate, generic"
  }

  validation {
    condition = alltrue([
      for k, v in var.secrets : !v.enable_rotation || v.rotation_lambda_arn != null
    ])
    error_message = "rotation_lambda_arn must be provided when enable_rotation is true"
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
