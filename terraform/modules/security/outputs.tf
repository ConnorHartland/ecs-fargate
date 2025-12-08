# Security Module Outputs
# Exposes KMS keys and IAM roles for use by other modules

# =============================================================================
# KMS Key Outputs
# =============================================================================

output "kms_key_ecs_arn" {
  description = "ARN of the KMS key for ECS encryption"
  value       = aws_kms_key.ecs.arn
}

output "kms_key_ecs_id" {
  description = "ID of the KMS key for ECS encryption"
  value       = aws_kms_key.ecs.key_id
}

output "kms_key_ecs_alias" {
  description = "Alias of the KMS key for ECS encryption"
  value       = aws_kms_alias.ecs.name
}

output "kms_key_ecr_arn" {
  description = "ARN of the KMS key for ECR encryption"
  value       = aws_kms_key.ecr.arn
}

output "kms_key_ecr_id" {
  description = "ID of the KMS key for ECR encryption"
  value       = aws_kms_key.ecr.key_id
}

output "kms_key_ecr_alias" {
  description = "Alias of the KMS key for ECR encryption"
  value       = aws_kms_alias.ecr.name
}

output "kms_key_secrets_arn" {
  description = "ARN of the KMS key for Secrets Manager encryption"
  value       = aws_kms_key.secrets.arn
}

output "kms_key_secrets_id" {
  description = "ID of the KMS key for Secrets Manager encryption"
  value       = aws_kms_key.secrets.key_id
}

output "kms_key_secrets_alias" {
  description = "Alias of the KMS key for Secrets Manager encryption"
  value       = aws_kms_alias.secrets.name
}

output "kms_key_cloudwatch_arn" {
  description = "ARN of the KMS key for CloudWatch Logs encryption"
  value       = aws_kms_key.cloudwatch.arn
}

output "kms_key_cloudwatch_id" {
  description = "ID of the KMS key for CloudWatch Logs encryption"
  value       = aws_kms_key.cloudwatch.key_id
}

output "kms_key_cloudwatch_alias" {
  description = "Alias of the KMS key for CloudWatch Logs encryption"
  value       = aws_kms_alias.cloudwatch.name
}

output "kms_key_s3_arn" {
  description = "ARN of the KMS key for S3 encryption"
  value       = aws_kms_key.s3.arn
}

output "kms_key_s3_id" {
  description = "ID of the KMS key for S3 encryption"
  value       = aws_kms_key.s3.key_id
}

output "kms_key_s3_alias" {
  description = "Alias of the KMS key for S3 encryption"
  value       = aws_kms_alias.s3.name
}

# =============================================================================
# IAM Role Outputs - ECS
# =============================================================================

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.name
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_role_name" {
  description = "Name of the ECS task role"
  value       = aws_iam_role.ecs_task.name
}

# =============================================================================
# IAM Role Outputs - CI/CD
# =============================================================================

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild service role"
  value       = aws_iam_role.codebuild.arn
}

output "codebuild_role_name" {
  description = "Name of the CodeBuild service role"
  value       = aws_iam_role.codebuild.name
}

output "codepipeline_role_arn" {
  description = "ARN of the CodePipeline service role"
  value       = aws_iam_role.codepipeline.arn
}

output "codepipeline_role_name" {
  description = "Name of the CodePipeline service role"
  value       = aws_iam_role.codepipeline.name
}

# =============================================================================
# Convenience Outputs - All KMS Keys
# =============================================================================

output "kms_keys" {
  description = "Map of all KMS key ARNs by purpose"
  value = {
    ecs        = aws_kms_key.ecs.arn
    ecr        = aws_kms_key.ecr.arn
    secrets    = aws_kms_key.secrets.arn
    cloudwatch = aws_kms_key.cloudwatch.arn
    s3         = aws_kms_key.s3.arn
  }
}

# =============================================================================
# Convenience Outputs - All IAM Roles
# =============================================================================

output "iam_roles" {
  description = "Map of all IAM role ARNs by purpose"
  value = {
    ecs_task_execution = aws_iam_role.ecs_task_execution.arn
    ecs_task           = aws_iam_role.ecs_task.arn
    codebuild          = aws_iam_role.codebuild.arn
    codepipeline       = aws_iam_role.codepipeline.arn
  }
}

# =============================================================================
# Production-Specific Policy Outputs
# Requirements: 10.5, 11.3
# =============================================================================

output "production_access_policy_arn" {
  description = "ARN of the production access policy (requires MFA) - only created in production"
  value       = length(aws_iam_policy.production_access) > 0 ? aws_iam_policy.production_access[0].arn : null
}

output "production_protection_policy_arn" {
  description = "ARN of the production protection policy - only created in production"
  value       = length(aws_iam_policy.production_protection) > 0 ? aws_iam_policy.production_protection[0].arn : null
}

output "permissions_boundary_policy_arn" {
  description = "ARN of the permissions boundary policy - only created in production"
  value       = length(aws_iam_policy.permissions_boundary) > 0 ? aws_iam_policy.permissions_boundary[0].arn : null
}

# =============================================================================
# Human User Access Policy Outputs
# Requirements: 11.3
# =============================================================================

output "enforce_mfa_policy_arn" {
  description = "ARN of the MFA enforcement policy - only created in production"
  value       = length(aws_iam_policy.enforce_mfa) > 0 ? aws_iam_policy.enforce_mfa[0].arn : null
}

output "production_readonly_policy_arn" {
  description = "ARN of the production read-only policy (requires MFA) - only created in production"
  value       = length(aws_iam_policy.production_readonly) > 0 ? aws_iam_policy.production_readonly[0].arn : null
}

output "production_operator_policy_arn" {
  description = "ARN of the production operator policy (requires MFA) - only created in production"
  value       = length(aws_iam_policy.production_operator) > 0 ? aws_iam_policy.production_operator[0].arn : null
}

output "production_admin_policy_arn" {
  description = "ARN of the production admin policy (requires MFA) - only created in production"
  value       = length(aws_iam_policy.production_admin) > 0 ? aws_iam_policy.production_admin[0].arn : null
}

output "human_access_policies" {
  description = "Map of all human user access policy ARNs - only populated in production"
  value = length(aws_iam_policy.enforce_mfa) > 0 ? {
    enforce_mfa         = aws_iam_policy.enforce_mfa[0].arn
    production_readonly = aws_iam_policy.production_readonly[0].arn
    production_operator = aws_iam_policy.production_operator[0].arn
    production_admin    = aws_iam_policy.production_admin[0].arn
  } : {}
}

output "is_production" {
  description = "Whether this is a production environment"
  value       = local.is_production
}

output "effective_key_deletion_window" {
  description = "Effective KMS key deletion window in days"
  value       = local.effective_key_deletion_window
}
