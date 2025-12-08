# Security Module

Manages encryption keys (KMS) and IAM roles for the ECS Fargate infrastructure.

## Overview

This module creates:
- Customer-managed KMS keys for ECS, ECR, Secrets Manager, CloudWatch, and S3
- IAM role templates for ECS task execution and task roles
- IAM role for CodeBuild with ECR and CloudWatch permissions
- IAM role for CodePipeline with required permissions

## Resources Created

### KMS Keys

| Key | Purpose | Services Allowed |
|-----|---------|------------------|
| ECS | Task volumes, execute command | ecs.amazonaws.com |
| ECR | Container image encryption | ecr.amazonaws.com |
| Secrets | Secrets Manager encryption | secretsmanager.amazonaws.com |
| CloudWatch | Log encryption | logs.{region}.amazonaws.com |
| S3 | ALB logs, artifacts, CloudTrail | s3, cloudtrail, delivery.logs |

### IAM Roles

| Role | Purpose | Key Permissions |
|------|---------|-----------------|
| ECS Task Execution | Pull images, write logs, read secrets | ECR pull, CloudWatch logs, Secrets Manager read |
| ECS Task | Application runtime permissions | Service-specific secrets read |
| CodeBuild | Build Docker images | ECR push, CloudWatch logs, S3 artifacts |
| CodePipeline | Orchestrate CI/CD | S3, CodeBuild, ECS deploy, SNS |

## Usage

```hcl
module "security" {
  source = "./modules/security"

  environment    = "prod"
  project_name   = "myproject"
  aws_region     = "us-east-1"
  aws_account_id = "123456789012"

  enable_key_rotation      = true
  key_deletion_window_days = 30

  tags = {
    Environment = "prod"
    Owner       = "platform-team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Deployment environment (develop, test, qa, prod) | string | - | yes |
| project_name | Project name used for resource naming | string | - | yes |
| aws_region | AWS region for resource ARN construction | string | "us-east-1" | no |
| aws_account_id | AWS account ID for resource ARN construction | string | - | yes |
| enable_key_rotation | Enable automatic key rotation for KMS keys | bool | true | no |
| key_deletion_window_days | Days before KMS key deletion (7-30) | number | 30 | no |
| tags | Additional tags to apply to all resources | map(string) | {} | no |

## Outputs

### KMS Keys

| Name | Description |
|------|-------------|
| kms_key_ecs_arn | ARN of the KMS key for ECS encryption |
| kms_key_ecr_arn | ARN of the KMS key for ECR encryption |
| kms_key_secrets_arn | ARN of the KMS key for Secrets Manager encryption |
| kms_key_cloudwatch_arn | ARN of the KMS key for CloudWatch Logs encryption |
| kms_key_s3_arn | ARN of the KMS key for S3 encryption |
| kms_keys | Map of all KMS key ARNs by purpose |

### IAM Roles

| Name | Description |
|------|-------------|
| ecs_task_execution_role_arn | ARN of the ECS task execution role |
| ecs_task_role_arn | ARN of the ECS task role |
| codebuild_role_arn | ARN of the CodeBuild service role |
| codepipeline_role_arn | ARN of the CodePipeline service role |
| iam_roles | Map of all IAM role ARNs by purpose |

## Security Considerations

- All KMS keys have automatic rotation enabled by default
- IAM policies follow least privilege principle
- Secrets access is scoped to environment-specific prefixes
- CodeBuild can only push to ECR repositories with matching prefix
- CodePipeline ECS access is restricted by environment tag

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 5.0.0 |
