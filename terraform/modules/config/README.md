# AWS Config Module

This module creates AWS Config resources for compliance tracking and configuration management.

## Requirements

- Terraform >= 1.0.0
- AWS Provider >= 5.0.0

## Features

- **Config Recorder**: Records configuration changes for all supported AWS resource types
- **Delivery Channel**: Delivers configuration snapshots and history to S3
- **Managed Rules**: Pre-configured compliance rules for ECS, encryption, IAM, and VPC
- **Config Aggregator**: Optional multi-account/multi-region aggregation
- **SNS Notifications**: Alerts for compliance state changes
- **S3 Storage**: Encrypted bucket with lifecycle policies for configuration data

## Compliance Coverage

This module implements controls for:
- **NIST**: CM-2 (Baseline Configuration), AU-2 (Audit Events), SC-7 (Boundary Protection), SC-28 (Protection of Information at Rest)
- **SOC-2**: CC8.1 (Change Management)

## Usage

```hcl
module "config" {
  source = "./modules/config"

  environment    = "prod"
  project_name   = "myproject"
  aws_region     = "us-east-1"
  aws_account_id = "123456789012"
  kms_key_arn    = module.security.s3_kms_key_arn

  # Optional: Enable specific rule categories
  enable_managed_rules    = true
  enable_ecs_rules        = true
  enable_encryption_rules = true
  enable_iam_rules        = true
  enable_vpc_rules        = true

  # Optional: Multi-account aggregation
  enable_aggregator       = false
  aggregator_account_ids  = []

  tags = {
    Environment = "prod"
    Owner       = "platform-team"
    CostCenter  = "infrastructure"
    Compliance  = "NIST,SOC2"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Deployment environment (develop, test, qa, prod) | `string` | n/a | yes |
| project_name | Project name used for resource naming | `string` | n/a | yes |
| aws_region | AWS region for resource deployment | `string` | `"us-east-1"` | no |
| aws_account_id | AWS account ID for resource ARN construction | `string` | n/a | yes |
| kms_key_arn | ARN of the KMS key for S3 bucket encryption | `string` | n/a | yes |
| config_bucket_name | Name of the S3 bucket for Config delivery | `string` | `null` | no |
| log_retention_days | Number of days to retain Config snapshots | `number` | `90` | no |
| recording_frequency | Recording frequency (CONTINUOUS or DAILY) | `string` | `"CONTINUOUS"` | no |
| include_global_resources | Include global resources (IAM) in recording | `bool` | `true` | no |
| resource_types | List of resource types to record (empty = all) | `list(string)` | `[]` | no |
| enable_managed_rules | Enable AWS managed Config rules | `bool` | `true` | no |
| enable_ecs_rules | Enable ECS-specific Config rules | `bool` | `true` | no |
| enable_encryption_rules | Enable encryption-related Config rules | `bool` | `true` | no |
| enable_iam_rules | Enable IAM-related Config rules | `bool` | `true` | no |
| enable_vpc_rules | Enable VPC-related Config rules | `bool` | `true` | no |
| enable_aggregator | Enable Config aggregator | `bool` | `false` | no |
| aggregator_account_ids | List of account IDs to aggregate | `list(string)` | `[]` | no |
| aggregator_regions | List of regions to aggregate | `list(string)` | `[]` | no |
| enable_sns_notifications | Enable SNS notifications for Config events | `bool` | `true` | no |
| sns_topic_arn | ARN of existing SNS topic for notifications | `string` | `null` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| config_recorder_id | ID of the AWS Config recorder |
| config_recorder_name | Name of the AWS Config recorder |
| delivery_channel_id | ID of the AWS Config delivery channel |
| s3_bucket_id | ID of the S3 bucket for Config delivery |
| s3_bucket_arn | ARN of the S3 bucket for Config delivery |
| config_notifications_topic_arn | ARN of the SNS topic for Config notifications |
| compliance_alerts_topic_arn | ARN of the SNS topic for compliance alerts |
| aggregator_arn | ARN of the Config aggregator (if enabled) |
| ecs_config_rules | Map of ECS-related Config rule ARNs |
| encryption_config_rules | Map of encryption-related Config rule ARNs |
| iam_config_rules | Map of IAM-related Config rule ARNs |
| vpc_config_rules | Map of VPC-related Config rule ARNs |
| config_enabled | Whether AWS Config is enabled |
| compliance_status | Compliance status summary |

## Config Rules

### ECS Rules
- `ECS_TASK_DEFINITION_MEMORY_HARD_LIMIT` - Checks memory limits
- `ECS_TASK_DEFINITION_NONROOT_USER` - Checks for non-root user
- `ECS_TASK_DEFINITION_LOG_CONFIGURATION` - Checks logging configuration
- `ECS_CONTAINERS_READONLY_ACCESS` - Checks read-only root filesystem

### Encryption Rules
- `S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED` - S3 encryption
- `S3_BUCKET_SSL_REQUESTS_ONLY` - S3 SSL enforcement
- `ECR_PRIVATE_IMAGE_SCANNING_ENABLED` - ECR image scanning
- `CLOUDWATCH_LOG_GROUP_ENCRYPTED` - CloudWatch log encryption
- `KMS_CMK_NOT_SCHEDULED_FOR_DELETION` - KMS key protection

### IAM Rules
- `IAM_ROOT_ACCESS_KEY_CHECK` - Root account access keys
- `IAM_USER_MFA_ENABLED` - User MFA enforcement
- `IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS` - Admin access policies
- `IAM_USER_UNUSED_CREDENTIALS_CHECK` - Unused credentials

### VPC Rules
- `VPC_FLOW_LOGS_ENABLED` - VPC Flow Logs
- `VPC_DEFAULT_SECURITY_GROUP_CLOSED` - Default security group
- `INCOMING_SSH_DISABLED` - SSH access restrictions
- `RESTRICTED_INCOMING_TRAFFIC` - Common port restrictions

## Notes

- Config recorder must be enabled in each region where you want to track resources
- Global resources (IAM) should only be recorded in one region to avoid duplicates
- Config rules may take a few minutes to evaluate after initial deployment
- S3 bucket lifecycle policies automatically archive and delete old configuration data
