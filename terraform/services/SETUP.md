# Service Setup Guide

## How Variables Work

Each service gets its configuration from the **root infrastructure** using Terraform remote state. This means:

1. Deploy root infrastructure first (VPC, ECS, ALB, etc.)
2. Services read outputs from root via `terraform_remote_state`
3. No need to manually pass 50+ variables around

## Quick Start

### 1. Deploy Root Infrastructure (if not done)

```bash
cd terraform
terraform init -backend-config=environments/develop/backend.hcl
terraform apply -var-file=environments/develop/terraform.tfvars
```

### 2. Configure Service

Edit `service-1/provider.tf`:

```hcl
# Update these values:
config = {
  bucket = "ecs-fargate-terraform-state-YOUR-ACCOUNT-ID"  # Your S3 bucket
  key    = "terraform.tfstate"
  region = "us-east-1"  # Your region
}

# Add your values:
codeconnections_arn = "arn:aws:codeconnections:..."  # From AWS Console
kafka_brokers       = ["broker1:9092", "broker2:9092"]  # If using Kafka
```

Edit `service-1/main.tf`:

```hcl
repository_url = "your-org/your-repo"  # Your Bitbucket repo
```

### 3. Create Secrets

```bash
aws secretsmanager create-secret \
  --name develop/service-1/database-url \
  --secret-string "postgresql://user:pass@host:5432/db"

aws secretsmanager create-secret \
  --name develop/service-1/api-key \
  --secret-string "your-api-key"
```

### 4. Deploy Service

```bash
cd terraform/services/service-1
terraform init -backend-config=../../environments/develop/backend.hcl
terraform plan
terraform apply
```

## What Gets Pulled from Root Infrastructure

The `provider.tf` file automatically pulls these from root:

- **ECS Cluster**: ARN and name
- **Networking**: VPC ID, subnet IDs
- **ALB**: Listener ARN, security group
- **IAM Roles**: Task execution, CodeBuild, CodePipeline
- **KMS Keys**: For encryption
- **SNS Topics**: For notifications
- **Tags**: Common tags for compliance

## Finding Values

### Get CodeConnections ARN

```bash
aws codeconnections list-connections
```

Or in AWS Console: Developer Tools → Connections

### Get Root Infrastructure Outputs

```bash
cd terraform
terraform output
```

### Get Your Account ID

```bash
aws sts get-caller-identity --query Account --output text
```

## Troubleshooting

### "Error: No outputs found"

Root infrastructure not deployed. Deploy it first:

```bash
cd terraform
terraform apply -var-file=environments/develop/terraform.tfvars
```

### "Error: Access Denied" on S3 bucket

Update bucket name in `provider.tf` to match your actual state bucket.

### "Error: Invalid listener ARN"

You may need to add the HTTPS listener output to root `outputs.tf`. Check if `alb_listener_arn` exists:

```bash
cd terraform
terraform output | grep listener
```

If missing, you'll need to add it to the ALB module outputs.

## Alternative: Without Remote State

If you prefer not to use remote state, you can:

1. Keep `variables.tf` 
2. Create `terraform.tfvars` with all values
3. Pass values manually

But this is more work and harder to maintain.
