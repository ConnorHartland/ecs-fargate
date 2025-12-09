# ECS Service Module - Main Resources
# Creates ECS Fargate services with support for public (ALB) and internal (service discovery) configurations

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  service_name = "${var.service_name}-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "ecs-service"
    ServiceName = var.service_name
    ServiceType = var.service_type
    Environment = var.environment
  })

  # Determine if this is a public service (requires load balancer)
  is_public_service = var.service_type == "public"

  # Determine if this is an internal service (uses service discovery)
  is_internal_service = var.service_type == "internal"
}

# =============================================================================
# Service Discovery Service (for internal services)
# =============================================================================

resource "aws_service_discovery_service" "main" {
  count = local.is_internal_service && var.enable_service_discovery ? 1 : 0

  name = var.service_name

  dns_config {
    namespace_id = var.service_discovery_namespace_id

    dns_records {
      ttl  = var.service_discovery_dns_ttl
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    # failure_threshold is deprecated and always set to 1 by AWS
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${var.service_name}-discovery"
  })
}

# =============================================================================
# ECS Service
# =============================================================================

resource "aws_ecs_service" "main" {
  name            = local.service_name
  cluster         = var.cluster_arn
  task_definition = var.task_definition_arn
  desired_count   = var.desired_count

  # Use capacity provider strategy for Fargate
  dynamic "capacity_provider_strategy" {
    for_each = var.use_capacity_provider_strategy ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight            = var.fargate_weight
      base              = var.fargate_base
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.use_capacity_provider_strategy ? [1] : []
    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = var.fargate_spot_weight
    }
  }

  # Fall back to launch type if not using capacity provider strategy
  launch_type = var.use_capacity_provider_strategy ? null : "FARGATE"

  # Network configuration - tasks run in private subnets
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = var.assign_public_ip
  }


  # Deployment configuration for rolling updates
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  # Deployment circuit breaker for automatic rollback
  deployment_circuit_breaker {
    enable   = var.enable_circuit_breaker
    rollback = var.enable_circuit_breaker_rollback
  }

  # Load balancer configuration (only for public services)
  dynamic "load_balancer" {
    for_each = local.is_public_service && var.target_group_arn != null ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  # Service discovery configuration (only for internal services)
  dynamic "service_registries" {
    for_each = local.is_internal_service && var.enable_service_discovery ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.main[0].arn
    }
  }

  # Health check grace period (only for services with load balancer)
  health_check_grace_period_seconds = local.is_public_service && var.target_group_arn != null ? var.health_check_grace_period_seconds : null

  # Enable ECS Exec for debugging
  enable_execute_command = var.enable_execute_command

  # Force new deployment
  force_new_deployment = var.force_new_deployment

  # Wait for steady state
  wait_for_steady_state = var.wait_for_steady_state

  # Propagate tags from service to tasks
  propagate_tags = "SERVICE"

  # Enable managed tags
  enable_ecs_managed_tags = true

  tags = merge(local.common_tags, {
    Name = local.service_name
  })

  # Ensure service discovery is created before the service
  depends_on = [aws_service_discovery_service.main]

  # Deployment timeout configuration
  timeouts {
    create = var.deployment_timeout
    update = var.deployment_timeout
    delete = var.deployment_timeout
  }

  lifecycle {
    # Ignore changes to task_definition - the CI/CD pipeline manages this
    # Ignore changes to desired_count when auto-scaling is enabled
    ignore_changes = [
      task_definition,
      desired_count
    ]
  }
}

# =============================================================================
# Application Auto Scaling
# =============================================================================

# Auto Scaling Target - registers the ECS service with Application Auto Scaling
resource "aws_appautoscaling_target" "ecs_service" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.main]
}

# CPU Utilization Target Tracking Scaling Policy
resource "aws_appautoscaling_policy" "cpu_scaling" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.cpu_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }

  depends_on = [aws_appautoscaling_target.ecs_service]
}

# Memory Utilization Target Tracking Scaling Policy
resource "aws_appautoscaling_policy" "memory_scaling" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.service_name}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.memory_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }

  depends_on = [aws_appautoscaling_target.ecs_service]
}
