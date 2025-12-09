# Service Module Variables
# Reusable module that combines ECR, Task Definition, ECS Service, CI/CD, and ALB resources
# Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8

# =============================================================================
# Required Variables
# =============================================================================

variable "service_name" {
  type        = string
  description = "Unique identifier for the service"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,31}$", var.service_name))
    error_message = "Service name must be 3-32 characters, start with a lowercase letter, and contain only lowercase letters, numbers, and hyphens"
  }
}

variable "runtime" {
  type        = string
  description = "Runtime environment: 'nodejs' or 'python'"

  validation {
    condition     = contains(["nodejs", "python"], var.runtime)
    error_message = "Runtime must be either 'nodejs' or 'python'"
  }
}

variable "repository_url" {
  type        = string
  description = "Bitbucket repository URL (e.g., 'owner/repo-name')"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$", var.repository_url))
    error_message = "Repository URL must be in format 'owner/repo-name'"
  }
}

variable "service_type" {
  type        = string
  description = "Type of service: 'public' (with ALB) or 'internal' (without ALB)"

  validation {
    condition     = contains(["public", "internal"], var.service_type)
    error_message = "Service type must be either 'public' or 'internal'"
  }
}

variable "container_port" {
  type        = number
  description = "Port the container listens on"

  validation {
    condition     = var.container_port >= 1024 && var.container_port <= 65535
    error_message = "Container port must be between 1024 and 65535"
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment: 'develop', 'test', 'qa', or 'prod'"

  validation {
    condition     = contains(["develop", "test", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: develop, test, qa, prod"
  }
}

# =============================================================================
# Fargate CPU and Memory Configuration
# =============================================================================

variable "cpu" {
  type        = number
  description = "Fargate CPU units (256, 512, 1024, 2048, 4096)"
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096"
  }
}

variable "memory" {
  type        = number
  description = "Fargate memory in MB (must be valid for the selected CPU)"
  default     = 512

  # Memory validation is done in the task definition module based on CPU value
}

# =============================================================================
# Service Scaling Configuration
# =============================================================================

variable "desired_count" {
  type        = number
  description = "Desired number of tasks to run"
  default     = 2

  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 100
    error_message = "Desired count must be between 1 and 100"
  }
}

variable "autoscaling_min" {
  type        = number
  description = "Minimum number of tasks for auto-scaling"
  default     = 1

  validation {
    condition     = var.autoscaling_min >= 1
    error_message = "Auto-scaling minimum must be at least 1"
  }
}

variable "autoscaling_max" {
  type        = number
  description = "Maximum number of tasks for auto-scaling"
  default     = 10

  validation {
    condition     = var.autoscaling_max >= 1 && var.autoscaling_max <= 100
    error_message = "Auto-scaling maximum must be between 1 and 100"
  }
}

# =============================================================================
# Health Check Configuration (for public services)
# =============================================================================

variable "health_check_path" {
  type        = string
  description = "Path for health checks (public services only)"
  default     = "/health"

  validation {
    condition     = can(regex("^/", var.health_check_path))
    error_message = "Health check path must start with '/'"
  }
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

# =============================================================================
# Secrets Configuration
# =============================================================================

variable "secrets_arns" {
  type = list(object({
    name       = string
    value_from = string
  }))
  description = "List of Secrets Manager ARNs to inject as environment variables"
  default     = []
}

# =============================================================================
# Environment Variables
# =============================================================================

variable "environment_variables" {
  type        = map(string)
  description = "Environment variables to pass to the container (non-sensitive)"
  default     = {}
}

# =============================================================================
# Kafka Configuration (for internal services)
# =============================================================================

variable "kafka_brokers" {
  type        = list(string)
  description = "List of Kafka broker endpoints"
  default     = []
}

variable "kafka_security_group_id" {
  type        = string
  description = "Security group ID for Kafka cluster access"
  default     = null
}


# =============================================================================
# Infrastructure Dependencies
# =============================================================================

variable "project_name" {
  type        = string
  description = "Project name used for resource naming"
  default     = "ecs-fargate"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID"
}

variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "us-east-1"
}

# =============================================================================
# ECS Cluster Configuration
# =============================================================================

variable "cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster"
}

variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster"
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "vpc_id" {
  type        = string
  description = "ID of the VPC"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for ECS tasks"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs for ALB (public services only)"
  default     = []
}

# =============================================================================
# ALB Configuration (for public services)
# =============================================================================

variable "alb_listener_arn" {
  type        = string
  description = "ARN of the ALB HTTPS listener (required for public services)"
  default     = null
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group ID of the ALB (required for public services)"
  default     = null
}

