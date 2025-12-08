# CI/CD Module

Creates CodeBuild project and CodePipeline for building Docker images with automated CI/CD capabilities.

## Resources Created

- CodeBuild project with Ubuntu standard image
- CodePipeline with source, build, and deploy stages (optional)
- S3 bucket for Docker layer caching
- S3 bucket for pipeline artifacts (when pipeline enabled)
- CloudWatch log group for build logs

## Features

- **Privileged Mode**: Enabled for Docker-in-Docker builds
- **Docker Layer Caching**: S3-based caching for faster builds
- **KMS Encryption**: All resources encrypted with customer-managed keys
- **Environment Variables**: Pre-configured for ECR integration
- **Default Buildspec**: Includes ECR login, build, scan, and push phases
- **CodePipeline Integration**: Full CI/CD pipeline with CodeConnections for Bitbucket
- **Pipeline Types**: Support for feature (manual), release (auto), and production (approval) pipelines

## Usage

### CodeBuild Only

```hcl
module "cicd" {
  source = "./modules/cicd"

  service_name       = "my-service"
  environment        = "develop"
  project_name       = "ecs-fargate"
  aws_account_id     = "123456789012"
  aws_region         = "us-east-1"
  ecr_repository_url = module.ecr.repository_url
  codebuild_role_arn = module.security.codebuild_role_arn
  kms_key_arn        = module.security.kms_key_cloudwatch_arn

  enable_pipeline = false

  tags = {
    Environment = "develop"
    Owner       = "platform-team"
  }
}
```

### Full Pipeline (Feature Branch - Manual Trigger)

```hcl
module "cicd" {
  source = "./modules/cicd"

  service_name       = "my-service"
  environment        = "develop"
  project_name       = "ecs-fargate"
  aws_account_id     = "123456789012"
  aws_region         = "us-east-1"
  ecr_repository_url = module.ecr.repository_url
  codebuild_role_arn = module.security.codebuild_role_arn
  kms_key_arn        = module.security.kms_key_cloudwatch_arn

  # Pipeline configuration
  enable_pipeline       = true
  codepipeline_role_arn = module.security.codepipeline_role_arn
  codeconnections_arn   = "arn:aws:codeconnections:us-east-1:123456789012:connection/abc123"
  repository_id         = "myorg/my-service"
  branch_pattern        = "feature/my-feature"
  pipeline_type         = "feature"  # Manual trigger (no webhook)
  ecs_cluster_name      = module.ecs_cluster.cluster_name
  ecs_service_name      = module.ecs_service.service_name
  s3_kms_key_arn        = module.security.kms_key_s3_arn

  tags = {
    Environment = "develop"
    Owner       = "platform-team"
  }
}
```

### Release Branch Pipeline (Automatic Trigger with Notifications)

```hcl
module "cicd_release" {
  source = "./modules/cicd"

  service_name       = "my-service"
  environment        = "test"  # or "qa"
  project_name       = "ecs-fargate"
  aws_account_id     = "123456789012"
  aws_region         = "us-east-1"
  ecr_repository_url = module.ecr.repository_url
  codebuild_role_arn = module.security.codebuild_role_arn
  kms_key_arn        = module.security.kms_key_cloudwatch_arn

  # Pipeline configuration for release branches
  enable_pipeline       = true
  codepipeline_role_arn = module.security.codepipeline_role_arn
  codeconnections_arn   = "arn:aws:codeconnections:us-east-1:123456789012:connection/abc123"
  repository_id         = "myorg/my-service"
  branch_pattern        = "release/1.0.0"  # Specific release branch
  pipeline_type         = "release"  # Automatic trigger (webhook enabled)
  ecs_cluster_name      = module.ecs_cluster.cluster_name
  ecs_service_name      = module.ecs_service.service_name
  s3_kms_key_arn        = module.security.kms_key_s3_arn

  # SNS Notifications for pipeline events
  enable_notifications = true
  # Optionally use existing SNS topic:
  # notification_sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:my-topic"

  tags = {
    Environment = "test"
    Owner       = "platform-team"
  }
}
```

