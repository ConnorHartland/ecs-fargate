# ECS Task Definition Module Variables
# Input variables for ECS Fargate task definition configuration

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

variable "service_name" {
  type        = string
  description = "Name of the service for this task definition"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{2,31}$", var.service_name))
    error_message = "Service name must be 3-32 characters, start with a letter, and contain only alphanumeric characters and hyphens"
  }
}

variable "runtime" {
  type        = string
  description = "Runtime environment for the container (nodejs or python)"

  validation {
    condition     = contains(["nodejs", "python"], var.runtime)
    error_message = "Runtime must be either 'nodejs' or 'python'"
  }
}

variable "container_image" {
  type        = string
  description = "Docker image URL for the container (ECR repository URL with tag)"
}

variable "container_port" {
  type        = number
  description = "Port the container listens on"

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535"
  }
}


# =============================================================================
# Fargate CPU and Memory Configuration
# Valid combinations per AWS documentation
# =============================================================================

variable "cpu" {
  type        = number
  description = "Fargate CPU units (256, 512, 1024, 2048, 4096)"

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096"
  }
}

variable "memory" {
  type        = number
  description = "Fargate memory in MB (must be valid for the selected CPU)"

  # Memory validation is done in locals based on CPU value
}

# =============================================================================
# Environment Variables and Secrets
# =============================================================================

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables to pass to the container (non-sensitive)"
  default     = {}
}

variable "secrets_arns" {
  type = list(object({
    name       = string
    value_from = string
  }))
  description = "List of secrets from Secrets Manager to inject as environment variables"
  default     = []
}

# =============================================================================
# Health Check Configuration
# =============================================================================

variable "health_check_command" {
  type        = list(string)
  description = "Health check command for the container"
  default     = null
}

variable "health_check_interval" {
  type        = number
  description = "Health check interval in seconds"
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds"
  }
}

variable "health_check_timeout" {
  type        = number
  description = "Health check timeout in seconds"
  default     = 5

  validation {
    condition     = var.health_check_timeout >= 2 && var.health_check_timeout <= 60
    error_message = "Health check timeout must be between 2 and 60 seconds"
  }
}

variable "health_check_retries" {
  type        = number
  description = "Number of health check retries before marking unhealthy"
  default     = 3

  validation {
    condition     = var.health_check_retries >= 1 && var.health_check_retries <= 10
    error_message = "Health check retries must be between 1 and 10"
  }
}

variable "health_check_start_period" {
  type        = number
  description = "Grace period in seconds before health checks start"
  default     = 60

  validation {
    condition     = var.health_check_start_period >= 0 && var.health_check_start_period <= 300
    error_message = "Health check start period must be between 0 and 300 seconds"
  }
}

# =============================================================================
# IAM Roles
# =============================================================================

variable "task_execution_role_arn" {
  type        = string
  description = "ARN of the ECS task execution role (for pulling images, writing logs, reading secrets)"
}

variable "task_role_arn" {
  type        = string
  description = "ARN of the ECS task role (for application permissions)"
  default     = null
}

variable "create_task_role" {
  type        = bool
  description = "Whether to create a service-specific task role"
  default     = true
}

variable "task_role_policy_arns" {
  type        = list(string)
  description = "List of IAM policy ARNs to attach to the task role"
  default     = []
}

# =============================================================================
# CloudWatch Logs Configuration
# =============================================================================

variable "log_group_name" {
  type        = string
  description = "CloudWatch Log Group name for container logs"
  default     = null
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days"
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention value"
  }
}

variable "kms_key_cloudwatch_arn" {
  type        = string
  description = "ARN of KMS key for CloudWatch Logs encryption"
  default     = null
}

variable "kms_key_secrets_arn" {
  type        = string
  description = "ARN of KMS key for Secrets Manager decryption"
  default     = null
}

# =============================================================================
# AWS Configuration
# =============================================================================

variable "aws_region" {
  type        = string
  description = "AWS region for resource configuration"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID for resource ARN construction"
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
