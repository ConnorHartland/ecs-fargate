# ECS Cluster Module Variables
# Input variables for ECS Fargate cluster configuration

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

variable "enable_container_insights" {
  type        = bool
  description = "Enable CloudWatch Container Insights for the ECS cluster"
  default     = true
}

variable "enable_execute_command_logging" {
  type        = bool
  description = "Enable execute command logging for debugging"
  default     = true
}

variable "execute_command_log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days for execute command logs"
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.execute_command_log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention value"
  }
}

variable "fargate_weight" {
  type        = number
  description = "Weight for FARGATE capacity provider in default strategy"
  default     = 70

  validation {
    condition     = var.fargate_weight >= 0 && var.fargate_weight <= 100
    error_message = "Fargate weight must be between 0 and 100"
  }
}

variable "fargate_spot_weight" {
  type        = number
  description = "Weight for FARGATE_SPOT capacity provider in default strategy"
  default     = 30

  validation {
    condition     = var.fargate_spot_weight >= 0 && var.fargate_spot_weight <= 100
    error_message = "Fargate Spot weight must be between 0 and 100"
  }
}

variable "fargate_base" {
  type        = number
  description = "Base count for FARGATE capacity provider (minimum tasks on FARGATE)"
  default     = 1

  validation {
    condition     = var.fargate_base >= 0
    error_message = "Fargate base must be 0 or greater"
  }
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of KMS key for encrypting execute command logs (optional)"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
