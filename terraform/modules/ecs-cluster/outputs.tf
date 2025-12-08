# ECS Cluster Module Outputs
# Exposes cluster information for use by other modules

# =============================================================================
# Cluster Outputs
# =============================================================================

output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

# =============================================================================
# Capacity Provider Outputs
# =============================================================================

output "capacity_providers" {
  description = "List of capacity providers associated with the cluster"
  value       = aws_ecs_cluster_capacity_providers.main.capacity_providers
}

output "default_capacity_provider_strategy" {
  description = "Default capacity provider strategy for the cluster"
  value = [
    {
      capacity_provider = "FARGATE"
      base              = var.fargate_base
      weight            = var.fargate_weight
    },
    {
      capacity_provider = "FARGATE_SPOT"
      base              = 0
      weight            = var.fargate_spot_weight
    }
  ]
}

# =============================================================================
# Logging Outputs
# =============================================================================

output "execute_command_log_group_name" {
  description = "Name of the CloudWatch Log Group for execute command logs"
  value       = var.enable_execute_command_logging ? aws_cloudwatch_log_group.execute_command[0].name : null
}

output "execute_command_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for execute command logs"
  value       = var.enable_execute_command_logging ? aws_cloudwatch_log_group.execute_command[0].arn : null
}

# =============================================================================
# Configuration Outputs
# =============================================================================

output "container_insights_enabled" {
  description = "Whether Container Insights is enabled for the cluster"
  value       = var.enable_container_insights
}

output "execute_command_logging_enabled" {
  description = "Whether execute command logging is enabled"
  value       = var.enable_execute_command_logging
}
