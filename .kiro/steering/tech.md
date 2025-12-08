# Technology Stack

## Infrastructure as Code

- **Terraform**: v1.5.0+ for all infrastructure provisioning
- **HCL**: HashiCorp Configuration Language for Terraform files

## AWS Services

- **Compute**: ECS Fargate (serverless containers)
- **Networking**: VPC, ALB, Security Groups, NAT Gateways
- **Storage**: ECR (container registry), S3 (state/logs)
- **Security**: KMS, Secrets Manager, IAM, CloudTrail, AWS Config
- **CI/CD**: CodePipeline, CodeBuild, CodeConnections
- **Monitoring**: CloudWatch Logs, CloudWatch Alarms, Container Insights
- **Service Discovery**: AWS Cloud Map (for internal services)

## Application Runtimes

- **Node.js**: For API services and web applications
- **Python**: For data processing and analytics services

## Testing

- **Go**: v1.21 for infrastructure testing
- **Terratest**: v0.46.7 for Terraform module testing
- **Property-based testing**: Using pgregory.net/rapid for validation

## Common Commands

### Terraform Operations

```bash
# Initialize with environment-specific backend
terraform init -backend-config=environments/${ENVIRONMENT}/backend.hcl

# Plan changes
terraform plan -var-file="environments/${ENVIRONMENT}/terraform.tfvars" -out=tfplan

# Apply changes
terraform apply tfplan

# Destroy resources (non-production only)
terraform destroy -var-file="environments/${ENVIRONMENT}/terraform.tfvars"

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate
```

### Backend Setup

```bash
# Bootstrap S3 backend and DynamoDB lock table
./scripts/bootstrap-backend.sh

# Migrate bucket to us-east-1 (if needed)
./scripts/migrate-bucket-to-us-east-1.sh
```

### AWS CLI Operations

```bash
# Deploy service manually
aws ecs update-service \
  --cluster ${ENVIRONMENT}-cluster \
  --service ${SERVICE_NAME} \
  --force-new-deployment

# Check service status
aws ecs describe-services \
  --cluster ${ENVIRONMENT}-cluster \
  --services ${SERVICE_NAME}

# View logs
aws logs tail /ecs/${SERVICE_NAME} --follow

# Trigger pipeline
aws codepipeline start-pipeline-execution \
  --name ${SERVICE_NAME}-${ENVIRONMENT}
```

### Testing

```bash
# Run Go tests
cd tests
go test -v ./...

# Run specific test
go test -v -run TestNetworkingProperties

# Run with coverage
go test -v -cover ./...
```

## File Naming Conventions

- Terraform files: `*.tf`
- Variable files: `variables.tf`, `terraform.tfvars`
- Output files: `outputs.tf`
- Version constraints: `versions.tf`
- Backend config: `backend.tf`, `backend.hcl`
- Templates: `*.yml`, `*.json.tpl`

## Code Style

- Use 2-space indentation for HCL
- Group related resources together
- Add comments for complex logic
- Use descriptive variable names
- Include validation rules for variables
- Document all modules with README.md
