# Monitoring Module - Main Resources
# Creates CloudWatch log groups, alarms, SNS topics, and dashboards

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Environment-specific settings
  is_production = var.environment == "prod"

  # Log retention: 90 days for production (compliance), 30 days for non-production
  effective_log_retention = var.log_retention_days != null ? var.log_retention_days : (local.is_production ? 90 : 30)

  common_tags = merge(var.tags, {
    Module       = "monitoring"
    IsProduction = tostring(local.is_production)
  })
}

# =============================================================================
# CloudWatch Log Group for Cluster-level Logs
# =============================================================================

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/ecs/${local.name_prefix}-cluster"
  retention_in_days = local.effective_log_retention
  kms_key_id        = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name          = "${local.name_prefix}-cluster-logs"
    RetentionDays = tostring(local.effective_log_retention)
  })
}

# =============================================================================
# CloudWatch Log Groups for Services
# =============================================================================

resource "aws_cloudwatch_log_group" "services" {
  for_each = var.services

  name              = "/ecs/${each.value.name}"
  retention_in_days = local.effective_log_retention
  kms_key_id        = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name          = "${each.value.name}-logs"
    Service       = each.value.name
    RetentionDays = tostring(local.effective_log_retention)
  })
}

# =============================================================================
# SNS Topics for Alarm Notifications
# =============================================================================

resource "aws_sns_topic" "critical_alarms" {
  count = var.enable_sns_notifications ? 1 : 0

  name              = "${local.name_prefix}-critical-alarms"
  kms_master_key_id = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name     = "${local.name_prefix}-critical-alarms"
    Severity = "critical"
  })
}

resource "aws_sns_topic" "warning_alarms" {
  count = var.enable_sns_notifications ? 1 : 0

  name              = "${local.name_prefix}-warning-alarms"
  kms_master_key_id = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name     = "${local.name_prefix}-warning-alarms"
    Severity = "warning"
  })
}

resource "aws_sns_topic" "pipeline_notifications" {
  count = var.enable_sns_notifications ? 1 : 0

  name              = "${local.name_prefix}-pipeline-notifications"
  kms_master_key_id = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-pipeline-notifications"
  })
}

# SNS Topic Policy to allow CodeStar Notifications to publish
resource "aws_sns_topic_policy" "pipeline_notifications" {
  count = var.enable_sns_notifications ? 1 : 0

  arn = aws_sns_topic.pipeline_notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountOwner"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.pipeline_notifications[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = var.aws_account_id
          }
        }
      },
      {
        Sid    = "AllowCodeStarNotifications"
        Effect = "Allow"
        Principal = {
          Service = "codestar-notifications.amazonaws.com"
        }
        Action = [
          "SNS:Publish",
          "SNS:Subscribe"
        ]
        Resource = aws_sns_topic.pipeline_notifications[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}


# =============================================================================
# SNS Topic Subscriptions (Email)
# =============================================================================

resource "aws_sns_topic_subscription" "critical_email" {
  count = var.enable_sns_notifications && var.critical_alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.critical_alarms[0].arn
  protocol  = "email"
  endpoint  = var.critical_alarm_email
}

resource "aws_sns_topic_subscription" "warning_email" {
  count = var.enable_sns_notifications && var.warning_alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.warning_alarms[0].arn
  protocol  = "email"
  endpoint  = var.warning_alarm_email
}

# =============================================================================
# CloudWatch Alarms - Cluster Level
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "cluster_cpu_high" {
  alarm_name          = "${local.name_prefix}-cluster-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.cpu_utilization_threshold
  alarm_description   = "ECS cluster CPU utilization is above ${var.cpu_utilization_threshold}%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.warning_alarms[0].arn] : []
  ok_actions    = var.enable_sns_notifications ? [aws_sns_topic.warning_alarms[0].arn] : []

  tags = merge(local.common_tags, {
    Name     = "${local.name_prefix}-cluster-cpu-high"
    Severity = "warning"
  })
}

resource "aws_cloudwatch_metric_alarm" "cluster_memory_high" {
  alarm_name          = "${local.name_prefix}-cluster-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.memory_utilization_threshold
  alarm_description   = "ECS cluster memory utilization is above ${var.memory_utilization_threshold}%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.warning_alarms[0].arn] : []
  ok_actions    = var.enable_sns_notifications ? [aws_sns_topic.warning_alarms[0].arn] : []

  tags = merge(local.common_tags, {
    Name     = "${local.name_prefix}-cluster-memory-high"
    Severity = "warning"
  })
}

# =============================================================================
# CloudWatch Alarms - Service Level (CPU, Memory, Task Failures)
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  for_each = var.services

  alarm_name          = "${each.value.name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.cpu_utilization_threshold
  alarm_description   = "Service ${each.value.name} CPU utilization is above ${var.cpu_utilization_threshold}%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = each.value.name
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.warning_alarms[0].arn] : []
  ok_actions    = var.enable_sns_notifications ? [aws_sns_topic.warning_alarms[0].arn] : []

  tags = merge(local.common_tags, {
    Name     = "${each.value.name}-cpu-high"
    Service  = each.value.name
    Severity = "warning"
  })
}

