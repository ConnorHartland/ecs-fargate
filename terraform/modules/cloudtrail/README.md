# CloudTrail Module

This module creates AWS CloudTrail with encryption, S3 bucket with versioning and MFA delete support, and CloudWatch integration for audit logging.

## Requirements

- **11.1**: CloudTrail SHALL log all API calls to AWS services with encryption enabled
- **11.2**: S3 Bucket SHALL store CloudTrail logs with versioning and MFA delete enabled

## Features

- CloudTrail with KMS encryption enabled
- S3 bucket for CloudTrail logs with:
  - Versioning enabled
  - MFA delete support (requires root credentials to enable)
  - Server-side encryption with KMS
  - Public access blocked
  - Lifecycle policies for cost optimization
- Log file validation for integrity verification
- CloudWatch Logs integration for real-time analysis
- Security alerts for:
  - Unauthorized API calls
  - Root account usage
  - IAM policy changes
  - Security group changes

## Usage

```hcl
module "cloudtrail" {
  source = "./modules/cloudtrail"

  environment    = "prod"
  project_name   = "my-project"
  aws_region     = "us-east-1"
  aws_account_id = "123456789012"

  kms_key_arn            = module.security.kms_key_s3_arn
  kms_key_cloudwatch_arn = module.security.kms_key_cloudwatch_arn

  # S3 bucket configuration
  enable_mfa_delete  = false  # Requires root credentials
  log_retention_days = 90

  # CloudTrail configuration
  is_multi_region_trail = true
  enable_insights       = true

  # Alerts
  enable_cloudtrail_alerts = true

  tags = {
    Environment = "prod"
    Owner       = "platform-team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Deployment environment | `string` | n/a | yes |
| project_name | Project name for resource naming | `string` | n/a | yes |
| aws_region | AWS region | `string` | `"us-east-1"` | no |
| aws_account_id | AWS account ID | `string` | n/a | yes |
| kms_key_arn | KMS key ARN for CloudTrail/S3 encryption | `string` | n/a | yes |
| kms_key_cloudwatch_arn | KMS key ARN for CloudWatch Logs | `string` | n/a | yes |
| enable_mfa_delete | Enable MFA delete on S3 bucket | `bool` | `false` | no |
| log_retention_days | Log retention in days | `number` | `90` | no |
| is_multi_region_trail | Create multi-region trail | `bool` | `true` | no |
| enable_insights | Enable CloudTrail Insights | `bool` | `true` | no |
| enable_cloudtrail_alerts | Enable security alerts | `bool` | `true` | no |
| tags | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cloudtrail_arn | ARN of the CloudTrail |
| cloudtrail_name | Name of the CloudTrail |
| s3_bucket_arn | ARN of the S3 bucket |
| s3_bucket_name | Name of the S3 bucket |
| s3_bucket_versioning_enabled | Whether versioning is enabled |
| s3_bucket_mfa_delete_enabled | Whether MFA delete is enabled |
| cloudwatch_log_group_arn | ARN of the CloudWatch Log Group |
| compliance_status | Compliance status summary |

## MFA Delete Note

MFA delete requires root account credentials to enable. The `enable_mfa_delete` variable is set to `false` by default. To enable MFA delete:

1. Log in as the root user
2. Enable MFA delete using the AWS CLI:
   ```bash
   aws s3api put-bucket-versioning \
     --bucket <bucket-name> \
     --versioning-configuration Status=Enabled,MFADelete=Enabled \
     --mfa "arn:aws:iam::<account-id>:mfa/<mfa-device-name> <mfa-code>"
   ```

## Compliance

This module helps meet the following compliance requirements:

- **NIST AU-2**: Audit Events
- **NIST AU-9**: Protection of Audit Information
- **SOC-2 CC7.2**: System Monitoring
