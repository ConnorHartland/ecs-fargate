# Root outputs for ECS Fargate CI/CD Infrastructure
# These outputs expose key resource identifiers for reference

# =============================================================================
# Account and Region Information
# =============================================================================

output "aws_account_id" {
  description = "AWS account ID where resources are deployed"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = data.aws_region.current.name
}

output "environment" {
  description = "Current deployment environment"
  value       = var.environment
}

# =============================================================================
# Networking Outputs (populated when networking module is implemented)
# =============================================================================

# output "vpc_id" {
#   description = "VPC ID"
#   value       = module.networking.vpc_id
# }

# output "private_subnet_ids" {
#   description = "List of private subnet IDs for ECS tasks"
#   value       = module.networking.private_subnet_ids
# }

# output "public_subnet_ids" {
#   description = "List of public subnet IDs for ALB"
#   value       = module.networking.public_subnet_ids
# }

# =============================================================================
# ECS Cluster Outputs (populated when ECS cluster module is implemented)
# =============================================================================

# output "ecs_cluster_arn" {
#   description = "ECS cluster ARN"
#   value       = module.ecs_cluster.cluster_arn
# }

# output "ecs_cluster_name" {
#   description = "ECS cluster name"
#   value       = module.ecs_cluster.cluster_name
# }

# =============================================================================
# Security Outputs
# =============================================================================

output "kms_key_arns" {
  description = "Map of KMS key ARNs by purpose"
  value       = module.security.kms_keys
}

output "iam_role_arns" {
  description = "Map of IAM role ARNs by purpose"
  value       = module.security.iam_roles
}

# =============================================================================
# Secrets Manager Outputs
# =============================================================================

output "secret_arns" {
  description = "Map of secret names to their ARNs"
  value       = module.secrets.secret_arns
}

output "secret_names" {
  description = "Map of secret keys to their full names in Secrets Manager"
  value       = module.secrets.secret_names
}

output "secret_read_policy_arn" {
  description = "ARN of the IAM policy for reading all secrets"
  value       = module.secrets.secret_read_policy_arn
}

output "service_secret_policy_arns" {
  description = "Map of service names to their secret access policy ARNs"
  value       = module.secrets.service_secret_policy_arns
}

output "secrets_with_rotation" {
  description = "List of secret names that have rotation enabled"
  value       = module.secrets.secrets_with_rotation
}

# =============================================================================
# ALB Outputs (populated when ALB module is implemented)
# =============================================================================

# output "alb_arn" {
#   description = "Application Load Balancer ARN"
#   value       = module.alb.alb_arn
# }

# output "alb_dns_name" {
#   description = "Application Load Balancer DNS name"
#   value       = module.alb.alb_dns_name
# }

# =============================================================================
# Service Outputs (populated when services are deployed)
# =============================================================================

# output "services" {
#   description = "Map of deployed services with their details"
#   value = {
#     for name, service in module.services : name => {
#       service_arn        = service.service_arn
#       ecr_repository_url = service.ecr_repository_url
#       pipeline_name      = service.pipeline_name
#       task_role_arn      = service.task_role_arn
#       security_group_id  = service.security_group_id
#     }
#   }
# }

# =============================================================================
# Environment-Specific Configuration Outputs
# Requirements: 10.1, 10.5
# =============================================================================

output "environment_config" {
  description = "Environment-specific configuration settings"
  value       = local.environment_config
}

output "is_production" {
  description = "Whether this is a production environment"
  value       = local.is_production
}

output "effective_log_retention_days" {
  description = "Effective CloudWatch log retention in days"
  value       = local.log_retention_days
}

output "effective_deletion_protection" {
  description = "Whether deletion protection is enabled"
  value       = local.enable_deletion_protection
}

output "effective_kms_key_deletion_window" {
  description = "Effective KMS key deletion window in days"
  value       = local.kms_key_deletion_window
}

output "effective_capacity_provider_strategy" {
  description = "Effective Fargate capacity provider weights"
  value = {
    fargate_weight      = local.fargate_weight
    fargate_spot_weight = local.fargate_spot_weight
  }
}

output "production_iam_policies" {
  description = "Production-specific IAM policy ARNs (only populated in production)"
  value = local.is_production ? {
    production_access_policy     = module.security.production_access_policy_arn
    production_protection_policy = module.security.production_protection_policy_arn
    permissions_boundary_policy  = module.security.permissions_boundary_policy_arn
  } : null
}
