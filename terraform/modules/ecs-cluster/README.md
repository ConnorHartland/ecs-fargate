# ECS Cluster Module

Creates and configures an ECS Fargate cluster with container insights, capacity providers, and execute command logging.

## Resources Created

- ECS cluster with container insights enabled
- Cluster capacity providers (FARGATE, FARGATE_SPOT)
- Default capacity provider strategy
- CloudWatch log group for execute command logs (optional)

## Features

- **Container Insights**: Enables CloudWatch Container Insights for monitoring and audit trails (Requirement 2.8)
- **Capacity Providers**: Configures both FARGATE and FARGATE_SPOT for cost optimization
- **Execute Command Logging**: Enables ECS Exec for debugging with CloudWatch logging
- **KMS Encryption**: Optional KMS encryption for execute command logs

## Usage

### Basic Usage

```hcl
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  environment  = "prod"
  project_name = "myapp"
}
```

### Production Configuration

```hcl
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  environment  = "prod"
  project_name = "myapp"

  # Container insights for monitoring
  enable_container_insights = true

  # Execute command logging for debugging
  enable_execute_command_logging     = true
  execute_command_log_retention_days = 90

  # Capacity provider strategy (favor FARGATE for production stability)
  fargate_weight      = 100
  fargate_spot_weight = 0
  fargate_base        = 2

  # KMS encryption for logs
  kms_key_arn = module.security.cloudwatch_kms_key_arn

  tags = {
    Environment = "prod"
    Owner       = "platform-team"
    CostCenter  = "infrastructure"
    Compliance  = "soc2"
  }
}
```

### Non-Production Configuration (Cost Optimized)

```hcl
module "ecs_cluster" {
  source = "./modules/ecs-cluster"

  environment  = "develop"
  project_name = "myapp"

  # Use FARGATE_SPOT for cost savings
  fargate_weight      = 70
  fargate_spot_weight = 30
  fargate_base        = 1

  # Shorter log retention for non-prod
  execute_command_log_retention_days = 30

  tags = {
    Environment = "develop"
    Owner       = "dev-team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Deployment environment (develop, test, qa, prod) | `string` | n/a | yes |
| project_name | Project name used for resource naming | `string` | n/a | yes |
| enable_container_insights | Enable CloudWatch Container Insights | `bool` | `true` | no |
| enable_execute_command_logging | Enable execute command logging for debugging | `bool` | `true` | no |
| execute_command_log_retention_days | CloudWatch log retention in days | `number` | `30` | no |
| fargate_weight | Weight for FARGATE capacity provider | `number` | `70` | no |
| fargate_spot_weight | Weight for FARGATE_SPOT capacity provider | `number` | `30` | no |
| fargate_base | Base count for FARGATE capacity provider | `number` | `1` | no |
| kms_key_arn | ARN of KMS key for encrypting logs | `string` | `null` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | ID of the ECS cluster |
| cluster_arn | ARN of the ECS cluster |
| cluster_name | Name of the ECS cluster |
| capacity_providers | List of capacity providers associated with the cluster |
| default_capacity_provider_strategy | Default capacity provider strategy |
| execute_command_log_group_name | Name of the CloudWatch Log Group for execute command logs |
| execute_command_log_group_arn | ARN of the CloudWatch Log Group for execute command logs |
| container_insights_enabled | Whether Container Insights is enabled |
| execute_command_logging_enabled | Whether execute command logging is enabled |

## Capacity Provider Strategy

The module configures a default capacity provider strategy that determines how tasks are distributed between FARGATE and FARGATE_SPOT:

- **base**: Minimum number of tasks that must run on FARGATE (default: 1)
- **fargate_weight**: Relative weight for FARGATE (default: 70)
- **fargate_spot_weight**: Relative weight for FARGATE_SPOT (default: 30)

### Recommended Strategies

| Environment | FARGATE Weight | FARGATE_SPOT Weight | Base | Notes |
|-------------|----------------|---------------------|------|-------|
| Production | 100 | 0 | 2 | Maximum stability |
| QA | 80 | 20 | 1 | Mostly stable with some cost savings |
| Test | 70 | 30 | 1 | Balanced |
| Develop | 50 | 50 | 0 | Maximum cost savings |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## Related Requirements

- **Requirement 2.8**: Container insights enabled for monitoring and audit trails
- **Requirement 5.1**: ECS cluster for running microservices
