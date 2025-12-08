# Design Document

## Overview

This design addresses S3 bucket permission issues preventing successful deployment of ALB access logging and AWS Config delivery channels. The root causes are:

1. **Path mismatch in Config module**: IAM role policy uses `/AWSLogs/.../Config/*` while bucket policy and delivery channel use `/config/.../*`
2. **Missing dependency ordering**: Resources may be created before bucket policies are fully propagated
3. **Incomplete bucket policy permissions**: Some required permissions may be missing or incorrectly scoped

The solution involves correcting S3 path references, ensuring proper Terraform dependency ordering, and validating all required permissions are present.

## Architecture

The fix operates at the Terraform module level, modifying two modules:

1. **ALB Module** (`terraform/modules/alb/`): Ensures bucket policy is applied before ALB attempts to enable access logs
2. **Config Module** (`terraform/modules/config/`): Fixes path mismatches and ensures proper dependency ordering

### Component Interaction

```
Terraform Apply
    ↓
Create S3 Bucket
    ↓
Apply Bucket Policy (with correct paths)
    ↓
[Wait for propagation]
    ↓
Create ALB/Config with access to bucket
```

## Components and Interfaces

### ALB Module Changes

**File**: `terraform/modules/alb/main.tf`

**Current State**:
- S3 bucket policy exists with correct permissions
- ALB resource has `depends_on` for bucket policy
- Policy grants permissions to ELB service account and elasticloadbalancing service

**Required Changes**:
- Verify resource ARN patterns match actual prefix usage
- Ensure all required service principals have necessary permissions

### Config Module Changes

**File**: `terraform/modules/config/main.tf`

**Current State**:
- IAM role policy uses path: `/AWSLogs/${var.aws_account_id}/Config/*`
- Bucket policy uses path: `/config/${var.aws_account_id}/*`
- Delivery channel uses prefix: `config/${var.aws_account_id}`

**Required Changes**:
- Standardize on single path pattern across all resources
- Update IAM role policy to match bucket policy and delivery channel
- Verify delivery channel depends on bucket policy

## Data Models

### S3 Path Patterns

**Config Module Standardized Path**:
```
Bucket: ecs-fargate-{environment}-config-{account_id}
Prefix: config/{account_id}/
Full Path: s3://bucket-name/config/{account_id}/*
```

**ALB Module Path**:
```
Bucket: ecs-fargate-{environment}-alb-logs
Prefix: {configurable, default: ""}
Full Path: s3://bucket-name/{prefix}/*
```

### Terraform Resource Dependencies

