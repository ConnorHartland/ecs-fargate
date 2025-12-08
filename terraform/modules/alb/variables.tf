# ALB Module - Input Variables
# Defines all configurable parameters for the Application Load Balancer

# =============================================================================
# Required Variables
# =============================================================================

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "environment" {
  description = "Environment name (develop, test, qa, prod)"
  type        = string

  validation {
    condition     = contains(["develop", "test", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: develop, test, qa, prod"
  }
}

variable "vpc_id" {
  description = "ID of the VPC where the ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least 2 public subnets are required for high availability"
  }
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS listener (leave empty to disable HTTPS)"
  type        = string
  default     = ""
}

# =============================================================================
# Optional Variables - S3 Access Logs
# =============================================================================

variable "enable_access_logs" {
  description = "Enable ALB access logs to S3"
  type        = bool
  default     = true
}

variable "access_logs_bucket_name" {
  description = "Name of the S3 bucket for ALB access logs (created if not provided)"
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "Prefix for ALB access logs in S3 bucket"
  type        = string
  default     = "alb-logs"
}

variable "kms_key_s3_arn" {
  description = "ARN of the KMS key for S3 bucket encryption"
  type        = string
  default     = ""
}

# =============================================================================
# Optional Variables - ALB Configuration
# =============================================================================

variable "internal" {
  description = "Whether the ALB is internal (true) or internet-facing (false)"
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Time in seconds that the connection is allowed to be idle"
  type        = number
  default     = 60

  validation {
    condition     = var.idle_timeout >= 1 && var.idle_timeout <= 4000
    error_message = "Idle timeout must be between 1 and 4000 seconds"
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the ALB (recommended for production)"
  type        = bool
  default     = null
}

variable "drop_invalid_header_fields" {
  description = "Drop invalid header fields in HTTP requests"
  type        = bool
  default     = true
}

variable "enable_http2" {
  description = "Enable HTTP/2 support"
  type        = bool
  default     = true
}

variable "enable_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing"
  type        = bool
  default     = true
}

# =============================================================================
# Optional Variables - Security
# =============================================================================

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener (TLS 1.2 minimum recommended)"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB (default: 0.0.0.0/0 for public)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# =============================================================================
# Optional Variables - Target Groups
# =============================================================================

variable "target_groups" {
  description = "Map of target group configurations for public services"
  type = map(object({
    port                       = number
    protocol                   = optional(string, "HTTP")
    deregistration_delay       = optional(number, 30)
    slow_start                 = optional(number, 0)
    health_check_path          = string
    health_check_port          = optional(string, "traffic-port")
    health_check_protocol      = optional(string, "HTTP")
    health_check_interval      = optional(number, 30)
    health_check_timeout       = optional(number, 5)
    healthy_threshold          = optional(number, 2)
    unhealthy_threshold        = optional(number, 3)
    health_check_matcher       = optional(string, "200-299")
    stickiness_enabled         = optional(bool, false)
    stickiness_type            = optional(string, "lb_cookie")
    stickiness_cookie_duration = optional(number, 86400)
    priority                   = number
    path_patterns              = optional(list(string), [])
    host_headers               = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.target_groups : v.priority >= 1 && v.priority <= 50000
    ])
    error_message = "Target group priority must be between 1 and 50000"
  }

  validation {
    condition = alltrue([
      for k, v in var.target_groups : v.deregistration_delay >= 0 && v.deregistration_delay <= 3600
    ])
    error_message = "Deregistration delay must be between 0 and 3600 seconds"
  }

  validation {
    condition = alltrue([
      for k, v in var.target_groups : v.health_check_interval >= 5 && v.health_check_interval <= 300
    ])
    error_message = "Health check interval must be between 5 and 300 seconds"
  }

  validation {
    condition = alltrue([
      for k, v in var.target_groups : v.health_check_timeout >= 2 && v.health_check_timeout <= 120
    ])
    error_message = "Health check timeout must be between 2 and 120 seconds"
  }

  validation {
    condition = alltrue([
      for k, v in var.target_groups : v.healthy_threshold >= 2 && v.healthy_threshold <= 10
    ])
    error_message = "Healthy threshold must be between 2 and 10"
  }

  validation {
    condition = alltrue([
      for k, v in var.target_groups : v.unhealthy_threshold >= 2 && v.unhealthy_threshold <= 10
    ])
    error_message = "Unhealthy threshold must be between 2 and 10"
  }
}

# =============================================================================
# Optional Variables - Tagging
# =============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
