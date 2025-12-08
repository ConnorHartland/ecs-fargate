# ECR Module

Manages Amazon Elastic Container Registry (ECR) repositories with security controls meeting NIST and SOC-2 compliance requirements.

## Features

- **KMS Encryption**: All container images encrypted at rest using customer-managed KMS keys
- **Image Tag Immutability**: Prevents image tag overwrites for deployment consistency
- **Vulnerability Scanning**: Automatic image scanning on push to detect security vulnerabilities
- **Lifecycle Policies**: Automatic cleanup of untagged images and retention limits
- **Access Control**: Repository policies restricting access to authorized ECS tasks and CI/CD pipelines

## Resources Created

- `aws_ecr_repository` - Container image repository with encryption and scanning
- `aws_ecr_lifecycle_policy` - Image retention and cleanup rules
- `aws_ecr_repository_policy` - IAM-based access control

## Usage

```hcl
module "ecr" {
  source = "./modules/ecr"

  service_name                = "my-service"
  environment                 = "prod"
  project_name                = "ecs-fargate"
  kms_key_arn                 = module.security.kms_key_ecr_arn
  aws_account_id              = data.aws_caller_identity.current.account_id
  aws_region                  = var.aws_region
  ecs_task_execution_role_arn = module.security.ecs_task_execution_role_arn
  codebuild_role_arn          = module.security.codebuild_role_arn

  tags = var.mandatory_tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| service_name | Name of the service for the ECR repository | `string` | n/a | yes |
| environment | Deployment environment (develop, test, qa, prod) | `string` | n/a | yes |
| project_name | Project name used for resource naming | `string` | `"ecs-fargate"` | no |
| kms_key_arn | ARN of the KMS key for ECR encryption | `string` | n/a | yes |
| aws_account_id | AWS account ID for repository policy | `string` | n/a | yes |
| aws_region | AWS region for resource deployment | `string` | `"us-east-1"` | no |
| image_tag_mutability | Image tag mutability setting | `string` | `"IMMUTABLE"` | no |
| scan_on_push | Enable image scanning on push | `bool` | `true` | no |
| untagged_image_expiry_days | Days before untagged images are removed | `number` | `7` | no |
| max_tagged_images | Maximum number of tagged images to retain | `number` | `10` | no |
| ecs_task_execution_role_arn | ARN of the ECS task execution role | `string` | n/a | yes |
| codebuild_role_arn | ARN of the CodeBuild role | `string` | n/a | yes |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| repository_arn | ARN of the ECR repository |
| repository_name | Name of the ECR repository |
| repository_url | URL of the ECR repository |
| repository_registry_id | Registry ID where the repository was created |
| image_tag_mutability | Image tag mutability setting |
| scan_on_push | Whether image scanning on push is enabled |
| encryption_type | Encryption type for the repository |
| kms_key_arn | ARN of the KMS key used for encryption |

## Lifecycle Policy Rules

The module implements the following lifecycle rules:

1. **Production Images**: Images tagged with `prod-*` are retained indefinitely
2. **Untagged Images**: Removed after 7 days (configurable)
3. **Environment Images**: Keep last 10 images tagged with `develop-*`, `test-*`, `qa-*`
4. **General Cleanup**: Keep last 30 images overall

## Security Considerations

- Repository policy denies access over non-HTTPS connections
- Access restricted to specific IAM roles (ECS task execution, CodeBuild)
- No public access allowed (Principal cannot be `*` without conditions)
- KMS encryption ensures images are encrypted at rest

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 5.0.0 |

## Compliance

This module supports the following compliance requirements:

- **NIST SC-28**: Protection of Information at Rest (KMS encryption)
- **NIST SC-13**: Cryptographic Protection (KMS customer-managed keys)
- **SOC-2 CC6.6**: Encryption (KMS encryption at rest)
- **Requirements 2.3, 4.1-4.6**: ECR security and lifecycle management