### Production Pipeline (Manual Approval Required)

```hcl
module "cicd_production" {
  source = "./modules/cicd"

  service_name       = "my-service"
  environment        = "prod"
  project_name       = "ecs-fargate"
  aws_account_id     = "123456789012"
  aws_region         = "us-east-1"
  ecr_repository_url = module.ecr.repository_url
  codebuild_role_arn = module.security.codebuild_role_arn
  kms_key_arn        = module.security.kms_key_cloudwatch_arn

  # Pipeline configuration for production branches
  enable_pipeline       = true
  codepipeline_role_arn = module.security.codepipeline_role_arn
  codeconnections_arn   = "arn:aws:codeconnections:us-east-1:123456789012:connection/abc123"
  repository_id         = "myorg/my-service"
  branch_pattern        = "prod/main"  # Production branch
  pipeline_type         = "production"  # Requires manual approval
  ecs_cluster_name      = module.ecs_cluster.cluster_name
  ecs_service_name      = module.ecs_service.service_name
  s3_kms_key_arn        = module.security.kms_key_s3_arn

  # Approval configuration (7 days timeout by default)
  approval_timeout_minutes = 10080  # 7 days
  approval_comments        = "Please review and approve this production deployment."
  # Optionally use existing SNS topic for approval notifications:
  # approval_sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:prod-approvals"

  # SNS Notifications for pipeline events (includes approval events)
  enable_notifications = true

  tags = {
    Environment = "prod"
    Owner       = "platform-team"
  }
}
```

## Pipeline Types

| Type | Trigger | Approval | Use Case |
|------|---------|----------|----------|
| `feature` | Manual (DetectChanges=false) | No | Feature branches deploying to develop environment |
| `release` | Automatic (DetectChanges=true) | No | Release branches deploying to test/QA environments |
| `production` | Manual (DetectChanges=false) | Yes (7 days timeout) | Production deployments with approval gate |

## Production Pipeline Stages

The production pipeline includes four stages:

