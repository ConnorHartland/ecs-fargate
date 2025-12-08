# Networking Module Variables
# Input variables for VPC and network infrastructure

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

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for high availability"
  }
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Enable NAT Gateway for private subnet internet access"
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "Use a single NAT Gateway instead of one per AZ (cost optimization for non-prod)"
  default     = false
}

variable "enable_vpc_flow_logs" {
  type        = bool
  description = "Enable VPC Flow Logs for network traffic analysis"
  default     = true
}

variable "flow_logs_retention_days" {
  type        = number
  description = "CloudWatch log retention in days for VPC Flow Logs"
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_logs_retention_days)
    error_message = "Flow logs retention must be a valid CloudWatch retention value"
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}

# =============================================================================
# Security Group Variables
# =============================================================================

variable "create_service_security_groups" {
  type        = bool
  description = "Whether to create security groups for ECS services"
  default     = true
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group ID of the ALB (required for public service security group)"
  default     = ""
}

variable "kafka_broker_endpoints" {
  type        = list(string)
  description = "List of Kafka broker endpoints (host:port format) for security group rules"
  default     = []
}

variable "kafka_security_group_id" {
  type        = string
  description = "Security group ID of the Kafka cluster (if using security group reference instead of CIDR)"
  default     = ""
}

variable "additional_internal_cidr_blocks" {
  type        = list(string)
  description = "Additional CIDR blocks allowed to access internal services"
  default     = []
}

# =============================================================================
# VPC Peering Variables (for cross-environment communication)
# Requirements: 10.4
# =============================================================================

variable "enable_vpc_peering" {
  type        = bool
  description = "Enable VPC peering connections to other environments"
  default     = false
}

variable "vpc_peering_connections" {
  type = list(object({
    peer_vpc_id      = string
    peer_vpc_cidr    = string
    peer_owner_id    = optional(string)
    peer_region      = optional(string)
    name             = string
    allow_remote_dns = optional(bool, true)
  }))
  description = "List of VPC peering connections to create"
  default     = []
}

variable "is_production" {
  type        = bool
  description = "Whether this is a production environment (enables stricter isolation)"
  default     = false
}

variable "production_vpc_cidr_prefix" {
  type        = string
  description = "Expected CIDR prefix for production VPCs (used for validation)"
  default     = "10.100."
}

variable "non_production_vpc_cidr_prefixes" {
  type        = list(string)
  description = "Expected CIDR prefixes for non-production VPCs (used for validation)"
  default     = ["10.0.", "10.1.", "10.2."]
}