```hcl
aws_s3_bucket
  ↓
aws_s3_bucket_public_access_block
  ↓
aws_s3_bucket_policy
  ↓
aws_lb (ALB) or aws_config_delivery_channel
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

Property 1: ALB bucket policy completeness
*For any* ALB module configuration, the generated S3 bucket policy should contain all three required permission statements: (1) PutObject for ELB service account, (2) PutObject for elasticloadbalancing.amazonaws.com service principal, and (3) GetBucketAcl for delivery.logs.amazonaws.com service principal
**Validates: Requirements 1.1, 1.2, 1.3**

Property 2: Config bucket policy completeness
*For any* Config module configuration, the generated S3 bucket policy should contain both required permission statements: (1) GetBucketAcl for config.amazonaws.com service principal, and (2) PutObject for config.amazonaws.com with bucket-owner-full-control ACL condition
**Validates: Requirements 2.1, 2.2**

Property 3: S3 path consistency
*For any* module configuration, all S3 resource ARN references (in bucket policies, IAM policies, and delivery channel configurations) should use the same path prefix pattern
**Validates: Requirements 1.5, 2.3, 2.5**

Property 4: Terraform dependency ordering
*For any* module that creates both an S3 bucket policy and a resource that uses that bucket (ALB or Config delivery channel), the using resource should have an explicit depends_on relationship to the bucket policy resource
**Validates: Requirements 1.4, 2.4**

## Error Handling

### Terraform Apply Failures

**Scenario**: S3 bucket policy not yet propagated when AWS service tries to access bucket

**Handling**:
- Use explicit `depends_on` in Terraform to enforce ordering
- If propagation delays persist, consider adding `time_sleep` resource with 10-30 second delay after bucket policy creation

**Scenario**: Path mismatch between IAM policy and bucket policy

**Handling**:
- Use local variables to define paths once and reference throughout module
- Validate paths match in module outputs or validation blocks

### AWS Service Errors

**Scenario**: "Access Denied for bucket" error from ALB

**Root Cause**: Missing or incorrect bucket policy permissions

**Resolution**: Verify all three service principals have required permissions in bucket policy

**Scenario**: "Insufficient delivery policy to s3 bucket" error from Config

**Root Cause**: Path mismatch between IAM role policy and actual delivery prefix

**Resolution**: Ensure IAM role policy resource ARN matches delivery channel s3_key_prefix

## Testing Strategy

### Unit Testing

Unit tests will verify Terraform configuration correctness:

1. **HCL Parsing Tests**: Parse Terraform files and verify resource structure
2. **Policy Document Tests**: Parse JSON policy documents and verify required statements exist
3. **Dependency Graph Tests**: Verify depends_on relationships are correctly specified

### Property-Based Testing

Property-based tests will use Go with the `testing/quick` package or `gopter` library to generate random configurations and verify properties hold:

1. **Property 1 Test**: Generate random ALB configurations, render bucket policy, parse JSON, verify all three required statements present
2. **Property 2 Test**: Generate random Config configurations, render bucket policy, parse JSON, verify both required statements present with correct conditions
3. **Property 3 Test**: Generate random module configurations, extract all S3 path references, verify they all use the same prefix pattern
4. **Property 4 Test**: Parse Terraform HCL for ALB and Config modules, verify depends_on includes bucket policy resource

**Testing Framework**: Go with `gopter` for property-based testing
**Test Location**: `tests/properties/s3_permissions_properties_test.go`
**Minimum Iterations**: 100 per property test

### Integration Testing

Integration tests will deploy actual Terraform configurations to verify:

1. ALB access logs successfully enabled without errors
2. Config delivery channel successfully created without errors
3. Logs actually written to S3 buckets by AWS services

## Implementation Notes

### Config Module Path Standardization

The Config module currently has inconsistent paths:
- IAM role policy: `/AWSLogs/${var.aws_account_id}/Config/*`
- Bucket policy: `/config/${var.aws_account_id}/*`
- Delivery channel: `config/${var.aws_account_id}`

**Decision**: Standardize on `config/${var.aws_account_id}` pattern (lowercase "config", no leading slash for prefix)

**Rationale**: 
- Matches AWS Config service expectations
- Consistent with delivery channel prefix format
- Simpler path structure

### ALB Module Verification

The ALB module appears to have correct configuration, but we should verify:
- Resource ARN in bucket policy matches actual prefix used
- All three service principals are present (ELB account, elasticloadbalancing service, delivery.logs service)

### Dependency Ordering

Both modules should use explicit `depends_on`:

```hcl
resource "aws_lb" "main" {
  # ... configuration ...
  
  depends_on = [
    aws_s3_bucket_policy.access_logs,
    aws_s3_bucket_public_access_block.access_logs
  ]
}

resource "aws_config_delivery_channel" "main" {
  # ... configuration ...
  
  depends_on = [
    aws_config_configuration_recorder.main,
    aws_s3_bucket_policy.config
  ]
}
```

### Local Variables for Path Management

Use local variables to ensure consistency:

```hcl
locals {
  config_prefix = "config/${var.aws_account_id}"
  config_path_pattern = "${aws_s3_bucket.config.arn}/${local.config_prefix}/*"
}
```

Then reference `local.config_path_pattern` in both IAM policy and bucket policy.
