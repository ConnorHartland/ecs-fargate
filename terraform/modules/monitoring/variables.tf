# Monitoring Module - Input Variables

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (develop, test, qa, prod)"
  type        = string

  validation {
    condition     = contains(["develop", "test", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: develop, test, qa, prod"
  }
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster to monitor"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster to monitor"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for CloudWatch Logs encryption"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID for SNS topic policy conditions"
  type        = string
}

# =============================================================================
# Log Retention Configuration
# =============================================================================

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs. If null, uses environment defaults (prod=90, non-prod=30)"
  type        = number
  default     = null

  validation {
    condition     = var.log_retention_days == null || contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, 0], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention value"
  }
}

# =============================================================================
# Alarm Configuration
# =============================================================================

variable "cpu_utilization_threshold" {
  description = "CPU utilization percentage threshold for alarms"
  type        = number
  default     = 80

  validation {
    condition     = var.cpu_utilization_threshold > 0 && var.cpu_utilization_threshold <= 100
    error_message = "CPU utilization threshold must be between 1 and 100"
  }
}

variable "memory_utilization_threshold" {
  description = "Memory utilization percentage threshold for alarms"
  type        = number
  default     = 80

  validation {
    condition     = var.memory_utilization_threshold > 0 && var.memory_utilization_threshold <= 100
    error_message = "Memory utilization threshold must be between 1 and 100"
  }
}

variable "task_failure_threshold" {
  description = "Number of task failures in evaluation period to trigger alarm"
  type        = number
  default     = 2
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarm"
  type        = number
  default     = 2
}

variable "alarm_period_seconds" {
  description = "Period in seconds for alarm evaluation"
  type        = number
  default     = 300
}

# =============================================================================
# SNS Configuration
# =============================================================================

variable "critical_alarm_email" {
  description = "Email address for critical alarm notifications (optional)"
  type        = string
  default     = ""
}

variable "warning_alarm_email" {
  description = "Email address for warning alarm notifications (optional)"
  type        = string
  default     = ""
}

variable "enable_sns_notifications" {
  description = "Enable SNS notifications for alarms"
  type        = bool
  default     = true
}

# =============================================================================
# Dashboard Configuration
# =============================================================================

variable "enable_dashboard" {
  description = "Enable CloudWatch dashboard creation"
  type        = bool
  default     = true
}

variable "dashboard_refresh_interval" {
  description = "Dashboard auto-refresh interval in seconds"
  type        = number
  default     = 300
}

# =============================================================================
# Service Monitoring Configuration
# =============================================================================

variable "services" {
  description = "Map of services to create log groups and alarms for"
  type = map(object({
    name          = string
    desired_count = number
  }))
  default = {}
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