1. **Source**: Pulls code from Bitbucket prod/* branch via CodeConnections
2. **Build**: Builds Docker image, runs security scan, pushes to ECR
3. **Approval**: Manual approval stage with SNS notification (7 day timeout)
4. **Deploy**: Deploys to production ECS service with 15 minute timeout

## Environment Variables

The CodeBuild project is pre-configured with the following environment variables:

| Variable | Description |
|----------|-------------|
| `AWS_ACCOUNT_ID` | AWS account ID for ECR authentication |
| `AWS_DEFAULT_REGION` | AWS region for ECR |
| `ECR_REPOSITORY_URL` | Full URL of the ECR repository |
| `IMAGE_TAG` | Default image tag (overridden during build) |
| `ENVIRONMENT` | Deployment environment name |
| `CONTAINER_NAME` | Name of the container for ECS |

## Default Buildspec

The module includes a default buildspec that:

1. **Pre-build**: Authenticates with ECR
2. **Build**: Builds Docker image and runs security scan (trivy)
3. **Post-build**: Pushes images with multiple tags (latest, commit SHA, environment-tagged)
4. **Artifacts**: Generates `imagedefinitions.json` for ECS deployment

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| service_name | Name of the service | string | - | yes |
| environment | Deployment environment | string | - | yes |
| aws_account_id | AWS account ID | string | - | yes |
| ecr_repository_url | ECR repository URL | string | - | yes |
| codebuild_role_arn | IAM role ARN for CodeBuild | string | - | yes |
| kms_key_arn | KMS key ARN for encryption | string | - | yes |
| project_name | Project name prefix | string | "ecs-fargate" | no |
| aws_region | AWS region | string | "us-east-1" | no |
| build_image | CodeBuild Docker image | string | "aws/codebuild/standard:7.0" | no |
| compute_type | CodeBuild compute type | string | "BUILD_GENERAL1_SMALL" | no |
| build_timeout_minutes | Build timeout | number | 30 | no |
| log_retention_days | Log retention period | number | 30 | no |
| buildspec_path | Custom buildspec path | string | "" | no |
| enable_pipeline | Create CodePipeline resources | bool | true | no |
| codepipeline_role_arn | IAM role ARN for CodePipeline | string | "" | no |
| codeconnections_arn | CodeConnections ARN for Bitbucket | string | "" | no |
| repository_id | Full repository ID (owner/repo) | string | "" | no |
| branch_pattern | Branch pattern for trigger | string | "feature/*" | no |
| pipeline_type | Pipeline type (feature/release/production) | string | "feature" | no |
| ecs_cluster_name | ECS cluster name for deployment | string | "" | no |
| ecs_service_name | ECS service name for deployment | string | "" | no |
| s3_kms_key_arn | KMS key ARN for S3 artifacts | string | "" | no |
| enable_notifications | Enable SNS notifications for pipeline events | bool | true | no |
| notification_sns_topic_arn | ARN of existing SNS topic (creates new if empty) | string | "" | no |
| notification_events | List of pipeline events to notify on | list(string) | (see below) | no |
| approval_sns_topic_arn | ARN of SNS topic for approval notifications | string | "" | no |
| approval_timeout_minutes | Timeout for manual approval (default: 7 days) | number | 10080 | no |
| approval_comments | Comments to include in approval notification | string | "Please review..." | no |
| approval_external_entity_link | URL to external entity for approval review | string | "" | no |
| tags | Additional tags | map(string) | {} | no |

### Default Notification Events

When `enable_notifications` is true, the following events trigger notifications by default:
- `codepipeline-pipeline-pipeline-execution-started`
- `codepipeline-pipeline-pipeline-execution-succeeded`
- `codepipeline-pipeline-pipeline-execution-failed`
- `codepipeline-pipeline-stage-execution-started`
- `codepipeline-pipeline-stage-execution-succeeded`
- `codepipeline-pipeline-stage-execution-failed`
- `codepipeline-pipeline-action-execution-failed`

## Outputs

| Name | Description |
|------|-------------|
| codebuild_project_name | Name of the CodeBuild project |
| codebuild_project_arn | ARN of the CodeBuild project |
| cache_bucket_name | S3 bucket for Docker caching |
| artifact_bucket_name | S3 bucket for pipeline artifacts |
| artifact_bucket_arn | ARN of S3 artifact bucket |
| pipeline_name | Name of the CodePipeline |
| pipeline_arn | ARN of the CodePipeline |
| pipeline_type | Type of pipeline configured |
| branch_pattern | Branch pattern for the pipeline |
| detect_changes | Whether webhook is enabled |
| log_group_name | CloudWatch log group name |
| environment_variables | Configured environment variables |
| notification_topic_arn | ARN of the SNS topic for notifications |
| notification_topic_name | Name of the SNS topic (if created) |
| notification_rule_arn | ARN of the CodeStar notification rule |
| notifications_enabled | Whether notifications are enabled |
| requires_approval | Whether pipeline requires manual approval |
| approval_topic_arn | ARN of SNS topic for approval notifications |
| approval_topic_name | Name of approval SNS topic (if created) |
| approval_timeout_minutes | Timeout for manual approval |

## Requirements

- Requirements 3.1: Feature branch pipelines require manual trigger
- Requirements 3.2: Release branch pipelines automatically deploy to TEST and QA environments
- Requirements 3.3: Production pipelines require manual approval before deploying to prod/* branch
- Requirements 3.4: CodeConnections authentication with Bitbucket
- Requirements 6.4: Pipeline notifications sent to SNS topics for state changes
