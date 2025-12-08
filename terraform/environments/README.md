# Environment-Specific Configuration Guide

This document explains the differences between environment configurations and provides guidance on using the tfvars files.

## Overview

The infrastructure supports four environments, each with specific configurations optimized for their purpose:

- **develop**: Development environment with minimal resources and relaxed security
- **test**: Testing environment with production-like configuration for validation
- **qa**: QA environment mirroring production for final validation
- **prod**: Production environment with full security controls and high availability

## Environment Comparison

### Resource Configuration

| Setting | Develop | Test | QA | Production |
|---------|---------|------|-----|------------|
| **Log Retention** | 30 days | 30 days | 60 days | 90 days |
| **Deletion Protection** | Disabled | Disabled | Enabled | Enabled |
| **KMS Deletion Window** | 7 days | 7 days | 14 days | 30 days |
| **Default CPU** | 256 | 512 | 512 | 512 |
| **Default Memory** | 512 MB | 1024 MB | 1024 MB | 1024 MB |
| **Default Task Count** | 1 | 2 | 2 | 2 |
| **Fargate Spot** | Enabled | Enabled | Enabled | Disabled |

### Network Configuration

| Setting | Develop | Test | QA | Production |
|---------|---------|------|-----|------------|
| **VPC CIDR** | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 | 10.100.0.0/16 |
| **Availability Zones** | 3 | 3 | 3 | 3 |
| **VPC Isolation** | Non-prod range | Non-prod range | Non-prod range | Isolated prod range |

**Requirements**: 10.4 - Production VPC uses distinct CIDR (10.100.x.x) to ensure network isolation from non-production environments (10.0-2.x.x).

### Security Configuration

| Setting | Develop | Test | QA | Production |
|---------|---------|------|-----|------------|
| **Compliance Tags** | Internal | SOC-2 | SOC-2 | NIST-SOC2 |
| **Secret Rotation** | Optional | Optional | Recommended | Required |
| **MFA Enforcement** | No | No | No | Yes (via IAM policies) |
| **Config Tracking** | Optional | Optional | Recommended | Required |

**Requirements**: 10.5 - Production environment enforces stricter IAM policies, including MFA requirements for human access.

## Key Differences Explained

### 1. Log Retention (Requirements: 2.6)

**Develop/Test**: 30 days
- Shorter retention reduces storage costs
- Sufficient for debugging and troubleshooting
- Logs older than 30 days are automatically deleted

**QA**: 60 days
- Longer retention for compliance validation
- Allows historical analysis during QA cycles

**Production**: 90 days
- Meets NIST and SOC-2 compliance requirements
- Required for audit trails and forensic analysis
- Minimum retention period for production systems

### 2. Deletion Protection

**Develop/Test**: Disabled
- Allows easy cleanup of test resources
- Faster iteration during development
- Resources can be destroyed without additional steps

**QA/Production**: Enabled
- Prevents accidental deletion of critical resources
- Requires explicit override to delete protected resources
- Protects ALB, RDS, and other stateful resources

### 3. KMS Key Deletion Window

**Develop/Test**: 7 days (minimum)
- Faster cleanup of test encryption keys
- Reduces waiting period for resource recreation

**QA**: 14 days (moderate)
- Balance between protection and flexibility

**Production**: 30 days (maximum)
- Maximum protection against accidental key deletion
- Allows recovery from mistakes
- Meets compliance requirements for key management

### 4. ECS Task Resources

**Develop**: 256 CPU / 512 MB Memory
- Minimum Fargate resources for cost optimization
- Suitable for development workloads
- Single task instance (desired_count = 1)

**Test/QA/Production**: 512 CPU / 1024 MB Memory
- Production-like resources for realistic testing
- Better performance for load testing
- Multiple task instances (desired_count = 2) for high availability

### 5. Fargate Spot (Requirements: Cost Optimization)

**Develop/Test/QA**: Enabled
- Up to 70% cost savings compared to On-Demand
- Acceptable for non-critical workloads
- Tasks may be interrupted with 2-minute warning

**Production**: Disabled
- Uses only Fargate On-Demand for maximum reliability
- No interruptions or task replacements
- Consistent performance for production workloads

### 6. VPC Isolation (Requirements: 10.4)

**Non-Production (Develop/Test/QA)**:
- CIDR ranges: 10.0.0.0/16, 10.1.0.0/16, 10.2.0.0/16
- Can communicate via VPC peering if needed
- Shared security posture

**Production**:
- CIDR range: 10.100.0.0/16
- Isolated from non-production environments
- Separate network security controls
- VPC peering requires explicit configuration

## Usage Instructions

### 1. Initial Setup

Before deploying to any environment, update the following values in the respective tfvars file:

```hcl
# Required: ACM Certificate for HTTPS
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"

# Required: Kafka Configuration (if using internal services)
kafka_brokers = [
  "broker1.kafka.internal:9092",
  "broker2.kafka.internal:9092",
  "broker3.kafka.internal:9092"
]
kafka_security_group_id = "sg-xxxxx"

# Required: Compliance Tags
mandatory_tags = {
  Owner      = "Your Team Name"
  CostCenter = "Your Cost Center"
  Compliance = "NIST-SOC2" # or "SOC-2" or "Internal"
}
```

