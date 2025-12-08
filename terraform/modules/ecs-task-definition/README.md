# ECS Task Definition Module

Creates ECS Fargate task definitions with awsvpc network mode, supporting both Node.js and Python runtimes.

## Features

- **awsvpc Network Mode**: Required for Fargate, enables direct communication between services
- **CPU/Memory Validation**: Validates Fargate-compatible CPU/memory combinations
- **Secrets Injection**: Injects secrets from AWS Secrets Manager as environment variables
- **CloudWatch Logs**: Configures container logging with encryption support
- **Health Checks**: Runtime-specific health check commands
- **Service-Specific Task Role**: Optional creation of IAM role for application permissions

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 5.0.0 |
| null | >= 3.0.0 |

## Usage

### Basic Node.js Service

```hcl
module "task_definition" {
  source = "./modules/ecs-task-definition"

  project_name    = "myproject"
  environment     = "prod"
  service_name    = "api-service"
  runtime         = "nodejs"
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/api-service:latest"
  container_port  = 3000
  cpu             = 256
  memory          = 512

  task_execution_role_arn = module.security.ecs_task_execution_role_arn
  kms_key_cloudwatch_arn  = module.security.kms_key_cloudwatch_arn

  aws_region     = "us-east-1"
  aws_account_id = "123456789012"

  tags = {
    Environment = "prod"
    Owner       = "platform-team"
  }
}
```

### Python Service with Secrets

```hcl
module "task_definition" {
  source = "./modules/ecs-task-definition"

  project_name    = "myproject"
  environment     = "prod"
  service_name    = "worker-service"
  runtime         = "python"
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/worker-service:latest"
  container_port  = 8000
  cpu             = 512
  memory          = 1024

  task_execution_role_arn = module.security.ecs_task_execution_role_arn
  kms_key_cloudwatch_arn  = module.security.kms_key_cloudwatch_arn
  kms_key_secrets_arn     = module.security.kms_key_secrets_arn

  environment_variables = {
    KAFKA_BROKERS = "broker1:9092,broker2:9092"
    LOG_LEVEL     = "INFO"
  }

  secrets_arns = [
    {
      name       = "DATABASE_PASSWORD"
      value_from = "arn:aws:secretsmanager:us-east-1:123456789012:secret:myproject-prod-db-password:password::"
    },
    {
      name       = "API_KEY"
      value_from = "arn:aws:secretsmanager:us-east-1:123456789012:secret:myproject-prod-api-key:key::"
    }
  ]

  aws_region     = "us-east-1"
  aws_account_id = "123456789012"

  tags = {
    Environment = "prod"
    Owner       = "platform-team"
  }
}
```

## Valid Fargate CPU/Memory Combinations

| CPU (units) | Memory (MB) |
|-------------|-------------|
| 256 | 512, 1024, 2048 |
| 512 | 1024, 2048, 3072, 4096 |
| 1024 | 2048, 3072, 4096, 5120, 6144, 7168, 8192 |
| 2048 | 4096-16384 (1024 increments) |
| 4096 | 8192-30720 (1024 increments) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name for resource naming | `string` | n/a | yes |
| environment | Deployment environment | `string` | n/a | yes |
| service_name | Name of the service | `string` | n/a | yes |
| runtime | Runtime environment (nodejs/python) | `string` | n/a | yes |
| container_image | Docker image URL | `string` | n/a | yes |
| container_port | Container port | `number` | n/a | yes |
| cpu | Fargate CPU units | `number` | n/a | yes |
| memory | Fargate memory (MB) | `number` | n/a | yes |
| task_execution_role_arn | Task execution role ARN | `string` | n/a | yes |
| aws_region | AWS region | `string` | n/a | yes |
| aws_account_id | AWS account ID | `string` | n/a | yes |
| environment_variables | Non-sensitive env vars | `map(string)` | `{}` | no |
| secrets_arns | Secrets to inject | `list(object)` | `[]` | no |
| health_check_command | Custom health check | `list(string)` | `null` | no |
| log_retention_days | Log retention period | `number` | `30` | no |
| create_task_role | Create service-specific task role | `bool` | `true` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| task_definition_arn | Full ARN of the task definition |
| task_definition_family | Family name of the task definition |
| task_definition_revision | Revision number |
| container_name | Name of the container |
| container_port | Container port |
| task_role_arn | ARN of the task role |
| log_group_name | CloudWatch Log Group name |
| log_group_arn | CloudWatch Log Group ARN |

## Requirements Validated

- **5.2**: Task resource limits (CPU, memory) with Fargate validation
- **5.6**: Secrets injection from Secrets Manager
- **5.8**: awsvpc network mode for Kafka communication
- **6.1**: CloudWatch Logs configuration with service-specific log groups
- **9.2**: Task role with read-only access to service-specific secrets
- **9.3**: Secrets referenced by ARN in task definition
