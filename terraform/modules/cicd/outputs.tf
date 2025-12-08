# CI/CD Module Outputs
# Exposes CodeBuild project and CodePipeline information for use by other modules

# =============================================================================
# CodeBuild Project Outputs
# =============================================================================

output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.this.name
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = aws_codebuild_project.this.arn
}

output "codebuild_project_id" {
  description = "ID of the CodeBuild project"
  value       = aws_codebuild_project.this.id
}

output "codebuild_badge_url" {
  description = "URL of the build badge (if enabled)"
  value       = aws_codebuild_project.this.badge_url
}

# =============================================================================
# S3 Cache Bucket Outputs
# =============================================================================

output "cache_bucket_name" {
  description = "Name of the S3 bucket for Docker layer caching"
  value       = aws_s3_bucket.cache.bucket
}

output "cache_bucket_arn" {
  description = "ARN of the S3 bucket for Docker layer caching"
  value       = aws_s3_bucket.cache.arn
}

# =============================================================================
# S3 Artifact Bucket Outputs
# =============================================================================

output "artifact_bucket_name" {
  description = "Name of the S3 bucket for pipeline artifacts"
  value       = var.enable_pipeline ? aws_s3_bucket.artifacts[0].bucket : ""
}

output "artifact_bucket_arn" {
  description = "ARN of the S3 bucket for pipeline artifacts"
  value       = var.enable_pipeline ? aws_s3_bucket.artifacts[0].arn : ""
}

# =============================================================================
# CodePipeline Outputs
# =============================================================================

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = var.enable_pipeline ? (var.pipeline_type == "production" ? aws_codepipeline.production[0].name : aws_codepipeline.this[0].name) : ""
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = var.enable_pipeline ? (var.pipeline_type == "production" ? aws_codepipeline.production[0].arn : aws_codepipeline.this[0].arn) : ""
}

output "pipeline_id" {
  description = "ID of the CodePipeline"
  value       = var.enable_pipeline ? (var.pipeline_type == "production" ? aws_codepipeline.production[0].id : aws_codepipeline.this[0].id) : ""
}

output "pipeline_type" {
  description = "Type of pipeline (feature, release, production)"
  value       = var.pipeline_type
}

output "branch_pattern" {
  description = "Branch pattern configured for the pipeline"
  value       = var.branch_pattern
}

output "detect_changes" {
  description = "Whether the pipeline automatically detects changes (webhook enabled)"
  value       = var.pipeline_type == "release"
}

output "requires_approval" {
  description = "Whether the pipeline requires manual approval before deployment"
  value       = var.pipeline_type == "production"
}

# =============================================================================
# CloudWatch Log Group Outputs
# =============================================================================

output "log_group_name" {
  description = "Name of the CloudWatch log group for CodeBuild"
  value       = aws_cloudwatch_log_group.codebuild.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group for CodeBuild"
  value       = aws_cloudwatch_log_group.codebuild.arn
}

# =============================================================================
# Environment Configuration Outputs
# =============================================================================

output "build_image" {
  description = "Docker image used for CodeBuild environment"
  value       = var.build_image
}

output "compute_type" {
  description = "Compute type used for CodeBuild"
  value       = var.compute_type
}

output "privileged_mode" {
  description = "Whether privileged mode is enabled for Docker builds"
  value       = true
}

output "environment_variables" {
  description = "Environment variables configured for CodeBuild"
  value = {
    AWS_ACCOUNT_ID     = var.aws_account_id
    AWS_DEFAULT_REGION = var.aws_region
    ECR_REPOSITORY_URL = var.ecr_repository_url
    ENVIRONMENT        = var.environment
    CONTAINER_NAME     = var.service_name
  }
}

# =============================================================================
# SNS Notification Outputs
# =============================================================================

output "notification_topic_arn" {
  description = "ARN of the SNS topic for pipeline notifications"
  value       = var.enable_pipeline && var.enable_notifications ? (var.notification_sns_topic_arn != "" ? var.notification_sns_topic_arn : (length(aws_sns_topic.pipeline_notifications) > 0 ? aws_sns_topic.pipeline_notifications[0].arn : "")) : ""
}

output "notification_topic_name" {
  description = "Name of the SNS topic for pipeline notifications"
  value       = var.enable_pipeline && var.enable_notifications && var.notification_sns_topic_arn == "" && length(aws_sns_topic.pipeline_notifications) > 0 ? aws_sns_topic.pipeline_notifications[0].name : ""
}

output "notification_rule_arn" {
  description = "ARN of the CodeStar notification rule"
  value       = var.enable_pipeline && var.enable_notifications ? (var.pipeline_type == "production" && length(aws_codestarnotifications_notification_rule.production_pipeline) > 0 ? aws_codestarnotifications_notification_rule.production_pipeline[0].arn : (length(aws_codestarnotifications_notification_rule.pipeline) > 0 ? aws_codestarnotifications_notification_rule.pipeline[0].arn : "")) : ""
}

output "notifications_enabled" {
  description = "Whether pipeline notifications are enabled"
  value       = var.enable_pipeline && var.enable_notifications
}

# =============================================================================
# Production Approval Outputs
# =============================================================================

output "approval_topic_arn" {
  description = "ARN of the SNS topic for production approval notifications"
  value       = var.enable_pipeline && var.pipeline_type == "production" ? (var.approval_sns_topic_arn != "" ? var.approval_sns_topic_arn : (length(aws_sns_topic.approval_notifications) > 0 ? aws_sns_topic.approval_notifications[0].arn : "")) : ""
}

output "approval_topic_name" {
  description = "Name of the SNS topic for production approval notifications"
  value       = var.enable_pipeline && var.pipeline_type == "production" && var.approval_sns_topic_arn == "" && length(aws_sns_topic.approval_notifications) > 0 ? aws_sns_topic.approval_notifications[0].name : ""
}

output "approval_timeout_minutes" {
  description = "Timeout in minutes for manual approval"
  value       = var.pipeline_type == "production" ? var.approval_timeout_minutes : 0
}