### 2. Deploying to an Environment

```bash
# Navigate to the environment directory
cd terraform/environments/develop

# Initialize Terraform (first time only)
terraform init -backend-config=backend.hcl

# Review the plan
terraform plan -var-file=terraform.tfvars

# Apply the configuration
terraform apply -var-file=terraform.tfvars
```

### 3. Configuring Secrets

Secrets should be configured in the `secrets` variable. After Terraform creates the secrets in AWS Secrets Manager, update the actual values in the AWS Console:

```hcl
secrets = {
  "example-db-credentials" = {
    description   = "Database credentials"
    secret_type   = "database"
    service_name  = "example-service"
    initial_value = {
      username = "admin"
      password = "CHANGE_ME_IN_AWS_CONSOLE"  # Update in AWS Console after creation
      host     = "db.example.internal"
      port     = "5432"
      database = "example_db"
    }
    enable_rotation = true  # Enable for production
    rotation_days   = 30
  }
}
```

**Important**: Never commit actual secrets to version control. Use placeholder values in tfvars files and update them in AWS Secrets Manager after creation.

### 4. VPC Peering Configuration

To enable cross-environment communication (e.g., production accessing non-production resources):

```hcl
enable_vpc_peering = true
vpc_peering_connections = [
  {
    peer_vpc_id      = "vpc-xxxxx"        # VPC ID from other environment
    peer_vpc_cidr    = "10.0.0.0/16"      # CIDR from other environment
    name             = "prod-to-develop"
    allow_remote_dns = true
  }
]
```

### 5. AWS Config Aggregation

For multi-account or multi-region compliance tracking:

```hcl
enable_config_aggregator = true
config_aggregator_account_ids = [
  "123456789012",  # Account ID 1
  "234567890123"   # Account ID 2
]
config_aggregator_regions = [
  "us-east-1",
  "us-west-2"
]
```

## Environment Promotion Workflow

### 1. Develop → Test

1. Deploy and test changes in develop environment
2. Validate functionality and performance
3. Update test environment tfvars if needed
4. Deploy to test environment
5. Run automated test suite

### 2. Test → QA

1. Verify all tests pass in test environment
2. Update QA environment tfvars if needed
3. Deploy to QA environment
4. Perform user acceptance testing
5. Validate compliance requirements

### 3. QA → Production

1. Get approval from stakeholders
2. Review production tfvars for any required updates
3. Schedule maintenance window (if needed)
4. Deploy to production with monitoring
5. Validate deployment success
6. Monitor CloudWatch metrics and alarms

## Best Practices

### 1. Variable Management

- **Never commit secrets**: Use placeholder values and update in AWS Console
- **Use consistent naming**: Follow the naming conventions in examples
- **Document changes**: Add comments explaining non-obvious configurations
- **Version control**: Commit tfvars files (without secrets) to track changes

### 2. Security

- **Enable deletion protection**: Always enabled for QA and production
- **Use secret rotation**: Enable for all production secrets where supported
- **Review IAM policies**: Ensure least privilege access
- **Enable MFA**: Required for production human access

### 3. Cost Optimization

- **Use Fargate Spot**: Enable for non-production environments
- **Right-size resources**: Start with minimum and scale up as needed
- **Set log retention**: Use shorter retention for non-production
- **Clean up unused resources**: Regularly review and remove test resources

### 4. Compliance

- **Tag all resources**: Use mandatory tags for cost tracking and compliance
- **Enable CloudTrail**: Track all API calls for audit trails
- **Enable Config**: Track resource configuration changes
- **Review regularly**: Conduct quarterly compliance reviews

## Troubleshooting

### Issue: Terraform plan shows unexpected changes

**Solution**: Ensure you're using the correct tfvars file for the environment:
```bash
terraform plan -var-file=terraform.tfvars
```

### Issue: VPC CIDR conflicts

**Solution**: Verify each environment uses distinct CIDR ranges:
- Develop: 10.0.0.0/16
- Test: 10.1.0.0/16
- QA: 10.2.0.0/16
- Production: 10.100.0.0/16

### Issue: Secrets not accessible by ECS tasks

**Solution**: 
1. Verify secrets exist in AWS Secrets Manager
2. Check IAM task role has GetSecretValue permission
3. Verify secret ARNs in task definition match actual secrets

### Issue: Fargate Spot interruptions in production

**Solution**: Production should have `fargate_spot_enabled = false`. Update prod tfvars and redeploy.

## References

- **Requirements**: See `.kiro/specs/ecs-fargate-cicd-infrastructure/requirements.md`
- **Design**: See `.kiro/specs/ecs-fargate-cicd-infrastructure/design.md`
- **AWS Fargate**: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

## Support

For questions or issues:
1. Review this documentation
2. Check the design document for architectural details
3. Review CloudWatch logs for runtime issues
4. Contact the DevOps team for assistance
