# ECS Service Module Variables
# Input variables for ECS Fargate service configuration

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
  description = "Name of the service"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{2,31}$", var.service_name))
    error_message = "Service name must be 3-32 characters, start with a letter, and contain only alphanumeric characters and hyphens"
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

# =============================================================================
# ECS Cluster Configuration
# =============================================================================

variable "cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster to deploy the service to"
}

variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster"
}

# =============================================================================
# Task Definition Configuration
# =============================================================================

variable "task_definition_arn" {
  type        = string
  description = "ARN of the ECS task definition to use"
}

variable "container_name" {
  type        = string
  description = "Name of the container in the task definition"
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
# Service Configuration
# =============================================================================

variable "desired_count" {
  type        = number
  description = "Desired number of tasks to run"
  default     = 2

  validation {
    condition     = var.desired_count >= 0
    error_message = "Desired count must be 0 or greater"
  }
}

variable "deployment_minimum_healthy_percent" {
  type        = number
  description = "Minimum healthy percent during deployment (100 ensures zero-downtime)"
  default     = 100

  validation {
    condition     = var.deployment_minimum_healthy_percent >= 0 && var.deployment_minimum_healthy_percent <= 200
    error_message = "Deployment minimum healthy percent must be between 0 and 200"
  }
}

variable "deployment_maximum_percent" {
  type        = number
  description = "Maximum percent during deployment"
  default     = 200

  validation {
    condition     = var.deployment_maximum_percent >= 100 && var.deployment_maximum_percent <= 400
    error_message = "Deployment maximum percent must be between 100 and 400"
  }
}

variable "enable_execute_command" {
  type        = bool
  description = "Enable ECS Exec for debugging"
  default     = false
}

variable "force_new_deployment" {
  type        = bool
  description = "Force a new deployment on each apply"
  default     = false
}

variable "wait_for_steady_state" {
  type        = bool
  description = "Wait for the service to reach a steady state"
  default     = true
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for ECS tasks"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs for ECS tasks"
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign public IP to tasks (should be false for private subnets)"
  default     = false
}

# =============================================================================
# Load Balancer Configuration (for public services)
# =============================================================================

variable "target_group_arn" {
  type        = string
  description = "ARN of the ALB target group (required for public services)"
  default     = null
}

# =============================================================================
# Service Discovery Configuration (for internal services)
# =============================================================================

variable "enable_service_discovery" {
  type        = bool
  description = "Enable AWS Cloud Map service discovery for internal services"
  default     = false
}

variable "service_discovery_namespace_id" {
  type        = string
  description = "ID of the Cloud Map namespace for service discovery"
  default     = null
}

variable "service_discovery_dns_ttl" {
  type        = number
  description = "TTL for service discovery DNS records"
  default     = 10
}

# =============================================================================
# Deployment Circuit Breaker
# =============================================================================

variable "enable_circuit_breaker" {
  type        = bool
  description = "Enable deployment circuit breaker"
  default     = true
}

variable "enable_circuit_breaker_rollback" {
  type        = bool
  description = "Enable automatic rollback on deployment failure"
  default     = true
}

# =============================================================================
# Deployment Timeout Configuration
# =============================================================================

variable "deployment_timeout" {
  type        = string
  description = "Timeout for ECS service deployment operations (e.g., '15m' for 15 minutes)"
  default     = "15m"

  validation {
    condition     = can(regex("^[0-9]+[smh]$", var.deployment_timeout))
    error_message = "Deployment timeout must be a valid duration string (e.g., '15m', '900s', '1h')"
  }
}

# =============================================================================
# Capacity Provider Strategy
# =============================================================================

variable "use_capacity_provider_strategy" {
  type        = bool
  description = "Use capacity provider strategy instead of launch type"
  default     = true
}

variable "fargate_weight" {
  type        = number
  description = "Weight for FARGATE capacity provider"
  default     = 70
}

variable "fargate_spot_weight" {
  type        = number
  description = "Weight for FARGATE_SPOT capacity provider"
  default     = 30
}

variable "fargate_base" {
  type        = number
  description = "Base count for FARGATE capacity provider"
  default     = 1
}

# =============================================================================
# Health Check Grace Period
# =============================================================================

variable "health_check_grace_period_seconds" {
  type        = number
  description = "Seconds to wait before starting health checks (for services with load balancer)"
  default     = 60

  validation {
    condition     = var.health_check_grace_period_seconds >= 0 && var.health_check_grace_period_seconds <= 2147483647
    error_message = "Health check grace period must be between 0 and 2147483647 seconds"
  }
}

# =============================================================================
# Auto Scaling Configuration
# =============================================================================

variable "enable_autoscaling" {
  type        = bool
  description = "Enable auto-scaling for the ECS service"
  default     = true
}

variable "autoscaling_min_capacity" {
  type        = number
  description = "Minimum number of tasks for auto-scaling"
  default     = 1

  validation {
    condition     = var.autoscaling_min_capacity >= 0
    error_message = "Auto-scaling minimum capacity must be 0 or greater"
  }
}

variable "autoscaling_max_capacity" {
  type        = number
  description = "Maximum number of tasks for auto-scaling"
  default     = 10

  validation {
    condition     = var.autoscaling_max_capacity >= 1
    error_message = "Auto-scaling maximum capacity must be 1 or greater"
  }
}

variable "cpu_target_value" {
  type        = number
  description = "Target CPU utilization percentage for auto-scaling"
  default     = 70

  validation {
    condition     = var.cpu_target_value >= 1 && var.cpu_target_value <= 100
    error_message = "CPU target value must be between 1 and 100"
  }
}

variable "memory_target_value" {
  type        = number
  description = "Target memory utilization percentage for auto-scaling"
  default     = 70

  validation {
    condition     = var.memory_target_value >= 1 && var.memory_target_value <= 100
    error_message = "Memory target value must be between 1 and 100"
  }
}

variable "scale_in_cooldown" {
  type        = number
  description = "Cooldown period in seconds before allowing another scale-in action"
  default     = 300

  validation {
    condition     = var.scale_in_cooldown >= 0
    error_message = "Scale-in cooldown must be 0 or greater"
  }
}

variable "scale_out_cooldown" {
  type        = number
  description = "Cooldown period in seconds before allowing another scale-out action"
  default     = 60

  validation {
    condition     = var.scale_out_cooldown >= 0
    error_message = "Scale-out cooldown must be 0 or greater"
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
