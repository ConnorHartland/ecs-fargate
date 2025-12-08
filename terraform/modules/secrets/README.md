# Secrets Manager Module

This module creates and manages AWS Secrets Manager secrets with KMS encryption, automatic rotation configuration, and IAM policies for secure access.

## Features

- Creates Secrets Manager secrets with customer-managed KMS encryption
- Configures automatic secret rotation with Lambda functions
- Creates IAM policies for secret access (both global and service-specific)
- Supports resource-based policies for fine-grained access control
- Environment-aware recovery window configuration

## Usage

```hcl
module "secrets" {
  source = "../modules/secrets"

  environment  = "prod"
  project_name = "myproject"
  aws_region   = "us-east-1"
  kms_key_arn  = module.security.kms_key_secrets_arn

  secrets = {
    "database-credentials" = {
      description   = "Database credentials for the application"
      secret_type   = "database"
      service_name  = "api-service"
      initial_value = {
        username = "admin"
        password = "CHANGE_ME"
        host     = "db.example.com"
        port     = "5432"
        dbname   = "myapp"
      }
      enable_rotation     = true
      rotation_lambda_arn = aws_lambda_function.rotate_db_secret.arn
      rotation_days       = 30
    }

    "api-key" = {
      description   = "External API key"
      secret_type   = "api_key"
      service_name  = "api-service"
      initial_value = {
        api_key = "CHANGE_ME"
      }
    }

    "shared-config" = {
      description   = "Shared configuration across services"
      secret_type   = "generic"
      service_name  = "shared"
      initial_value = {
        kafka_username = "kafka-user"
        kafka_password = "CHANGE_ME"
      }
    }
  }

  tags = {
    Environment = "prod"
    Owner       = "platform-team"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 5.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Deployment environment (develop, test, qa, prod) | `string` | n/a | yes |
| project_name | Project name used for resource naming | `string` | n/a | yes |
| aws_region | AWS region for resource ARN construction | `string` | `"us-east-1"` | no |
| kms_key_arn | ARN of the KMS key to use for encrypting secrets | `string` | n/a | yes |
| recovery_window_days | Number of days before secret deletion (7-30 for prod, 0 for immediate in non-prod) | `number` | `30` | no |
| secrets | Map of secrets to create with their configurations | `map(object)` | `{}` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

### Secret Object Structure

```hcl
{
  description         = string           # Description of the secret
  secret_type         = string           # Type: database, api_key, oauth, certificate, generic
  service_name        = optional(string) # Service that owns this secret (default: "shared")
  initial_value       = map(string)      # Initial key-value pairs for the secret
  enable_rotation     = optional(bool)   # Enable automatic rotation (default: false)
  rotation_lambda_arn = optional(string) # Lambda ARN for rotation (required if enable_rotation=true)
  rotation_days       = optional(number) # Days between rotations (default: 30)
  rotation_schedule   = optional(string) # Cron/rate expression for rotation schedule
  resource_policy     = optional(string) # JSON resource policy for the secret
}
```

## Outputs

| Name | Description |
|------|-------------|
| secret_arns | Map of secret names to their ARNs |
| secret_ids | Map of secret names to their IDs |
| secret_names | Map of secret keys to their full names in Secrets Manager |
| secret_read_policy_arn | ARN of the IAM policy for reading all secrets |
| service_secret_policy_arns | Map of service names to their secret access policy ARNs |
| secrets_with_rotation | List of secret names that have rotation enabled |
| secrets_for_task_definition | Map formatted for ECS task definition secrets |
| secrets_by_service | Map of service names to their associated secret ARNs |

## Security Considerations

1. **Initial Values**: The `initial_value` is only used for initial secret creation. Update secrets manually or via rotation after deployment.

2. **KMS Encryption**: All secrets are encrypted using the provided customer-managed KMS key.

3. **Least Privilege**: Use service-specific IAM policies (`service_secret_policy_arns`) to grant access only to required secrets.

4. **Rotation**: Enable rotation for database credentials and other supported secret types.

5. **Recovery Window**: Production secrets have a 30-day recovery window; non-production can be deleted immediately.

## Requirements Mapping

This module implements the following requirements:

- **Requirement 9.1**: Secrets Manager stores all sensitive configuration
- **Requirement 9.2**: IAM policies grant read-only access to required secrets only
- **Requirement 9.4**: Automatic rotation enabled for supported secret types
- **Requirement 9.5**: KMS encryption for all secrets at rest
