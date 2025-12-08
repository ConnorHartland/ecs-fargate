# ECS Service Module Outputs
# Exposes service information for use by other modules

# =============================================================================
# Service Outputs
# =============================================================================

output "service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.main.id
}

output "service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.main.id
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_service.main.cluster
}

# =============================================================================
# Configuration Outputs
# =============================================================================

output "desired_count" {
  description = "Desired number of tasks"
  value       = aws_ecs_service.main.desired_count
}

output "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percent during deployment"
  value       = var.deployment_minimum_healthy_percent
}

output "deployment_maximum_percent" {
  description = "Maximum percent during deployment"
  value       = var.deployment_maximum_percent
}

output "service_type" {
  description = "Type of service (public or internal)"
  value       = var.service_type
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

# =============================================================================
# Network Configuration Outputs
# =============================================================================

output "subnet_ids" {
  description = "Subnet IDs where tasks are deployed"
  value       = var.private_subnet_ids
}

output "security_group_ids" {
  description = "Security group IDs attached to tasks"
  value       = var.security_group_ids
}

# =============================================================================
# Load Balancer Outputs (for public services)
# =============================================================================

output "target_group_arn" {
  description = "ARN of the target group (for public services)"
  value       = var.service_type == "public" ? var.target_group_arn : null
}

output "has_load_balancer" {
  description = "Whether the service has a load balancer attached"
  value       = var.service_type == "public" && var.target_group_arn != null
}

# =============================================================================
# Service Discovery Outputs (for internal services)
# =============================================================================

output "service_discovery_arn" {
  description = "ARN of the service discovery service (for internal services)"
  value       = var.service_type == "internal" && var.enable_service_discovery ? aws_service_discovery_service.main[0].arn : null
}

output "service_discovery_id" {
  description = "ID of the service discovery service (for internal services)"
  value       = var.service_type == "internal" && var.enable_service_discovery ? aws_service_discovery_service.main[0].id : null
}

output "service_discovery_name" {
  description = "Name of the service discovery service (for internal services)"
  value       = var.service_type == "internal" && var.enable_service_discovery ? aws_service_discovery_service.main[0].name : null
}

output "has_service_discovery" {
  description = "Whether the service has service discovery enabled"
  value       = var.service_type == "internal" && var.enable_service_discovery
}

# =============================================================================
# Deployment Configuration Outputs
# =============================================================================

output "circuit_breaker_enabled" {
  description = "Whether deployment circuit breaker is enabled"
  value       = var.enable_circuit_breaker
}

output "circuit_breaker_rollback_enabled" {
  description = "Whether automatic rollback on failure is enabled"
  value       = var.enable_circuit_breaker_rollback
}

output "deployment_timeout" {
  description = "Timeout for deployment operations"
  value       = var.deployment_timeout
}

output "execute_command_enabled" {
  description = "Whether ECS Exec is enabled"
  value       = var.enable_execute_command
}

# =============================================================================
# Auto Scaling Outputs
# =============================================================================

output "autoscaling_enabled" {
  description = "Whether auto-scaling is enabled for the service"
  value       = var.enable_autoscaling
}

output "autoscaling_target_id" {
  description = "ID of the Application Auto Scaling target"
  value       = var.enable_autoscaling ? aws_appautoscaling_target.ecs_service[0].id : null
}

output "autoscaling_target_resource_id" {
  description = "Resource ID of the Application Auto Scaling target"
  value       = var.enable_autoscaling ? aws_appautoscaling_target.ecs_service[0].resource_id : null
}

output "autoscaling_min_capacity" {
  description = "Minimum capacity for auto-scaling"
  value       = var.enable_autoscaling ? var.autoscaling_min_capacity : null
}

output "autoscaling_max_capacity" {
  description = "Maximum capacity for auto-scaling"
  value       = var.enable_autoscaling ? var.autoscaling_max_capacity : null
}

output "cpu_scaling_policy_arn" {
  description = "ARN of the CPU utilization scaling policy"
  value       = var.enable_autoscaling ? aws_appautoscaling_policy.cpu_scaling[0].arn : null
}

output "cpu_scaling_policy_name" {
  description = "Name of the CPU utilization scaling policy"
  value       = var.enable_autoscaling ? aws_appautoscaling_policy.cpu_scaling[0].name : null
}

output "memory_scaling_policy_arn" {
  description = "ARN of the memory utilization scaling policy"
  value       = var.enable_autoscaling ? aws_appautoscaling_policy.memory_scaling[0].arn : null
}

output "memory_scaling_policy_name" {
  description = "Name of the memory utilization scaling policy"
  value       = var.enable_autoscaling ? aws_appautoscaling_policy.memory_scaling[0].name : null
}
