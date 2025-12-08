# Security Module

Manages encryption keys (KMS) and IAM roles for the ECS Fargate infrastructure.

## Overview

This module creates:
- Customer-managed KMS keys for ECS, ECR, Secrets Manager, CloudWatch, and S3
- IAM role templates for ECS task execution and task roles
- IAM role for CodeBuild with ECR and CloudWatch permissions
- IAM role for CodePipeline with required permissions
- Production-specific IAM policies with MFA enforcement (Requirements: 11.3)

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

### Production IAM Policies (MFA Required)

The following policies are created only in production environments when `require_mfa_for_production = true`:

| Policy | Purpose | Access Level |
|--------|---------|--------------|
| enforce-mfa | Enforces MFA for all actions except MFA self-management | Base policy for all users |
| production-access | General production resource access with MFA | Read access to production resources |
| production-readonly | Read-only access to ECS, ECR, CloudWatch | View-only access |
| production-operator | Operational access (update services, view logs) | Day-to-day operations |
| production-admin | Full administrative access to production resources | Full access with MFA |
| production-protection | Denies destructive actions without MFA | Protection layer |

## Usage

```hcl
module "security" {
  source = "./modules/security"

  environment    = "prod"
  project_name   = "myproject"
  aws_region     = "us-east-1"
  aws_account_id = "123456789012"

  enable_key_rotation        = true
  key_deletion_window_days   = 30
  require_mfa_for_production = true  # Enable MFA enforcement

  tags = {
    Environment = "prod"
    Owner       = "platform-team"
  }
}
```

### Attaching MFA Policies to IAM Groups

After deploying the module, attach the policies to IAM groups for human users:

```hcl
# Create IAM groups for different access levels
resource "aws_iam_group" "production_readonly" {
  name = "production-readonly-users"
}

resource "aws_iam_group" "production_operators" {
  name = "production-operators"
}

resource "aws_iam_group" "production_admins" {
  name = "production-admins"
}

# Attach MFA enforcement policy to all groups
resource "aws_iam_group_policy_attachment" "readonly_mfa" {
  group      = aws_iam_group.production_readonly.name
  policy_arn = module.security.enforce_mfa_policy_arn
}

resource "aws_iam_group_policy_attachment" "operators_mfa" {
  group      = aws_iam_group.production_operators.name
  policy_arn = module.security.enforce_mfa_policy_arn
}

resource "aws_iam_group_policy_attachment" "admins_mfa" {
  group      = aws_iam_group.production_admins.name
  policy_arn = module.security.enforce_mfa_policy_arn
}

# Attach role-specific policies
resource "aws_iam_group_policy_attachment" "readonly_access" {
  group      = aws_iam_group.production_readonly.name
  policy_arn = module.security.production_readonly_policy_arn
}

resource "aws_iam_group_policy_attachment" "operators_access" {
  group      = aws_iam_group.production_operators.name
  policy_arn = module.security.production_operator_policy_arn
}

resource "aws_iam_group_policy_attachment" "admins_access" {
  group      = aws_iam_group.production_admins.name
  policy_arn = module.security.production_admin_policy_arn
}

# Attach protection policy to prevent destructive actions without MFA
resource "aws_iam_group_policy_attachment" "admins_protection" {
  group      = aws_iam_group.production_admins.name
  policy_arn = module.security.production_protection_policy_arn
}
```

## MFA Setup Requirements

### Prerequisites for Human Users

All human users accessing production resources MUST have MFA enabled. This is enforced by the `enforce-mfa` policy which denies all actions (except MFA self-management) when MFA is not present.

### Setting Up MFA for IAM Users

#### Step 1: Enable Virtual MFA Device

1. Sign in to the AWS Management Console
2. Navigate to IAM > Users > [Your Username] > Security credentials
3. In the "Multi-factor authentication (MFA)" section, click "Assign MFA device"
4. Select "Virtual MFA device" and click "Continue"
5. Use an authenticator app (Google Authenticator, Authy, etc.) to scan the QR code
6. Enter two consecutive MFA codes to complete setup

#### Step 2: Using MFA with AWS CLI

For CLI access with MFA, users must obtain temporary credentials:

```bash
# Get temporary credentials with MFA
aws sts get-session-token \
  --serial-number arn:aws:iam::ACCOUNT_ID:mfa/USERNAME \
  --token-code MFA_CODE \
  --duration-seconds 43200

# Export the temporary credentials
export AWS_ACCESS_KEY_ID=<AccessKeyId>
export AWS_SECRET_ACCESS_KEY=<SecretAccessKey>
export AWS_SESSION_TOKEN=<SessionToken>
```

#### Step 3: Configure AWS CLI Profile with MFA

Add to `~/.aws/config`:

```ini
[profile production]
region = us-east-1
mfa_serial = arn:aws:iam::ACCOUNT_ID:mfa/USERNAME

[profile production-mfa]
source_profile = production
role_arn = arn:aws:iam::ACCOUNT_ID:role/ProductionAccessRole
mfa_serial = arn:aws:iam::ACCOUNT_ID:mfa/USERNAME
```

### MFA Policy Behavior

| Scenario | Behavior |
|----------|----------|
| User without MFA tries to access production | Access denied |
| User with MFA accesses production read-only | Access granted (with readonly policy) |
| User with MFA tries destructive action | Access granted only with admin policy |
| User without MFA tries to set up MFA | Access granted (self-management allowed) |

### Compliance Mapping

| Policy | NIST Control | SOC 2 Control |
|--------|--------------|---------------|
| enforce-mfa | IA-2 (Identification and Authentication) | CC6.1 (Logical Access) |
| production-access | AC-3 (Access Enforcement) | CC6.1 (Logical Access) |
| production-protection | AC-6 (Least Privilege) | CC6.1 (Logical Access) |
| permissions-boundary | AC-2 (Account Management) | CC6.1 (Logical Access) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Deployment environment (develop, test, qa, prod) | string | - | yes |
| project_name | Project name used for resource naming | string | - | yes |
| aws_region | AWS region for resource ARN construction | string | "us-east-1" | no |
| aws_account_id | AWS account ID for resource ARN construction | string | - | yes |
| enable_key_rotation | Enable automatic key rotation for KMS keys | bool | true | no |
| key_deletion_window_days | Days before KMS key deletion (7-30) | number | 30 | no |
| require_mfa_for_production | Require MFA for IAM policies accessing production resources | bool | true | no |
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

### Production IAM Policies (MFA)

| Name | Description |
|------|-------------|
| enforce_mfa_policy_arn | ARN of the MFA enforcement policy |
| production_readonly_policy_arn | ARN of the production read-only policy |
| production_operator_policy_arn | ARN of the production operator policy |
| production_admin_policy_arn | ARN of the production admin policy |
| production_access_policy_arn | ARN of the production access policy |
| production_protection_policy_arn | ARN of the production protection policy |
| permissions_boundary_policy_arn | ARN of the permissions boundary policy |
| human_access_policies | Map of all human user access policy ARNs |

## Security Considerations

- All KMS keys have automatic rotation enabled by default
- IAM policies follow least privilege principle
- Secrets access is scoped to environment-specific prefixes
- CodeBuild can only push to ECR repositories with matching prefix
- CodePipeline ECS access is restricted by environment tag
- **Production resources require MFA for all human user access (NIST IA-2, SOC 2 CC6.1)**
- Destructive actions in production are denied without MFA authentication
- Permissions boundaries limit maximum permissions for production roles

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 5.0.0 |
