# Root variables for ECS Fargate CI/CD Infrastructure
# These variables are used across all modules and environments

# =============================================================================
# Environment Configuration
# =============================================================================

variable "environment" {
  type        = string
  description = "Deployment environment (develop, test, qa, prod)"

  validation {
    condition     = contains(["develop", "test", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: develop, test, qa, prod"
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Project name used for resource naming"
  default     = "ecs-fargate"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block"
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones for multi-AZ deployment"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for high availability"
  }
}

# =============================================================================
# Kafka Configuration
# =============================================================================

variable "kafka_brokers" {
  type        = list(string)
  description = "List of Kafka broker endpoints for internal services"
  default     = []
}

variable "kafka_security_group_id" {
  type        = string
  description = "Security group ID for Kafka cluster (external)"
  default     = ""
}

# =============================================================================
# Security Configuration
# =============================================================================

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to access ALB (use 0.0.0.0/0 for public access)"
  default     = ["0.0.0.0/0"]
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Enable deletion protection for critical resources (recommended for production)"
  default     = true
}

# =============================================================================
# Compliance Tags
# =============================================================================

variable "mandatory_tags" {
  type = object({
    Owner      = string
    CostCenter = string
    Compliance = string
  })
  description = "Mandatory tags for compliance (NIST, SOC-2)"

  validation {
    condition     = length(var.mandatory_tags.Owner) > 0 && length(var.mandatory_tags.CostCenter) > 0 && length(var.mandatory_tags.Compliance) > 0
    error_message = "All mandatory tags (Owner, CostCenter, Compliance) must be non-empty"
  }
}

# =============================================================================
# Secrets Configuration
# =============================================================================

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
  description = "Map of secrets to create in Secrets Manager"
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.secrets : contains(["database", "api_key", "oauth", "certificate", "generic"], v.secret_type)
    ])
    error_message = "Secret type must be one of: database, api_key, oauth, certificate, generic"
  }
}

# =============================================================================
# Environment-Specific Configuration Overrides
# These variables allow overriding the default environment-specific settings
# Requirements: 10.1, 10.5
# =============================================================================

variable "log_retention_days_override" {
  type        = number
  description = "Override for CloudWatch log retention days (null uses environment defaults: prod=90, non-prod=30)"
  default     = null

  validation {
    condition     = var.log_retention_days_override == null || contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days_override)
    error_message = "Log retention must be a valid CloudWatch retention value"
  }
}

variable "enable_deletion_protection_override" {
  type        = bool
  description = "Override for deletion protection (null uses environment defaults: prod=true, non-prod=false)"
  default     = null
}

variable "kms_key_deletion_window_override" {
  type        = number
  description = "Override for KMS key deletion window in days (null uses environment defaults: prod=30, non-prod=7)"
  default     = null

  validation {
    condition     = var.kms_key_deletion_window_override == null || (var.kms_key_deletion_window_override >= 7 && var.kms_key_deletion_window_override <= 30)
    error_message = "KMS key deletion window must be between 7 and 30 days"
  }
}

variable "default_cpu_override" {
  type        = number
  description = "Override for default CPU units (null uses environment defaults: prod=512, non-prod=256)"
  default     = null

  validation {
    condition     = var.default_cpu_override == null || contains([256, 512, 1024, 2048, 4096], var.default_cpu_override)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096"
  }
}

variable "default_memory_override" {
  type        = number
  description = "Override for default memory in MB (null uses environment defaults: prod=1024, non-prod=512)"
  default     = null
}

variable "default_desired_count_override" {
  type        = number
  description = "Override for default desired task count (null uses environment defaults: prod=2, non-prod=1)"
  default     = null

  validation {
    condition     = var.default_desired_count_override == null || (var.default_desired_count_override >= 1 && var.default_desired_count_override <= 100)
    error_message = "Desired count must be between 1 and 100"
  }
}

variable "fargate_spot_enabled" {
  type        = bool
  description = "Enable Fargate Spot for non-production environments (ignored in production)"
  default     = true
}
