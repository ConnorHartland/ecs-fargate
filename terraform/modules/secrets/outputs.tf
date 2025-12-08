# Secrets Manager Module Outputs
# Exposes secret ARNs and IAM policies for use by other modules

# =============================================================================
# Secret Outputs
# =============================================================================

output "secret_arns" {
  description = "Map of secret names to their ARNs"
  value = {
    for k, v in aws_secretsmanager_secret.this : k => v.arn
  }
}

output "secret_ids" {
  description = "Map of secret names to their IDs"
  value = {
    for k, v in aws_secretsmanager_secret.this : k => v.id
  }
}

output "secret_names" {
  description = "Map of secret keys to their full names in Secrets Manager"
  value = {
    for k, v in aws_secretsmanager_secret.this : k => v.name
  }
}

# =============================================================================
# IAM Policy Outputs
# =============================================================================

output "secret_read_policy_arn" {
  description = "ARN of the IAM policy for reading all secrets"
  value       = length(aws_iam_policy.secret_read) > 0 ? aws_iam_policy.secret_read[0].arn : null
}

output "secret_read_policy_name" {
  description = "Name of the IAM policy for reading all secrets"
  value       = length(aws_iam_policy.secret_read) > 0 ? aws_iam_policy.secret_read[0].name : null
}

output "service_secret_policy_arns" {
  description = "Map of service names to their secret access policy ARNs"
  value = {
    for k, v in aws_iam_policy.service_secret : k => v.arn
  }
}

output "service_secret_policy_names" {
  description = "Map of service names to their secret access policy names"
  value = {
    for k, v in aws_iam_policy.service_secret : k => v.name
  }
}

# =============================================================================
# Rotation Status Outputs
# =============================================================================

output "secrets_with_rotation" {
  description = "List of secret names that have rotation enabled"
  value = [
    for k, v in var.secrets : k
    if v.enable_rotation && v.rotation_lambda_arn != null
  ]
}

output "rotation_configurations" {
  description = "Map of secret names to their rotation configurations"
  value = {
    for k, v in aws_secretsmanager_secret_rotation.this : k => {
      rotation_lambda_arn      = v.rotation_lambda_arn
      automatically_after_days = v.rotation_rules[0].automatically_after_days
    }
  }
}

# =============================================================================
# Convenience Outputs for ECS Task Definitions
# =============================================================================

output "secrets_for_task_definition" {
  description = "Map of secret names to ARN format suitable for ECS task definition secrets"
  value = {
    for k, v in aws_secretsmanager_secret.this : upper(replace(k, "-", "_")) => {
      name      = upper(replace(k, "-", "_"))
      valueFrom = v.arn
    }
  }
}

output "secrets_by_service" {
  description = "Map of service names to their associated secret ARNs"
  value = {
    for service in distinct([for k, v in var.secrets : v.service_name if v.service_name != null]) : service => [
      for k, v in var.secrets : aws_secretsmanager_secret.this[k].arn
      if v.service_name == service || v.service_name == "shared"
    ]
  }
}
