# CI/CD Module Variables
# Input variables for CodeBuild project and CodePipeline configuration

variable "service_name" {
  type        = string
  description = "Name of the service for the CodeBuild project"

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

variable "aws_account_id" {
  type        = string
  description = "AWS account ID for resource ARN construction"
}

variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment"
  default     = "us-east-1"
}

variable "ecr_repository_url" {
  type        = string
  description = "URL of the ECR repository for Docker image storage"
}

variable "codebuild_role_arn" {
  type        = string
  description = "ARN of the IAM role for CodeBuild"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for encryption"
}

# =============================================================================
# CodePipeline Variables
# =============================================================================

variable "enable_pipeline" {
  type        = bool
  description = "Whether to create CodePipeline resources"
  default     = true
}

variable "codepipeline_role_arn" {
  type        = string
  description = "ARN of the IAM role for CodePipeline"
  default     = ""
}

variable "codeconnections_arn" {
  type        = string
  description = "ARN of the CodeConnections connection for Bitbucket"
  default     = ""
}

variable "repository_id" {
  type        = string
  description = "Full repository ID (e.g., 'owner/repo-name') for Bitbucket"
  default     = ""
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

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster for deployment"
  default     = ""
}

variable "ecs_service_name" {
  type        = string
  description = "Name of the ECS service for deployment"
  default     = ""
}

variable "s3_kms_key_arn" {
  type        = string
  description = "ARN of the KMS key for S3 artifact bucket encryption (defaults to kms_key_arn if not specified)"
  default     = ""
}


variable "build_image" {
  type        = string
  description = "Docker image for CodeBuild environment"
  default     = "aws/codebuild/standard:7.0"
}

variable "compute_type" {
  type        = string
  description = "CodeBuild compute type"
  default     = "BUILD_GENERAL1_SMALL"

  validation {
    condition     = contains(["BUILD_GENERAL1_SMALL", "BUILD_GENERAL1_MEDIUM", "BUILD_GENERAL1_LARGE", "BUILD_GENERAL1_2XLARGE"], var.compute_type)
    error_message = "Compute type must be one of: BUILD_GENERAL1_SMALL, BUILD_GENERAL1_MEDIUM, BUILD_GENERAL1_LARGE, BUILD_GENERAL1_2XLARGE"
  }
}

variable "build_timeout_minutes" {
  type        = number
  description = "Build timeout in minutes"
  default     = 30

  validation {
    condition     = var.build_timeout_minutes >= 5 && var.build_timeout_minutes <= 480
    error_message = "Build timeout must be between 5 and 480 minutes"
  }
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days"
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention value"
  }
}

variable "buildspec_path" {
  type        = string
  description = "Path to custom buildspec file (optional, uses default if empty)"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}

# =============================================================================
# SNS Notification Variables
# =============================================================================

variable "enable_notifications" {
  type        = bool
  description = "Whether to enable SNS notifications for pipeline events"
  default     = true
}

variable "notification_sns_topic_arn" {
  type        = string
  description = "ARN of the SNS topic for pipeline notifications (if empty, a new topic will be created)"
  default     = ""
}

variable "notification_events" {
  type        = list(string)
  description = "List of pipeline events to send notifications for"
  default = [
    "codepipeline-pipeline-pipeline-execution-started",
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-pipeline-execution-failed",
    "codepipeline-pipeline-pipeline-execution-canceled",
    "codepipeline-pipeline-pipeline-execution-superseded"
  ]
  # Note: Event types 'stopped' and 'resumed' are not valid for CodePipeline notification rules
}

# =============================================================================
# Production Pipeline Approval Variables
# =============================================================================

variable "approval_sns_topic_arn" {
  type        = string
  description = "ARN of the SNS topic for manual approval notifications (production pipelines only)"
  default     = ""
}

variable "approval_timeout_minutes" {
  type        = number
  description = "Timeout in minutes for manual approval (default: 7 days = 10080 minutes)"
  default     = 10080

  validation {
    condition     = var.approval_timeout_minutes >= 1 && var.approval_timeout_minutes <= 20160
    error_message = "Approval timeout must be between 1 minute and 14 days (20160 minutes)"
  }
}

variable "approval_comments" {
  type        = string
  description = "Comments to include in the approval notification"
  default     = "Please review and approve this production deployment."
}

variable "approval_external_entity_link" {
  type        = string
  description = "URL to external entity for approval review (e.g., pull request URL)"
  default     = ""
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
  description = "Branch to use for E2E tests (e.g., 'main', 'develop')"
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
