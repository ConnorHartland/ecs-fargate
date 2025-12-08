# Service Module Outputs
# Exposes all necessary resource identifiers for reference
# Requirements: 1.8

# =============================================================================
# Service Identification Outputs
# =============================================================================

output "service_arn" {
  description = "ARN of the ECS service"
  value       = module.ecs_service.service_arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.ecs_service.service_name
}

output "service_id" {
  description = "ID of the ECS service"
  value       = module.ecs_service.service_id
}

output "service_type" {
  description = "Type of service (public or internal)"
  value       = var.service_type
}

output "runtime" {
  description = "Runtime environment (nodejs or python)"
  value       = var.runtime
}

output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

# =============================================================================
# ECR Repository Outputs
# =============================================================================

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = module.ecr.repository_name
}

# =============================================================================
# CI/CD Pipeline Outputs
# =============================================================================

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = var.enable_pipeline ? module.cicd[0].pipeline_name : null
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline"
  value       = var.enable_pipeline ? module.cicd[0].pipeline_arn : null
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = var.enable_pipeline ? module.cicd[0].codebuild_project_name : null
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = var.enable_pipeline ? module.cicd[0].codebuild_project_arn : null
}

output "pipeline_type" {
  description = "Type of pipeline (feature, release, production)"
  value       = var.enable_pipeline ? module.cicd[0].pipeline_type : null
}

output "branch_pattern" {
  description = "Branch pattern configured for the pipeline"
  value       = var.enable_pipeline ? module.cicd[0].branch_pattern : null
}

# =============================================================================
# Task Definition Outputs
# =============================================================================

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = module.task_definition.task_definition_arn
}

output "task_definition_family" {
  description = "Family name of the ECS task definition"
  value       = module.task_definition.task_definition_family
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.task_definition.task_role_arn
}

output "container_name" {
  description = "Name of the container in the task definition"
  value       = module.task_definition.container_name
}

output "container_port" {
  description = "Port the container listens on"
  value       = module.task_definition.container_port
}

# =============================================================================
# Security Group Outputs
# =============================================================================

output "security_group_id" {
  description = "ID of the service security group"
  value       = aws_security_group.service.id
}

output "security_group_arn" {
  description = "ARN of the service security group"
  value       = aws_security_group.service.arn
}

# =============================================================================
# CloudWatch Logs Outputs
# =============================================================================

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for container logs"
  value       = module.task_definition.log_group_name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group for container logs"
  value       = module.task_definition.log_group_arn
}

# =============================================================================
# Load Balancer Outputs (for public services)
# =============================================================================

output "target_group_arn" {
  description = "ARN of the target group (for public services)"
  value       = var.service_type == "public" ? aws_lb_target_group.service[0].arn : null
}

output "target_group_name" {
  description = "Name of the target group (for public services)"
  value       = var.service_type == "public" ? aws_lb_target_group.service[0].name : null
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group for CloudWatch metrics (for public services)"
  value       = var.service_type == "public" ? aws_lb_target_group.service[0].arn_suffix : null
}

output "has_load_balancer" {
  description = "Whether the service has a load balancer attached"
  value       = var.service_type == "public"
}

# =============================================================================
# Service Discovery Outputs (for internal services)
# =============================================================================

output "service_discovery_arn" {
  description = "ARN of the service discovery service (for internal services)"
  value       = module.ecs_service.service_discovery_arn
}

output "service_discovery_name" {
  description = "Name of the service discovery service (for internal services)"
  value       = module.ecs_service.service_discovery_name
}

output "has_service_discovery" {
  description = "Whether the service has service discovery enabled"
  value       = module.ecs_service.has_service_discovery
}

# =============================================================================
# Auto-Scaling Outputs
# =============================================================================

output "autoscaling_enabled" {
  description = "Whether auto-scaling is enabled for the service"
  value       = module.ecs_service.autoscaling_enabled
}

output "autoscaling_min_capacity" {
  description = "Minimum capacity for auto-scaling"
  value       = module.ecs_service.autoscaling_min_capacity
}

output "autoscaling_max_capacity" {
  description = "Maximum capacity for auto-scaling"
  value       = module.ecs_service.autoscaling_max_capacity
}

output "cpu_scaling_policy_arn" {
  description = "ARN of the CPU utilization scaling policy"
  value       = module.ecs_service.cpu_scaling_policy_arn
}

output "memory_scaling_policy_arn" {
  description = "ARN of the memory utilization scaling policy"
  value       = module.ecs_service.memory_scaling_policy_arn
}

# =============================================================================
# Deployment Configuration Outputs
# =============================================================================

output "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percent during deployment"
  value       = module.ecs_service.deployment_minimum_healthy_percent
}

output "deployment_maximum_percent" {
  description = "Maximum percent during deployment"
  value       = module.ecs_service.deployment_maximum_percent
}

output "circuit_breaker_enabled" {
  description = "Whether deployment circuit breaker is enabled"
  value       = module.ecs_service.circuit_breaker_enabled
}

output "circuit_breaker_rollback_enabled" {
  description = "Whether automatic rollback on failure is enabled"
  value       = module.ecs_service.circuit_breaker_rollback_enabled
}

# =============================================================================
# Notification Outputs
# =============================================================================

output "notification_topic_arn" {
  description = "ARN of the SNS topic for pipeline notifications"
  value       = var.enable_pipeline ? module.cicd[0].notification_topic_arn : null
}

output "approval_topic_arn" {
  description = "ARN of the SNS topic for production approval notifications"
  value       = var.enable_pipeline ? module.cicd[0].approval_topic_arn : null
}

output "notifications_enabled" {
  description = "Whether pipeline notifications are enabled"
  value       = var.enable_pipeline ? module.cicd[0].notifications_enabled : false
}
