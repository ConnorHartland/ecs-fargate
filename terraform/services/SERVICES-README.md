# Services Deployment Guide

This directory contains configurations for individual microservices deployed to ECS Fargate.

## Available Services

### service-1
- **Type**: Public (ALB-exposed)
- **Runtime**: Node.js
- **Port**: 3000
- **Path**: `/service1/*`
- **Priority**: 101

### service-2
- **Type**: Public (ALB-exposed)
- **Runtime**: Python
- **Port**: 8000
- **Path**: `/service2/*`
- **Priority**: 102

### service-3
- **Type**: Internal (Kafka-based)
- **Runtime**: Node.js
- **Port**: 3000
- **Communication**: Kafka topics

## Prerequisites

Before deploying services, ensure:

1. **Core infrastructure is deployed** (VPC, ECS Cluster, ALB, etc.)
   ```bash
   cd terraform
   terraform apply -var-file="environments/develop/terraform.tfvars"
   ```

2. **Secrets are created in AWS Secrets Manager**:
   - `arn:aws:secretsmanager:REGION:ACCOUNT:secret:ENV/service-1/database-url`
   - `arn:aws:secretsmanager:REGION:ACCOUNT:secret:ENV/service-1/api-key`
   - `arn:aws:secretsmanager:REGION:ACCOUNT:secret:ENV/service-2/database-url`
   - `arn:aws:secretsmanager:REGION:ACCOUNT:secret:ENV/service-2/api-key`
   - `arn:aws:secretsmanager:REGION:ACCOUNT:secret:ENV/service-3/database-url`
   - `arn:aws:secretsmanager:REGION:ACCOUNT:secret:ENV/kafka/username`
   - `arn:aws:secretsmanager:REGION:ACCOUNT:secret:ENV/kafka/password`

3. **Bitbucket repositories exist**:
   - `myorg/service-1`
   - `myorg/service-2`
   - `myorg/service-3`

4. **Update repository URLs** in each service's `main.tf`:
   ```hcl
   repository_url = "your-org/your-repo"
   ```

## Deployment Methods

### Method 1: Deploy All Services (Recommended)

```bash
cd terraform/services
chmod +x deploy-services.sh
./deploy-services.sh develop
```

### Method 2: Deploy Individual Service

```bash
cd terraform/services
./deploy-services.sh develop service-1
```

Or manually:

```bash
cd terraform/services/service-1
terraform init -backend-config=../../environments/develop/backend.hcl
terraform plan -var-file="../../environments/develop/terraform.tfvars"
terraform apply -var-file="../../environments/develop/terraform.tfvars"
```

### Method 3: Deploy from Root (Alternative)

Add services to `terraform/main.tf` and deploy together with core infrastructure.

## Post-Deployment Steps

### 1. Create Secrets in AWS Secrets Manager

```bash
# Service 1 secrets
aws secretsmanager create-secret \
  --name develop/service-1/database-url \
  --secret-string "postgresql://user:pass@host:5432/db"

aws secretsmanager create-secret \
  --name develop/service-1/api-key \
  --secret-string "your-api-key"

# Service 2 secrets
aws secretsmanager create-secret \
  --name develop/service-2/database-url \
  --secret-string "postgresql://user:pass@host:5432/db"

aws secretsmanager create-secret \
  --name develop/service-2/api-key \
  --secret-string "your-api-key"

# Service 3 secrets
aws secretsmanager create-secret \
  --name develop/service-3/database-url \
  --secret-string "postgresql://user:pass@host:5432/db"

# Kafka secrets (shared)
aws secretsmanager create-secret \
  --name develop/kafka/username \
  --secret-string "kafka-user"

aws secretsmanager create-secret \
  --name develop/kafka/password \
  --secret-string "kafka-password"
```

### 2. Push Initial Docker Image to ECR

Each service needs an initial Docker image before the pipeline can run:

```bash
# Get ECR repository URL from Terraform output
ECR_URL=$(cd service-1 && terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL

# Build and push initial image
cd /path/to/service-1-code
docker build -t service-1:latest .
docker tag service-1:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

### 3. Verify Deployment

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster develop-ecs-fargate-cluster \
  --services service-1-develop

# Check running tasks
aws ecs list-tasks \
  --cluster develop-ecs-fargate-cluster \
  --service-name service-1-develop

# View logs
aws logs tail /ecs/service-1-develop --follow

# Test public services
curl https://your-alb-url/service1/health
curl https://your-alb-url/service2/health
```

### 4. Trigger CI/CD Pipeline

Once the initial image is pushed, the pipeline will handle subsequent deployments:

```bash
# Trigger pipeline manually
aws codepipeline start-pipeline-execution \
  --name service-1-develop

# Check pipeline status
aws codepipeline get-pipeline-state \
  --name service-1-develop
```

## Customization

### Modify Service Configuration

Edit the service's `main.tf`:

```hcl
module "service_1" {
  source = "../../modules/service"

  # Change these values as needed
  cpu            = 1024  # Increase CPU
  memory         = 2048  # Increase memory
  desired_count  = 3     # Run more tasks
  autoscaling_max = 10   # Allow more scaling
  
  # Add more environment variables
  environment_variables = {
    NEW_VAR = "value"
  }
}
```

### Add New Service

1. Copy an existing service directory:
   ```bash
   cp -r service-1 service-4
   ```

2. Update `service-4/main.tf`:
   - Change `service_name` to `"service-4"`
   - Update `repository_url`
   - Adjust `path_patterns` and `listener_rule_priority`
   - Modify resource allocations as needed

3. Deploy:
   ```bash
   ./deploy-services.sh develop service-4
   ```

## Troubleshooting

### Service Won't Start

Check task logs:
```bash
aws logs tail /ecs/service-1-develop --follow
```

Common issues:
- Missing secrets in Secrets Manager
- Incorrect environment variables
- Container health check failing
- Insufficient CPU/memory

### Pipeline Fails

Check CodeBuild logs:
```bash
aws codebuild batch-get-builds \
  --ids $(aws codepipeline get-pipeline-state --name service-1-develop \
    --query 'stageStates[?stageName==`Build`].latestExecution.externalExecutionId' \
    --output text)
```

Common issues:
- Bitbucket connection not configured
- Build fails (check buildspec.yml in service repo)
- ECR push permissions

### Can't Access Service via ALB

Check:
- Security group rules allow traffic
- Target group health checks passing
- ALB listener rules configured correctly
- Service is in private subnets with NAT gateway

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups \
    --names service-1-develop-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
```

## Environment Promotion

To promote services across environments:

```bash
# Deploy to test
./deploy-services.sh test

# Deploy to qa
./deploy-services.sh qa

# Deploy to prod (requires manual approval in pipeline)
./deploy-services.sh prod
```

## Cleanup

To destroy a service:

```bash
cd terraform/services/service-1
terraform destroy -var-file="../../environments/develop/terraform.tfvars"
```

**Warning**: This will delete the ECR repository and all container images!
