# ECS Service Module

Reusable module for deploying individual microservices on ECS Fargate. Supports both public-facing services (with ALB integration) and internal services (with service discovery).

## Features

- ECS Fargate service with configurable desired count
- Rolling update deployment with zero-downtime configuration
- Deployment circuit breaker with automatic rollback
- Load balancer integration for public services
- AWS Cloud Map service discovery for internal services
- Capacity provider strategy (FARGATE and FARGATE_SPOT)
- Private subnet placement for security
- Application Auto Scaling with CPU and memory target tracking policies

## Usage

### Public Service (with ALB)

```hcl
module "public_service" {
  source = "./modules/ecs-service"

  environment   = "prod"
  project_name  = "myapp"
  service_name  = "api-gateway"
  service_type  = "public"

  cluster_arn         = module.ecs_cluster.cluster_arn
  cluster_name        = module.ecs_cluster.cluster_name
  task_definition_arn = module.task_definition.task_definition_arn
  container_name      = "api-gateway"
  container_port      = 3000

  desired_count                      = 2
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  private_subnet_ids = module.networking.private_subnet_ids
  security_group_ids = [module.networking.public_services_security_group_id]

  target_group_arn = module.alb.target_group_arn

  tags = var.tags
}
```

### Internal Service (with Service Discovery)

```hcl
module "internal_service" {
  source = "./modules/ecs-service"

  environment   = "prod"
  project_name  = "myapp"
  service_name  = "worker"
  service_type  = "internal"

  cluster_arn         = module.ecs_cluster.cluster_arn
  cluster_name        = module.ecs_cluster.cluster_name
  task_definition_arn = module.task_definition.task_definition_arn
  container_name      = "worker"
  container_port      = 8080

  desired_count                      = 2
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  private_subnet_ids = module.networking.private_subnet_ids
  security_group_ids = [module.networking.internal_services_security_group_id]

  enable_service_discovery       = true
  service_discovery_namespace_id = aws_service_discovery_private_dns_namespace.main.id

  tags = var.tags
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 5.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Deployment environment (develop, test, qa, prod) | `string` | n/a | yes |
| project_name | Project name used for resource naming | `string` | n/a | yes |
| service_name | Name of the service | `string` | n/a | yes |
| service_type | Type of service: 'public' or 'internal' | `string` | n/a | yes |
| cluster_arn | ARN of the ECS cluster | `string` | n/a | yes |
| cluster_name | Name of the ECS cluster | `string` | n/a | yes |
| task_definition_arn | ARN of the ECS task definition | `string` | n/a | yes |
| container_name | Name of the container in the task definition | `string` | n/a | yes |
| container_port | Port the container listens on | `number` | n/a | yes |
| private_subnet_ids | List of private subnet IDs for ECS tasks | `list(string)` | n/a | yes |
| security_group_ids | List of security group IDs for ECS tasks | `list(string)` | n/a | yes |
| desired_count | Desired number of tasks to run | `number` | `2` | no |
| deployment_minimum_healthy_percent | Minimum healthy percent during deployment | `number` | `100` | no |
| deployment_maximum_percent | Maximum percent during deployment | `number` | `200` | no |
| deployment_timeout | Timeout for ECS service deployment operations | `string` | `"15m"` | no |
| enable_circuit_breaker | Enable deployment circuit breaker | `bool` | `true` | no |
| enable_circuit_breaker_rollback | Enable automatic rollback on deployment failure | `bool` | `true` | no |
| target_group_arn | ARN of the ALB target group (for public services) | `string` | `null` | no |
| enable_service_discovery | Enable AWS Cloud Map service discovery | `bool` | `false` | no |
| service_discovery_namespace_id | ID of the Cloud Map namespace | `string` | `null` | no |
| enable_autoscaling | Enable auto-scaling for the ECS service | `bool` | `true` | no |
| autoscaling_min_capacity | Minimum number of tasks for auto-scaling | `number` | `1` | no |
| autoscaling_max_capacity | Maximum number of tasks for auto-scaling | `number` | `10` | no |
| cpu_target_value | Target CPU utilization percentage for auto-scaling | `number` | `70` | no |
| memory_target_value | Target memory utilization percentage for auto-scaling | `number` | `70` | no |
| scale_in_cooldown | Cooldown period in seconds before allowing another scale-in action | `number` | `300` | no |
| scale_out_cooldown | Cooldown period in seconds before allowing another scale-out action | `number` | `60` | no |

## Outputs

| Name | Description |
|------|-------------|
| service_id | ID of the ECS service |
| service_arn | ARN of the ECS service |
| service_name | Name of the ECS service |
| desired_count | Desired number of tasks |
| deployment_minimum_healthy_percent | Minimum healthy percent during deployment |
| deployment_maximum_percent | Maximum percent during deployment |
| deployment_timeout | Timeout for deployment operations |
| circuit_breaker_enabled | Whether deployment circuit breaker is enabled |
| circuit_breaker_rollback_enabled | Whether automatic rollback on failure is enabled |
| has_load_balancer | Whether the service has a load balancer attached |
| has_service_discovery | Whether the service has service discovery enabled |
| autoscaling_enabled | Whether auto-scaling is enabled for the service |
| autoscaling_target_id | ID of the Application Auto Scaling target |
| autoscaling_min_capacity | Minimum capacity for auto-scaling |
| autoscaling_max_capacity | Maximum capacity for auto-scaling |
| cpu_scaling_policy_arn | ARN of the CPU utilization scaling policy |
| memory_scaling_policy_arn | ARN of the memory utilization scaling policy |

## Auto Scaling

The module supports Application Auto Scaling with target tracking policies for both CPU and memory utilization. When enabled (default), the service will automatically scale between the configured minimum and maximum capacity based on resource utilization.

### Auto Scaling Example

```hcl
module "scalable_service" {
  source = "./modules/ecs-service"

