# ECS Cluster Module - Main Resources
# Creates ECS Fargate cluster with container insights and capacity providers

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.tags, {
    Module = "ecs-cluster"
  })
}

# =============================================================================
# CloudWatch Log Group for Execute Command Logging
# =============================================================================

resource "aws_cloudwatch_log_group" "execute_command" {
  count = var.enable_execute_command_logging ? 1 : 0

  name              = "/ecs/${local.name_prefix}-cluster/execute-command"
  retention_in_days = var.execute_command_log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecs-execute-command-logs"
  })
}

# =============================================================================
# ECS Cluster
# =============================================================================

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  # Execute command configuration for debugging
  dynamic "configuration" {
    for_each = var.enable_execute_command_logging ? [1] : []
    content {
      execute_command_configuration {
        logging    = "OVERRIDE"
        kms_key_id = var.kms_key_arn

        log_configuration {
          cloud_watch_log_group_name     = aws_cloudwatch_log_group.execute_command[0].name
          cloud_watch_encryption_enabled = var.kms_key_arn != null
        }
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cluster"
  })
}

# =============================================================================
# Capacity Providers
# =============================================================================

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = var.fargate_base
    weight            = var.fargate_weight
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    weight            = var.fargate_spot_weight
    capacity_provider = "FARGATE_SPOT"
  }
}