variable "path_patterns" {
  type        = list(string)
  description = "Path patterns for ALB routing (public services only)"
  default     = ["/*"]
}

variable "listener_rule_priority" {
  type        = number
  description = "Priority for the ALB listener rule (public services only)"
  default     = 100

  validation {
    condition     = var.listener_rule_priority >= 1 && var.listener_rule_priority <= 50000
    error_message = "Listener rule priority must be between 1 and 50000"
  }
}

variable "deregistration_delay" {
  type        = number
  description = "Deregistration delay in seconds for target group"
  default     = 30

  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "Deregistration delay must be between 0 and 3600 seconds"
  }
}

# =============================================================================
# Service Discovery Configuration (for internal services)
# =============================================================================

variable "enable_service_discovery" {
  type        = bool
  description = "Enable AWS Cloud Map service discovery for internal services"
  default     = true
}

variable "service_discovery_namespace_id" {
  type        = string
  description = "ID of the Cloud Map namespace for service discovery"
  default     = null
}

# =============================================================================
# IAM Roles
# =============================================================================

variable "task_execution_role_arn" {
  type        = string
  description = "ARN of the ECS task execution role"
}

variable "codebuild_role_arn" {
  type        = string
  description = "ARN of the IAM role for CodeBuild"
}

variable "codepipeline_role_arn" {
  type        = string
  description = "ARN of the IAM role for CodePipeline"
}

# =============================================================================
# KMS Keys
# =============================================================================

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for general encryption"
}

variable "kms_key_ecr_arn" {
  type        = string
  description = "ARN of the KMS key for ECR encryption"
  default     = null
}

variable "kms_key_cloudwatch_arn" {
  type        = string
  description = "ARN of the KMS key for CloudWatch Logs encryption"
  default     = null
}

variable "kms_key_secrets_arn" {
  type        = string
  description = "ARN of the KMS key for Secrets Manager decryption"
  default     = null
}

variable "kms_key_s3_arn" {
  type        = string
  description = "ARN of the KMS key for S3 encryption"
  default     = null
}

# =============================================================================
# CI/CD Configuration
# =============================================================================

variable "codeconnections_arn" {
  type        = string
  description = "ARN of the CodeConnections connection for Bitbucket"
}

variable "branch_pattern" {
  type        = string
  description = "Branch pattern for pipeline trigger (e.g., 'feature/*', 'release/*', 'prod/*')"
  default     = "feature/*"
}

variable "pipeline_type" {
  type        = string
  description = "Type of pipeline: 'feature' (manual trigger), 'release' (auto trigger), 'production' (manual approval)"
  default     = "feature"

  validation {
    condition     = contains(["feature", "release", "production"], var.pipeline_type)
    error_message = "Pipeline type must be one of: feature, release, production"
  }
}

variable "enable_pipeline" {
  type        = bool
  description = "Whether to create CodePipeline resources"
  default     = true
}

variable "enable_notifications" {
  type        = bool
  description = "Whether to enable SNS notifications for pipeline events"
  default     = true
}

variable "notification_sns_topic_arn" {
  type        = string
  description = "ARN of the SNS topic for pipeline notifications"
  default     = ""
}

variable "approval_sns_topic_arn" {
  type        = string
  description = "ARN of the SNS topic for production approval notifications"
  default     = ""
}

variable "notification_events" {
  type        = list(string)
  description = "List of pipeline events to send notifications for (uses module defaults if not specified)"
  default     = []
}

# =============================================================================
# Logging Configuration
# =============================================================================

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days"
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch retention value"
  }
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}


# =============================================================================
# E2E Testing Configuration
# =============================================================================

variable "enable_e2e_tests" {
  type        = bool
  description = "Whether to enable E2E testing stage after deployment"
  default     = false
}

variable "e2e_test_repository_id" {
  type        = string
  description = "Full repository ID for E2E test repo (e.g., 'owner/qa-tests')"
  default     = ""
}

variable "e2e_test_branch" {
  type        = string
  description = "Branch to use for E2E tests"
  default     = "main"
}

variable "e2e_test_buildspec" {
  type        = string
  description = "Custom buildspec content for E2E tests (optional)"
  default     = ""
}

variable "e2e_test_environment_variables" {
  type        = map(string)
  description = "Environment variables to pass to E2E tests (e.g., API_URL, ENVIRONMENT)"
  default     = {}
}

variable "e2e_test_timeout_minutes" {
  type        = number
  description = "Timeout for E2E tests in minutes"
  default     = 30
}


variable "buildspec_path" {
  type        = string
  description = "Path to custom buildspec file in service repository (relative to repo root)"
  default     = ""
}
