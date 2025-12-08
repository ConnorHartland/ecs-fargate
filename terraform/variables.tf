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
