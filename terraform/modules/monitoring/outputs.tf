# Monitoring Module - Outputs

# =============================================================================
# CloudWatch Log Group Outputs
# =============================================================================

output "cluster_log_group_name" {
  description = "Name of the cluster CloudWatch log group"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "cluster_log_group_arn" {
  description = "ARN of the cluster CloudWatch log group"
  value       = aws_cloudwatch_log_group.cluster.arn
}

output "service_log_group_names" {
  description = "Map of service names to their CloudWatch log group names"
  value       = { for k, v in aws_cloudwatch_log_group.services : k => v.name }
}

output "service_log_group_arns" {
  description = "Map of service names to their CloudWatch log group ARNs"
  value       = { for k, v in aws_cloudwatch_log_group.services : k => v.arn }
}

# =============================================================================
# SNS Topic Outputs
# =============================================================================

output "critical_alarms_topic_arn" {
  description = "ARN of the SNS topic for critical alarms"
  value       = var.enable_sns_notifications ? aws_sns_topic.critical_alarms[0].arn : null
}

output "warning_alarms_topic_arn" {
  description = "ARN of the SNS topic for warning alarms"
  value       = var.enable_sns_notifications ? aws_sns_topic.warning_alarms[0].arn : null
}

output "pipeline_notifications_topic_arn" {
  description = "ARN of the SNS topic for pipeline notifications"
  value       = var.enable_sns_notifications ? aws_sns_topic.pipeline_notifications[0].arn : null
}

output "sns_topics" {
  description = "Map of all SNS topic ARNs"
  value = var.enable_sns_notifications ? {
    critical_alarms        = aws_sns_topic.critical_alarms[0].arn
    warning_alarms         = aws_sns_topic.warning_alarms[0].arn
    pipeline_notifications = aws_sns_topic.pipeline_notifications[0].arn
  } : {}
}

# =============================================================================
# CloudWatch Alarm Outputs
# =============================================================================

output "cluster_cpu_alarm_arn" {
  description = "ARN of the cluster CPU utilization alarm"
  value       = aws_cloudwatch_metric_alarm.cluster_cpu_high.arn
}

output "cluster_memory_alarm_arn" {
  description = "ARN of the cluster memory utilization alarm"
  value       = aws_cloudwatch_metric_alarm.cluster_memory_high.arn
}

output "service_cpu_alarm_arns" {
  description = "Map of service names to their CPU alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.service_cpu_high : k => v.arn }
}

output "service_memory_alarm_arns" {
  description = "Map of service names to their memory alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.service_memory_high : k => v.arn }
}

output "service_task_count_alarm_arns" {
  description = "Map of service names to their task count alarm ARNs"
  value       = { for k, v in aws_cloudwatch_metric_alarm.service_running_task_count : k => v.arn }
}

# =============================================================================
# CloudWatch Dashboard Outputs
# =============================================================================

output "cluster_dashboard_name" {
  description = "Name of the cluster CloudWatch dashboard"
  value       = var.enable_dashboard ? aws_cloudwatch_dashboard.cluster[0].dashboard_name : null
}

output "service_dashboard_names" {
  description = "Map of service names to their CloudWatch dashboard names"
  value       = { for k, v in aws_cloudwatch_dashboard.services : k => v.dashboard_name }
}

# =============================================================================
# Convenience Outputs
# =============================================================================

output "log_retention_days" {
  description = "Configured log retention period in days (input value)"
  value       = var.log_retention_days
}

output "effective_log_retention_days" {
  description = "Effective log retention period in days (after environment defaults applied)"
  value       = local.effective_log_retention
}

output "is_production" {
  description = "Whether this is a production environment"
  value       = local.is_production
}

output "alarm_thresholds" {
  description = "Configured alarm thresholds"
  value = {
    cpu_utilization    = var.cpu_utilization_threshold
    memory_utilization = var.memory_utilization_threshold
    task_failure       = var.task_failure_threshold
  }
}