resource "aws_cloudwatch_metric_alarm" "service_memory_high" {
  for_each = var.services

  alarm_name          = "${each.value.name}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = var.memory_utilization_threshold
  alarm_description   = "Service ${each.value.name} memory utilization is above ${var.memory_utilization_threshold}%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = each.value.name
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.warning_alarms[0].arn] : []
  ok_actions    = var.enable_sns_notifications ? [aws_sns_topic.warning_alarms[0].arn] : []

  tags = merge(local.common_tags, {
    Name     = "${each.value.name}-memory-high"
    Service  = each.value.name
    Severity = "warning"
  })
}

resource "aws_cloudwatch_metric_alarm" "service_running_task_count" {
  for_each = var.services

  alarm_name          = "${each.value.name}-task-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = var.alarm_period_seconds
  statistic           = "Average"
  threshold           = each.value.desired_count
  alarm_description   = "Service ${each.value.name} running task count is below desired count of ${each.value.desired_count}"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = each.value.name
  }

  alarm_actions = var.enable_sns_notifications ? [aws_sns_topic.critical_alarms[0].arn] : []
  ok_actions    = var.enable_sns_notifications ? [aws_sns_topic.critical_alarms[0].arn] : []

  tags = merge(local.common_tags, {
    Name     = "${each.value.name}-task-count-low"
    Service  = each.value.name
    Severity = "critical"
  })
}


# =============================================================================
# CloudWatch Dashboard - Cluster Overview
# =============================================================================

resource "aws_cloudwatch_dashboard" "cluster" {
  count = var.enable_dashboard ? 1 : 0

  dashboard_name = "${local.name_prefix}-cluster-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Cluster CPU Utilization"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, { stat = "Average" }]
          ]
          period = var.dashboard_refresh_interval
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Cluster Memory Utilization"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, { stat = "Average" }]
          ]
          period = var.dashboard_refresh_interval
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Running Task Count"
          region = data.aws_region.current.name
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, { stat = "Average" }]
          ]
          period = var.dashboard_refresh_interval
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Pending Task Count"
          region = data.aws_region.current.name
          metrics = [
            ["ECS/ContainerInsights", "PendingTaskCount", "ClusterName", var.ecs_cluster_name, { stat = "Average" }]
          ]
          period = var.dashboard_refresh_interval
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "Service Task Counts"
          region = data.aws_region.current.name
          metrics = [
            for service_key, service in var.services : [
              "ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", service.name, { stat = "Average" }
            ]
          ]
          period = var.dashboard_refresh_interval
          view   = "timeSeries"
        }
      }
    ]
  })
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_region" "current" {}

# =============================================================================
# CloudWatch Dashboard - Service Details
# =============================================================================

resource "aws_cloudwatch_dashboard" "services" {
  for_each = var.enable_dashboard ? var.services : {}

  dashboard_name = "${each.value.name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "${each.value.name} CPU Utilization"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", each.value.name, { stat = "Average" }]
          ]
          period = var.dashboard_refresh_interval
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "${each.value.name} Memory Utilization"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", each.value.name, { stat = "Average" }]
          ]
          period = var.dashboard_refresh_interval
          view   = "timeSeries"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "${each.value.name} Running Tasks"
          region = data.aws_region.current.name
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", each.value.name, { stat = "Average" }]
          ]
          period = var.dashboard_refresh_interval
          view   = "timeSeries"
          annotations = {
            horizontal = [
              {
                value = each.value.desired_count
                label = "Desired Count"
                color = "#2ca02c"
              }
            ]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "${each.value.name} Network"
          region = data.aws_region.current.name
          metrics = [
            ["ECS/ContainerInsights", "NetworkRxBytes", "ClusterName", var.ecs_cluster_name, "ServiceName", each.value.name, { stat = "Average", label = "RX Bytes" }],
            ["ECS/ContainerInsights", "NetworkTxBytes", "ClusterName", var.ecs_cluster_name, "ServiceName", each.value.name, { stat = "Average", label = "TX Bytes" }]
          ]
          period = var.dashboard_refresh_interval
          view   = "timeSeries"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title  = "${each.value.name} Recent Logs"
          region = data.aws_region.current.name
          query  = "SOURCE '/ecs/${each.value.name}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
        }
      }
    ]
  })
}
