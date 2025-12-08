# Monitoring Module

Centralized logging, metrics, and alerting configuration for ECS Fargate infrastructure.

## Overview

This module creates CloudWatch resources for monitoring ECS clusters and services, including:
- CloudWatch Log Groups with KMS encryption and configurable retention
- CloudWatch Alarms for CPU, memory, and task count metrics
- SNS Topics for alarm notifications
- CloudWatch Dashboards for cluster and service visualization

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 5.0.0 |

## Resources Created

- CloudWatch Log Group for cluster-level logs
- CloudWatch Log Groups for each service (per-service isolation)
- SNS Topics for critical, warning, and pipeline notifications
- CloudWatch Alarms:
  - Cluster CPU utilization
  - Cluster memory utilization
  - Per-service CPU utilization
  - Per-service memory utilization
  - Per-service running task count
- CloudWatch Dashboards:
  - Cluster overview dashboard
  - Per-service detail dashboards

## Usage

### Basic Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  project_name     = "myproject"
  environment      = "prod"
  ecs_cluster_name = module.ecs_cluster.cluster_name
  ecs_cluster_arn  = module.ecs_cluster.cluster_arn
  kms_key_arn      = module.security.kms_key_cloudwatch_arn

  # Production requires 90+ days retention for compliance
  log_retention_days = 90

  tags = var.tags
}
```

### With Services and Notifications

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  project_name     = "myproject"
  environment      = "prod"
  ecs_cluster_name = module.ecs_cluster.cluster_name
  ecs_cluster_arn  = module.ecs_cluster.cluster_arn
  kms_key_arn      = module.security.kms_key_cloudwatch_arn

  log_retention_days = 90

  # Alarm thresholds
  cpu_utilization_threshold    = 80
  memory_utilization_threshold = 80
  task_failure_threshold       = 2

  # SNS notifications
  enable_sns_notifications = true
  critical_alarm_email     = "oncall@example.com"
  warning_alarm_email      = "devops@example.com"

  # Services to monitor
  services = {
    api = {
      name          = "myproject-prod-api"
      desired_count = 3
    }
    worker = {
      name          = "myproject-prod-worker"
      desired_count = 2
    }
  }

  tags = var.tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project, used for resource naming | `string` | n/a | yes |
| environment | Environment name (develop, test, qa, prod) | `string` | n/a | yes |
| ecs_cluster_name | Name of the ECS cluster to monitor | `string` | n/a | yes |
| ecs_cluster_arn | ARN of the ECS cluster to monitor | `string` | n/a | yes |
| kms_key_arn | ARN of the KMS key for CloudWatch Logs encryption | `string` | n/a | yes |
| log_retention_days | Number of days to retain CloudWatch logs | `number` | `90` | no |
| cpu_utilization_threshold | CPU utilization percentage threshold for alarms | `number` | `80` | no |
| memory_utilization_threshold | Memory utilization percentage threshold for alarms | `number` | `80` | no |
| task_failure_threshold | Number of task failures to trigger alarm | `number` | `2` | no |
| alarm_evaluation_periods | Number of periods to evaluate for alarm | `number` | `2` | no |
| alarm_period_seconds | Period in seconds for alarm evaluation | `number` | `300` | no |
| critical_alarm_email | Email address for critical alarm notifications | `string` | `""` | no |
| warning_alarm_email | Email address for warning alarm notifications | `string` | `""` | no |
| enable_sns_notifications | Enable SNS notifications for alarms | `bool` | `true` | no |
| enable_dashboard | Enable CloudWatch dashboard creation | `bool` | `true` | no |
| dashboard_refresh_interval | Dashboard auto-refresh interval in seconds | `number` | `300` | no |
| services | Map of services to create log groups and alarms for | `map(object)` | `{}` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_log_group_name | Name of the cluster CloudWatch log group |
| cluster_log_group_arn | ARN of the cluster CloudWatch log group |
| service_log_group_names | Map of service names to their CloudWatch log group names |
| service_log_group_arns | Map of service names to their CloudWatch log group ARNs |
| critical_alarms_topic_arn | ARN of the SNS topic for critical alarms |
| warning_alarms_topic_arn | ARN of the SNS topic for warning alarms |
| pipeline_notifications_topic_arn | ARN of the SNS topic for pipeline notifications |
| sns_topics | Map of all SNS topic ARNs |
| cluster_cpu_alarm_arn | ARN of the cluster CPU utilization alarm |
| cluster_memory_alarm_arn | ARN of the cluster memory utilization alarm |
| service_cpu_alarm_arns | Map of service names to their CPU alarm ARNs |
| service_memory_alarm_arns | Map of service names to their memory alarm ARNs |
| service_task_count_alarm_arns | Map of service names to their task count alarm ARNs |
| cluster_dashboard_name | Name of the cluster CloudWatch dashboard |
| service_dashboard_names | Map of service names to their CloudWatch dashboard names |
| log_retention_days | Configured log retention period in days |
| alarm_thresholds | Configured alarm thresholds |

## Compliance

This module supports NIST and SOC-2 compliance requirements:

- **AU-2 (Audit Events)**: CloudWatch Logs capture all container logs
- **AU-9 (Protection of Audit Information)**: Logs encrypted with KMS
- **AU-11 (Audit Record Retention)**: Configurable retention (90+ days for production)
- **CC7.2 (System Monitoring)**: CloudWatch alarms and dashboards

## Log Retention Requirements

| Environment | Minimum Retention |
|-------------|-------------------|
| develop | 30 days |
| test | 30 days |
| qa | 30 days |
| prod | 90 days |

## Alarm Severity Levels

| Severity | SNS Topic | Use Case |
|----------|-----------|----------|
| Critical | critical_alarms | Task count below minimum, service failures |
| Warning | warning_alarms | High CPU/memory utilization |
| Info | pipeline_notifications | Pipeline state changes |
