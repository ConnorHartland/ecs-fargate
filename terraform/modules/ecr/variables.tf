# ECR Module Variables
# Input variables for container registry configuration

variable "service_name" {
  type        = string
  description = "Name of the service for the ECR repository"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,31}$", var.service_name))
    error_message = "Service name must be 3-32 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens"
  }
}

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
  default     = "ecs-fargate"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for ECR encryption"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID for repository policy"
}

variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "us-east-1"
}

variable "image_tag_mutability" {
  type        = string
  description = "Image tag mutability setting (MUTABLE or IMMUTABLE)"
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Image tag mutability must be MUTABLE or IMMUTABLE"
  }
}


variable "scan_on_push" {
  type        = bool
  description = "Enable image scanning on push"
  default     = true
}

variable "untagged_image_expiry_days" {
  type        = number
  description = "Number of days before untagged images are removed"
  default     = 7

  validation {
    condition     = var.untagged_image_expiry_days >= 1 && var.untagged_image_expiry_days <= 365
    error_message = "Untagged image expiry days must be between 1 and 365"
  }
}

variable "max_tagged_images" {
  type        = number
  description = "Maximum number of tagged images to retain"
  default     = 10

  validation {
    condition     = var.max_tagged_images >= 1 && var.max_tagged_images <= 1000
    error_message = "Max tagged images must be between 1 and 1000"
  }
}

variable "ecs_task_execution_role_arn" {
  type        = string
  description = "ARN of the ECS task execution role for repository access"
}

variable "codebuild_role_arn" {
  type        = string
  description = "ARN of the CodeBuild role for repository access"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}
