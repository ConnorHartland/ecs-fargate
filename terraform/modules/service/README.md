# Service Module

Reusable Terraform module for deploying microservices to ECS Fargate with CI/CD pipelines.

## Overview

This module combines all components needed to deploy a microservice:
- ECR repository for container images
- ECS task definition with runtime-specific configuration
- ECS service with auto-scaling
- CI/CD pipeline (CodeBuild + CodePipeline)
- Security groups with least-privilege access
- Target group and ALB listener rule (for public services)
- Service discovery (for internal services)

## Requirements

| Requirement | Description |
|-------------|-------------|
| 1.1 | Reusable service module with service-specific parameters |
| 1.2 | Creates all required resources from single module invocation |
| 1.3 | Supports Node.js and Python runtime configurations |
| 1.4 | Supports public and internal service types |
| 1.5 | Creates ALB resources for public services |
| 1.6 | Skips ALB resources for internal services |
| 1.8 | Outputs all necessary resource identifiers |

## Usage

### Public Service (Node.js)

```hcl
module "api_service" {
  source = "./modules/service"

  service_name    = "api-gateway"
  runtime         = "nodejs"
  repository_url  = "myorg/api-gateway"
  service_type    = "public"
  container_port  = 3000
  environment     = "prod"

  cpu    = 512
  memory = 1024

  desired_count   = 2
  autoscaling_min = 2
  autoscaling_max = 10

  health_check_path = "/health"
  path_patterns     = ["/api/*"]

  # Infrastructure dependencies
  aws_account_id      = var.aws_account_id
  aws_region          = var.aws_region
  cluster_arn         = module.ecs_cluster.cluster_arn
  cluster_name        = module.ecs_cluster.cluster_name
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids

  # ALB configuration
  alb_listener_arn      = module.alb.https_listener_arn
  alb_security_group_id = module.alb.security_group_id

  # IAM roles
  task_execution_role_arn = module.security.task_execution_role_arn
  codebuild_role_arn      = module.security.codebuild_role_arn
  codepipeline_role_arn   = module.security.codepipeline_role_arn

  # KMS keys
  kms_key_arn = module.security.kms_key_arn

  # CI/CD
  codeconnections_arn = var.codeconnections_arn
  branch_pattern      = "release/*"
  pipeline_type       = "release"

  tags = var.tags
}
```

### Internal Service (Python)

```hcl
module "worker_service" {
  source = "./modules/service"

  service_name    = "data-processor"
  runtime         = "python"
  repository_url  = "myorg/data-processor"
  service_type    = "internal"
  container_port  = 8000
  environment     = "prod"

  cpu    = 1024
  memory = 2048

  desired_count   = 3
  autoscaling_min = 2
  autoscaling_max = 20

  # Kafka configuration
  kafka_brokers           = ["broker1:9092", "broker2:9092"]
  kafka_security_group_id = var.kafka_security_group_id

  # Service discovery
  enable_service_discovery       = true
  service_discovery_namespace_id = module.networking.service_discovery_namespace_id

  # Infrastructure dependencies
  aws_account_id      = var.aws_account_id
  aws_region          = var.aws_region
  cluster_arn         = module.ecs_cluster.cluster_arn
  cluster_name        = module.ecs_cluster.cluster_name
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids

  # IAM roles
  task_execution_role_arn = module.security.task_execution_role_arn
  codebuild_role_arn      = module.security.codebuild_role_arn
  codepipeline_role_arn   = module.security.codepipeline_role_arn

  # KMS keys
  kms_key_arn = module.security.kms_key_arn

  # CI/CD
  codeconnections_arn = var.codeconnections_arn
  branch_pattern      = "prod/*"
  pipeline_type       = "production"

  # Secrets
  secrets_arns = [
    {
      name       = "DATABASE_PASSWORD"
      value_from = "arn:aws:secretsmanager:us-east-1:123456789:secret:db-password"
    }
  ]

  tags = var.tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| service_name | Unique identifier for the service | `string` | n/a | yes |
| runtime | Runtime environment: 'nodejs' or 'python' | `string` | n/a | yes |
| repository_url | Bitbucket repository URL | `string` | n/a | yes |
| service_type | Type of service: 'public' or 'internal' | `string` | n/a | yes |
| container_port | Port the container listens on | `number` | n/a | yes |
| environment | Deployment environment | `string` | n/a | yes |
| cpu | Fargate CPU units | `number` | `256` | no |
| memory | Fargate memory in MB | `number` | `512` | no |
| desired_count | Desired number of tasks | `number` | `2` | no |
| autoscaling_min | Minimum tasks for auto-scaling | `number` | `1` | no |
| autoscaling_max | Maximum tasks for auto-scaling | `number` | `10` | no |
| health_check_path | Path for health checks | `string` | `/health` | no |
| secrets_arns | List of Secrets Manager ARNs | `list(object)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| service_arn | ARN of the ECS service |
| service_name | Name of the ECS service |
| ecr_repository_url | URL of the ECR repository |
| pipeline_name | Name of the CodePipeline |
| task_role_arn | ARN of the ECS task role |
| security_group_id | ID of the service security group |
| target_group_arn | ARN of the target group (public services) |
| service_discovery_arn | ARN of service discovery (internal services) |

## Service Types

### Public Services
- Exposed via Application Load Balancer
- Creates target group and listener rule
- Path-based routing support
- Health checks via ALB

### Internal Services
- No ALB integration
- Uses AWS Cloud Map for service discovery
- Communicates via Kafka or direct service calls
- Health checks via ECS

## Runtime Support

### Node.js
- Sets `NODE_ENV` based on environment
- Default health check uses `curl`
- Supports npm test in CI/CD

### Python
- Sets `PYTHON_ENV` based on environment
- Default health check uses Python urllib
- Supports pytest in CI/CD

## Security

- Tasks run in private subnets
- Security groups follow least-privilege
- Secrets injected from Secrets Manager
- All data encrypted with KMS
- ECR images scanned on push
