# ECS Task Definition Module Outputs
# Exposes task definition information for use by other modules

# =============================================================================
# Task Definition Outputs
# =============================================================================

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.main.arn
}

output "task_definition_arn_without_revision" {
  description = "ARN of the ECS task definition without revision number"
  value       = replace(aws_ecs_task_definition.main.arn, "/:\\d+$/", "")
}

output "task_definition_family" {
  description = "Family name of the ECS task definition"
  value       = aws_ecs_task_definition.main.family
}

output "task_definition_revision" {
  description = "Revision number of the ECS task definition"
  value       = aws_ecs_task_definition.main.revision
}

# =============================================================================
# Container Configuration Outputs
# =============================================================================

output "container_name" {
  description = "Name of the container in the task definition"
  value       = var.service_name
}

output "container_port" {
  description = "Port the container listens on"
  value       = var.container_port
}

output "cpu" {
  description = "CPU units allocated to the task"
  value       = var.cpu
}

output "memory" {
  description = "Memory (MB) allocated to the task"
  value       = var.memory
}

output "network_mode" {
  description = "Network mode of the task definition"
  value       = aws_ecs_task_definition.main.network_mode
}

# =============================================================================
# IAM Role Outputs
# =============================================================================

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = var.task_role_arn != null ? var.task_role_arn : (var.create_task_role ? aws_iam_role.task[0].arn : null)
}

output "task_role_name" {
  description = "Name of the ECS task role"
  value       = var.create_task_role && var.task_role_arn == null ? aws_iam_role.task[0].name : null
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = var.task_execution_role_arn
}

# =============================================================================
# CloudWatch Logs Outputs
# =============================================================================

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for container logs"
  value       = aws_cloudwatch_log_group.container.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group for container logs"
  value       = aws_cloudwatch_log_group.container.arn
}

# =============================================================================
# Configuration Outputs
# =============================================================================

output "runtime" {
  description = "Runtime environment (nodejs or python)"
  value       = var.runtime
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "service_name" {
  description = "Name of the service"
  value       = var.service_name
}

output "secrets_configured" {
  description = "Whether secrets are configured for this task"
  value       = length(var.secrets_arns) > 0
}

output "health_check_configured" {
  description = "Whether health check is configured for this task"
  value       = true
}