  # ... other configuration ...

  # Auto Scaling Configuration
  enable_autoscaling       = true
  autoscaling_min_capacity = 2
  autoscaling_max_capacity = 20
  cpu_target_value         = 70    # Scale when CPU exceeds 70%
  memory_target_value      = 80    # Scale when memory exceeds 80%
  scale_in_cooldown        = 300   # Wait 5 minutes before scaling in
  scale_out_cooldown       = 60    # Wait 1 minute before scaling out
}
```

### Disabling Auto Scaling

To disable auto-scaling and use a fixed number of tasks:

```hcl
module "fixed_service" {
  source = "./modules/ecs-service"

  # ... other configuration ...

  enable_autoscaling = false
  desired_count      = 3  # Fixed at 3 tasks
}
```

## Zero-Downtime Deployment

The module is configured for zero-downtime deployments by default with the following settings:

- **minimum_healthy_percent = 100**: Ensures the previous version remains running during deployment
- **maximum_percent = 200**: Allows new tasks to start before old tasks are stopped
- **deployment_timeout = 15m**: Deployment operations timeout after 15 minutes
- **circuit_breaker enabled**: Automatically detects deployment failures
- **rollback enabled**: Automatically rolls back to the previous version on failure

### Deployment Configuration Example

```hcl
module "zero_downtime_service" {
  source = "./modules/ecs-service"

  # ... other configuration ...

  # Zero-downtime deployment settings (these are defaults)
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  deployment_timeout                 = "15m"
  enable_circuit_breaker             = true
  enable_circuit_breaker_rollback    = true
}
```

### How Zero-Downtime Deployment Works

1. ECS starts new tasks with the updated task definition
2. New tasks must pass health checks before receiving traffic
3. Once new tasks are healthy, old tasks are drained and stopped
4. If new tasks fail to start or pass health checks within the timeout, the circuit breaker triggers
5. On circuit breaker activation, ECS automatically rolls back to the previous task definition
