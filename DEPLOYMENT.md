# ECS Fargate CI/CD Infrastructure - Deployment Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Infrastructure Deployment](#initial-infrastructure-deployment)
3. [Service Deployment Process](#service-deployment-process)
4. [Environment Promotion Workflow](#environment-promotion-workflow)
5. [Rollback Procedures](#rollback-procedures)
6. [Troubleshooting Guide](#troubleshooting-guide)
7. [Monitoring and Validation](#monitoring-and-validation)

## Prerequisites

### Required Tools

- **Terraform**: v1.5.0 or higher
- **AWS CLI**: v2.x configured with appropriate credentials
- **Git**: For version control
- **Docker**: For local testing (optional)
- **jq**: For JSON parsing in scripts

### AWS Account Setup

1. **AWS Account Access**:
   - IAM user or role with administrative permissions
   - MFA enabled for production access
   - Access keys configured in AWS CLI

2. **Required AWS Services**:
   - ECS Fargate enabled in target region
   - ECR repositories quota sufficient for services
   - VPC quota allows additional VPCs
   - CodePipeline and CodeBuild enabled

3. **External Dependencies**:
   - **Bitbucket Repository**: Source code repositories
   - **CodeConnections**: Configured connection to Bitbucket
   - **ACM Certificate**: SSL/TLS certificate for ALB HTTPS
   - **Kafka Cluster**: External Kafka brokers (for internal services)

4. **Terraform Backend**:
   - S3 bucket for state storage
   - DynamoDB table for state locking
   - KMS key for state encryption

### Initial Configuration

```bash
# Configure AWS CLI
aws configure
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region name: us-east-1
# Default output format: json

# Verify AWS access
aws sts get-caller-identity
# Enable MFA for production (required for compliance)
aws iam enable-mfa-device --user-name [your-username] --serial-number [mfa-arn] --authentication-code1 [code1] --authentication-code2 [code2]
```

## Initial Infrastructure Deployment

### Step 1: Bootstrap Terraform Backend

Before deploying any infrastructure, set up the Terraform backend for state management.

```bash
# Navigate to terraform directory
cd terraform

# Run bootstrap script to create S3 bucket and DynamoDB table
./scripts/bootstrap-backend.sh

# Expected output:
# - S3 bucket: terraform-state-[account-id]-[region]
# - DynamoDB table: terraform-state-lock
# - KMS key: alias/terraform-state
```

**Bootstrap Script Details**:
- Creates encrypted S3 bucket with versioning
- Creates DynamoDB table for state locking
- Creates KMS key for encryption
- Configures bucket policies for secure access

### Step 2: Initialize Terraform

```bash
# Initialize Terraform with backend configuration
# Use the environment-specific backend config file
terraform init -backend-config=environments/develop/backend.hcl

# Or initialize with inline backend config
terraform init \
  -backend-config="bucket=ecs-fargate-terraform-state" \
  -backend-config="key=develop/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=ecs-fargate-terraform-state-lock" \
  -backend-config="encrypt=true"

# Note: You may see a deprecation warning about dynamodb_table parameter.
# This is expected and will be addressed in future Terraform versions.

# Verify initialization
terraform version
terraform providers
```

### Step 3: Deploy Core Infrastructure (Networking & Security)

Deploy foundational infrastructure in the following order:

```bash
# Set environment variable
export ENVIRONMENT=develop

# Create terraform.tfvars for the environment
cat > environments/${ENVIRONMENT}/terraform.tfvars <<EOF
environment = "${ENVIRONMENT}"
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Mandatory compliance tags
mandatory_tags = {
  Environment = "${ENVIRONMENT}"
  Owner       = "platform-team"
  CostCenter  = "engineering"
  Compliance  = "NIST-SOC2"
}

# Kafka configuration (external)
kafka_brokers = ["kafka-broker-1:9092", "kafka-broker-2:9092", "kafka-broker-3:9092"]
kafka_security_group_id = "sg-xxxxxxxxx"

# ACM certificate for ALB
acm_certificate_arn = "arn:aws:acm:us-east-1:xxxx:certificate/xxxx"
EOF

# Plan deployment
terraform plan -var-file="environments/${ENVIRONMENT}/terraform.tfvars" -out=tfplan

# Review the plan carefully
# Verify:
# - VPC and subnets are created correctly
# - Security groups have appropriate rules
# - KMS keys are created for encryption
# - IAM roles follow least privilege

# Apply the plan
terraform apply tfplan
```

**Expected Resources Created**:
- VPC with DNS support
- 3 public subnets (for ALB and NAT gateways)
- 3 private subnets (for ECS tasks)
- Internet Gateway
- 3 NAT Gateways (high availability)
- Route tables
- VPC Flow Logs
- KMS keys (ECS, ECR, Secrets, CloudWatch, S3)
- Security groups (ALB, public services, internal services)
- ECS cluster
- CloudWatch log groups
- CloudTrail
- AWS Config recorder

**Deployment Time**: Approximately 10-15 minutes

### Step 4: Configure Secrets Manager

Create secrets for services before deploying them:

```bash
# Create a secret for a service
aws secretsmanager create-secret \
  --name ${ENVIRONMENT}/service-name/database \
  --description "Database credentials for service-name" \
  --kms-key-id alias/secrets-${ENVIRONMENT} \
  --secret-string '{
    "username": "dbuser",
    "password": "secure-password-here",
    "host": "database.example.com",
    "port": "5432",
    "database": "mydb"
  }'

# Tag the secret
aws secretsmanager tag-resource \
  --secret-id ${ENVIRONMENT}/service-name/database \
  --tags Key=Environment,Value=${ENVIRONMENT} \
         Key=Service,Value=service-name \
         Key=Compliance,Value=NIST-SOC2

# Verify secret creation
aws secretsmanager describe-secret --secret-id ${ENVIRONMENT}/service-name/database
```

### Step 5: Configure CodeConnections

Set up connection to Bitbucket for CI/CD pipelines:

```bash
# Create CodeConnections connection (via AWS Console or CLI)
aws codestar-connections create-connection \
  --provider-type Bitbucket \
  --connection-name bitbucket-connection

# Note the connection ARN from output
# Complete the OAuth handshake in AWS Console:
# 1. Go to Developer Tools > Connections
# 2. Click on the pending connection
# 3. Click "Update pending connection"
# 4. Authorize with Bitbucket

# Verify connection is available
aws codestar-connections get-connection --connection-arn [connection-arn]
```

### Step 6: Validate Core Infrastructure

```bash
# Check VPC
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=${ENVIRONMENT}"

# Check ECS cluster
aws ecs describe-clusters --clusters ${ENVIRONMENT}-cluster

# Check security groups
aws ec2 describe-security-groups --filters "Name=tag:Environment,Values=${ENVIRONMENT}"

# Check KMS keys
aws kms list-aliases | grep ${ENVIRONMENT}

# Check CloudTrail
aws cloudtrail describe-trails --trail-name-list ${ENVIRONMENT}-audit-trail
```

## Service Deployment Process

### Deploying a New Service

Follow these steps to deploy a new microservice:

#### 1. Prepare Service Configuration

Create a service configuration file:

```bash
# Create service directory
mkdir -p terraform/services/my-service

# Create main.tf for the service
cat > terraform/services/my-service/main.tf <<'EOF'
module "my_service" {
  source = "../../modules/service"

  service_name    = "my-service"
  runtime         = "nodejs"  # or "python"
  service_type    = "public"  # or "internal"
  repository_url  = "https://bitbucket.org/myorg/my-service"
  branch_pattern  = "feature/*"  # develop environment

  # Resource configuration
  container_port  = 3000
  cpu             = 256
  memory          = 512
  desired_count   = 2
  autoscaling_min = 1
  autoscaling_max = 10

  # Health check (for public services)
  health_check_path = "/health"

  # Environment and networking
  environment            = var.environment
  vpc_id                 = module.networking.vpc_id
  private_subnet_ids     = module.networking.private_subnet_ids
  public_subnet_ids      = module.networking.public_subnet_ids
  alb_security_group_id  = module.networking.alb_security_group_id
  cluster_id             = module.ecs_cluster.cluster_id
  cluster_name           = module.ecs_cluster.cluster_name

  # Secrets
  secrets_arns = [
    aws_secretsmanager_secret.my_service_db.arn,
    aws_secretsmanager_secret.my_service_api_key.arn
  ]

  # CI/CD
  codeconnections_arn = var.codeconnections_arn
  
  # ALB (for public services)
  alb_listener_arn = module.alb.https_listener_arn
  alb_dns_name     = module.alb.dns_name

  # Tags
  tags = var.mandatory_tags
}
EOF
```

#### 2. Create Service Secrets

```bash
# Create database secret
aws secretsmanager create-secret \
  --name ${ENVIRONMENT}/my-service/database \
  --kms-key-id alias/secrets-${ENVIRONMENT} \
  --secret-string '{"username":"user","password":"pass","host":"db.example.com"}'

# Create API key secret
aws secretsmanager create-secret \
  --name ${ENVIRONMENT}/my-service/api-key \
  --kms-key-id alias/secrets-${ENVIRONMENT} \
  --secret-string '{"api_key":"your-api-key-here"}'
```

#### 3. Deploy Service Infrastructure

```bash
# Navigate to service directory
cd terraform/services/my-service

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="../../environments/${ENVIRONMENT}/terraform.tfvars"

# Apply deployment
terraform apply -var-file="../../environments/${ENVIRONMENT}/terraform.tfvars"
```

**Resources Created**:
- ECR repository
- ECS task definition
- ECS service
- IAM roles (task execution, task role)
- Security group
- CloudWatch log group
- CodePipeline
- CodeBuild project
- Target group and listener rule (if public)
- Auto-scaling policies
- CloudWatch alarms


#### 4. Build and Push Initial Docker Image

```bash
# Get ECR repository URL from Terraform output
ECR_REPO=$(terraform output -raw ecr_repository_url)

# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REPO}

# Build Docker image locally (from service repository)
cd /path/to/service/repository
docker build -t my-service:latest .

# Tag image for ECR
docker tag my-service:latest ${ECR_REPO}:latest
docker tag my-service:latest ${ECR_REPO}:${ENVIRONMENT}-initial

# Push image to ECR
docker push ${ECR_REPO}:latest
docker push ${ECR_REPO}:${ENVIRONMENT}-initial

# Verify image in ECR
aws ecr describe-images --repository-name my-service
```

#### 5. Trigger Initial Deployment

```bash
# Update ECS service to use the new image
aws ecs update-service \
  --cluster ${ENVIRONMENT}-cluster \
  --service my-service \
  --force-new-deployment

# Monitor deployment
aws ecs describe-services \
  --cluster ${ENVIRONMENT}-cluster \
  --services my-service \
  --query 'services[0].deployments'
```

#### 6. Verify Service Health

```bash
# Check task status
aws ecs list-tasks --cluster ${ENVIRONMENT}-cluster --service-name my-service
aws ecs describe-tasks --cluster ${ENVIRONMENT}-cluster --tasks [task-arn]

# Check CloudWatch logs
aws logs tail /ecs/my-service --follow

# For public services, check ALB target health
aws elbv2 describe-target-health --target-group-arn [target-group-arn]

# Test service endpoint (public services)
curl https://[alb-dns-name]/my-service/health
```

### Service Configuration Examples

#### Example 1: Node.js Public Service

```hcl
module "api_gateway" {
  source = "../../modules/service"

  service_name      = "api-gateway"
  runtime           = "nodejs"
  service_type      = "public"
  repository_url    = "https://bitbucket.org/myorg/api-gateway"
  branch_pattern    = "feature/*"
  container_port    = 3000
  cpu               = 512
  memory            = 1024
  desired_count     = 3
  autoscaling_min   = 2
  autoscaling_max   = 20
  health_check_path = "/api/health"
  
  environment = var.environment
  # ... other required variables
}
```

#### Example 2: Python Internal Service

```hcl
module "data_processor" {
  source = "../../modules/service"

  service_name    = "data-processor"
  runtime         = "python"
  service_type    = "internal"
  repository_url  = "https://bitbucket.org/myorg/data-processor"
  branch_pattern  = "feature/*"
  container_port  = 8000
  cpu             = 1024
  memory          = 2048
  desired_count   = 2
  autoscaling_min = 1
  autoscaling_max = 10
  
  environment = var.environment
  # ... other required variables
}
```


## Environment Promotion Workflow

### Overview

Code flows through environments in this order:
1. **Develop** (feature/* branches) - Manual trigger
2. **Test** (release/*.*.* branches) - Automatic deployment
3. **QA** (release/*.*.* branches) - Automatic deployment
4. **Production** (prod/* branches) - Manual approval required

### Develop Environment Deployment

**Branch Pattern**: `feature/*`
**Trigger**: Manual

```bash
# Developer creates feature branch
git checkout -b feature/new-feature

# Make changes and commit
git add .
git commit -m "Add new feature"
git push origin feature/new-feature

# Manually trigger pipeline in AWS Console:
# 1. Go to CodePipeline
# 2. Find pipeline: my-service-develop
# 3. Click "Release change"

# Or trigger via CLI
aws codepipeline start-pipeline-execution \
  --name my-service-develop
```

**Validation Steps**:
1. Monitor pipeline execution in AWS Console
2. Check CodeBuild logs for build success
3. Verify ECS service deployment completes
4. Test functionality in develop environment
5. Check CloudWatch logs for errors

### Test/QA Environment Deployment

**Branch Pattern**: `release/*.*.*` (e.g., release/1.2.0)
**Trigger**: Automatic on push

```bash
# Create release branch from main/master
git checkout main
git pull origin main
git checkout -b release/1.2.0

# Merge feature branches
git merge feature/feature-1
git merge feature/feature-2

# Push release branch (triggers automatic deployment)
git push origin release/1.2.0

# Pipeline automatically:
# 1. Detects push to release/* branch
# 2. Runs CodeBuild to build and test
# 3. Pushes image to ECR with tags: commit-sha, release-1.2.0, test-latest
# 4. Deploys to TEST environment
# 5. Deploys to QA environment
# 6. Sends SNS notification on completion
```

**Validation Steps**:
1. Monitor pipeline in AWS Console
2. Verify deployment to TEST environment
3. Run automated test suite
4. Perform manual QA testing
5. Verify deployment to QA environment
6. Conduct user acceptance testing

### Production Deployment

**Branch Pattern**: `prod/*` (e.g., prod/1.2.0)
**Trigger**: Manual approval required

```bash
# Create production branch from tested release
git checkout release/1.2.0
git checkout -b prod/1.2.0

# Push to trigger production pipeline
git push origin prod/1.2.0

# Pipeline workflow:
# 1. Source stage: Detects push to prod/* branch
# 2. Build stage: Builds and scans image
# 3. Approval stage: WAITS for manual approval
# 4. Deploy stage: Deploys to production (after approval)
```

**Approval Process**:

```bash
# Approvers receive SNS notification via email/Slack

# Review deployment in AWS Console:
# 1. Go to CodePipeline
# 2. Find pipeline: my-service-prod
# 3. Review approval stage
# 4. Check build artifacts and test results
# 5. Click "Review" and approve or reject

# Or approve via CLI
aws codepipeline put-approval-result \
  --pipeline-name my-service-prod \
  --stage-name Approval \
  --action-name ManualApproval \
  --result status=Approved,summary="Approved by [name] after validation" \
  --token [approval-token]
```

**Post-Deployment Validation**:
1. Monitor ECS service deployment progress
2. Check CloudWatch alarms for any triggers
3. Verify ALB target health
4. Test critical user flows
5. Monitor error rates and latency
6. Check application logs for errors
7. Validate with smoke tests

### Environment-Specific Configurations

Each environment has different settings:

| Configuration | Develop | Test/QA | Production |
|--------------|---------|---------|------------|
| Desired Count | 1-2 | 2-3 | 3+ |
| Auto-scaling Min | 1 | 2 | 3 |
| Auto-scaling Max | 5 | 10 | 20 |
| Log Retention | 7 days | 30 days | 90 days |
| Deletion Protection | Disabled | Disabled | Enabled |
| Fargate Spot | 70% | 30% | 0% |
| MFA Required | No | No | Yes |
| Approval Required | No | No | Yes |


## Rollback Procedures

### Automatic Rollback

ECS automatically rolls back failed deployments when:
- New tasks fail to start within timeout (15 minutes)
- Health checks fail consistently
- Deployment circuit breaker triggers

**Monitor Automatic Rollback**:
```bash
# Watch deployment events
aws ecs describe-services \
  --cluster ${ENVIRONMENT}-cluster \
  --services my-service \
  --query 'services[0].events[0:10]'

# Check for rollback messages like:
# "service my-service has reached a steady state"
# "deployment rolled back due to failed health checks"
```

### Manual Rollback - Method 1: Redeploy Previous Task Definition

```bash
# List task definition revisions
aws ecs list-task-definitions \
  --family-prefix my-service \
  --sort DESC

# Identify the last known good revision (e.g., my-service:42)

# Update service to use previous task definition
aws ecs update-service \
  --cluster ${ENVIRONMENT}-cluster \
  --service my-service \
  --task-definition my-service:42 \
  --force-new-deployment

# Monitor rollback
aws ecs describe-services \
  --cluster ${ENVIRONMENT}-cluster \
  --services my-service \
  --query 'services[0].deployments'
```

### Manual Rollback - Method 2: Redeploy Previous Image

```bash
# List ECR images with tags
aws ecr describe-images \
  --repository-name my-service \
  --query 'sort_by(imageDetails,& imagePushedAt)[*].[imageTags[0], imagePushedAt]' \
  --output table

# Identify previous working image tag (e.g., abc123f)

# Update task definition to use previous image
# Create new task definition revision with old image
aws ecs register-task-definition \
  --cli-input-json file://task-definition-rollback.json

# Update service
aws ecs update-service \
  --cluster ${ENVIRONMENT}-cluster \
  --service my-service \
  --task-definition my-service:43 \
  --force-new-deployment
```

### Manual Rollback - Method 3: Revert Git and Redeploy

```bash
# Identify the commit to revert to
git log --oneline

# Create revert branch
git checkout prod/1.2.0
git revert [bad-commit-sha]
git push origin prod/1.2.0

# Or create new branch with previous good commit
git checkout [good-commit-sha]
git checkout -b prod/1.2.0-rollback
git push origin prod/1.2.0-rollback

# Pipeline will automatically build and deploy the reverted code
# Approve the deployment when ready
```

### Emergency Rollback - Scale to Zero and Redeploy

For critical issues requiring immediate action:

```bash
# Scale service to zero tasks
aws ecs update-service \
  --cluster ${ENVIRONMENT}-cluster \
  --service my-service \
  --desired-count 0

# Wait for tasks to stop
aws ecs wait services-stable \
  --cluster ${ENVIRONMENT}-cluster \
  --services my-service

# Update to previous task definition
aws ecs update-service \
  --cluster ${ENVIRONMENT}-cluster \
  --service my-service \
  --task-definition my-service:42 \
  --desired-count 3

# Monitor recovery
watch -n 5 'aws ecs describe-services --cluster ${ENVIRONMENT}-cluster --services my-service --query "services[0].runningCount"'
```

### Rollback Validation Checklist

After any rollback:

- [ ] Verify correct task definition is running
- [ ] Check all tasks are healthy
- [ ] Verify ALB target health (public services)
- [ ] Test critical functionality
- [ ] Check CloudWatch logs for errors
- [ ] Monitor CloudWatch alarms
- [ ] Verify metrics return to normal
- [ ] Document rollback reason and actions taken
- [ ] Create incident report
- [ ] Plan fix for rolled-back issue


## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Tasks Fail to Start

**Symptoms**:
- ECS service shows tasks in PENDING or STOPPED state
- Deployment never reaches steady state
- CloudWatch shows task stopped events

**Diagnosis**:
```bash
# Check stopped tasks
aws ecs list-tasks \
  --cluster ${ENVIRONMENT}-cluster \
  --service-name my-service \
  --desired-status STOPPED

# Get detailed task information
aws ecs describe-tasks \
  --cluster ${ENVIRONMENT}-cluster \
  --tasks [task-arn] \
  --query 'tasks[0].{StopCode:stopCode,StopReason:stoppedReason,Containers:containers[*].{Name:name,Reason:reason,ExitCode:exitCode}}'
```

**Common Causes and Solutions**:

1. **Image Pull Error**:
   ```
   StopReason: "CannotPullContainerError: Error response from daemon"
   ```
   - Verify ECR repository exists and image is pushed
   - Check task execution role has ECR pull permissions
   - Verify image tag exists in ECR

2. **Insufficient Memory**:
   ```
   StopReason: "OutOfMemoryError: Container killed due to memory usage"
   ```
   - Increase memory allocation in task definition
   - Check application memory leaks
   - Review CloudWatch Container Insights

3. **Secret Not Found**:
   ```
   StopReason: "ResourceInitializationError: unable to pull secrets"
   ```
   - Verify secret exists in Secrets Manager
   - Check task execution role has GetSecretValue permission
   - Verify secret ARN is correct in task definition

4. **Health Check Failures**:
   ```
   StopReason: "Task failed ELB health checks"
   ```
   - Verify health check endpoint returns 200 OK
   - Check health check path configuration
   - Increase health check grace period
   - Review application startup time

#### Issue 2: Pipeline Failures

**Build Stage Failures**:

```bash
# Check CodeBuild logs
aws codebuild batch-get-builds --ids [build-id]

# View detailed logs
aws logs tail /aws/codebuild/my-service-build --follow
```

**Common Build Failures**:

1. **Docker Build Fails**:
   - Check Dockerfile syntax
   - Verify base image is accessible
   - Check for missing dependencies
   - Review build logs for specific errors

2. **Tests Fail**:
   - Review test output in CodeBuild logs
   - Run tests locally to reproduce
   - Check environment variables are set correctly

3. **Security Scan Finds Vulnerabilities**:
   - Review trivy scan results
   - Update vulnerable dependencies
   - Add exceptions for false positives (with justification)

4. **ECR Push Fails**:
   ```
   Error: denied: User is not authorized to perform: ecr:PutImage
   ```
   - Verify CodeBuild role has ECR push permissions
   - Check ECR repository policy
   - Verify repository exists

**Source Stage Failures**:

```bash
# Check CodeConnections status
aws codestar-connections get-connection --connection-arn [connection-arn]
```

Solutions:
- Re-authenticate CodeConnections in AWS Console
- Verify Bitbucket repository access
- Check branch pattern matches configuration

#### Issue 3: Service Not Receiving Traffic

**Symptoms**:
- Service is running but ALB returns 503 errors
- Target group shows unhealthy targets
- No traffic reaching containers

**Diagnosis**:
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn [target-group-arn]

# Check security group rules
aws ec2 describe-security-groups --group-ids [task-sg-id] [alb-sg-id]

# Check service network configuration
aws ecs describe-services \
  --cluster ${ENVIRONMENT}-cluster \
  --services my-service \
  --query 'services[0].networkConfiguration'
```

**Solutions**:

1. **Unhealthy Targets**:
   - Verify health check endpoint is accessible
   - Check application logs for errors
   - Verify container port matches target group port
   - Increase health check interval or reduce thresholds

2. **Security Group Misconfiguration**:
   - Ensure task security group allows inbound from ALB security group
   - Verify ALB security group allows inbound 80/443 from internet
   - Check outbound rules allow responses

3. **Wrong Subnets**:
   - Verify tasks are in private subnets
   - Verify ALB is in public subnets
   - Check route tables are configured correctly


#### Issue 4: High CPU or Memory Utilization

**Symptoms**:
- CloudWatch alarms triggering
- Tasks being killed and restarted
- Slow response times

**Diagnosis**:
```bash
# Check service metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=my-service Name=ClusterName,Value=${ENVIRONMENT}-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average Maximum

# Check Container Insights
# Go to CloudWatch Console > Container Insights > ECS Services
```

**Solutions**:

1. **Increase Resources**:
   ```bash
   # Update task definition with higher CPU/memory
   # Then update service
   aws ecs update-service \
     --cluster ${ENVIRONMENT}-cluster \
     --service my-service \
     --force-new-deployment
   ```

2. **Optimize Application**:
   - Profile application to find bottlenecks
   - Optimize database queries
   - Add caching where appropriate
   - Review memory leaks

3. **Scale Horizontally**:
   ```bash
   # Increase desired count
   aws ecs update-service \
     --cluster ${ENVIRONMENT}-cluster \
     --service my-service \
     --desired-count 5
   
   # Or adjust auto-scaling thresholds
   aws application-autoscaling put-scaling-policy \
     --policy-name my-service-cpu-scaling \
     --service-namespace ecs \
     --resource-id service/${ENVIRONMENT}-cluster/my-service \
     --scalable-dimension ecs:service:DesiredCount \
     --policy-type TargetTrackingScaling \
     --target-tracking-scaling-policy-configuration file://scaling-policy.json
   ```

#### Issue 5: Secrets Not Accessible

**Symptoms**:
- Tasks fail with "ResourceInitializationError"
- Application logs show missing environment variables
- Authentication failures

**Diagnosis**:
```bash
# Check secret exists
aws secretsmanager describe-secret --secret-id ${ENVIRONMENT}/my-service/database

# Check task role permissions
aws iam get-role-policy \
  --role-name my-service-task-role \
  --policy-name secrets-access

# Check task definition secrets configuration
aws ecs describe-task-definition \
  --task-definition my-service \
  --query 'taskDefinition.containerDefinitions[0].secrets'
```

**Solutions**:

1. **Secret Doesn't Exist**:
   ```bash
   # Create the secret
   aws secretsmanager create-secret \
     --name ${ENVIRONMENT}/my-service/database \
     --secret-string '{"key":"value"}'
   ```

2. **Permission Denied**:
   ```bash
   # Update task role policy
   aws iam put-role-policy \
     --role-name my-service-task-role \
     --policy-name secrets-access \
     --policy-document file://secrets-policy.json
   ```

3. **Wrong Secret ARN**:
   - Verify ARN in task definition matches actual secret
   - Update task definition with correct ARN
   - Redeploy service

#### Issue 6: Deployment Stuck

**Symptoms**:
- Deployment shows "IN_PROGRESS" for extended time
- New tasks start but old tasks don't stop
- Service never reaches steady state

**Diagnosis**:
```bash
# Check deployment status
aws ecs describe-services \
  --cluster ${ENVIRONMENT}-cluster \
  --services my-service \
  --query 'services[0].deployments'

# Check service events
aws ecs describe-services \
  --cluster ${ENVIRONMENT}-cluster \
  --services my-service \
  --query 'services[0].events[0:20]'
```

**Solutions**:

1. **Force New Deployment**:
   ```bash
   aws ecs update-service \
     --cluster ${ENVIRONMENT}-cluster \
     --service my-service \
     --force-new-deployment
   ```

2. **Stop Old Tasks Manually**:
   ```bash
   # List running tasks
   aws ecs list-tasks --cluster ${ENVIRONMENT}-cluster --service-name my-service
   
   # Stop old tasks (from previous deployment)
   aws ecs stop-task --cluster ${ENVIRONMENT}-cluster --task [old-task-arn]
   ```

3. **Adjust Deployment Configuration**:
   - Reduce minimum_healthy_percent temporarily
   - Increase deployment timeout
   - Check if capacity is available


#### Issue 7: S3 Backend Region Mismatch

**Symptoms**:
- Terraform init fails with "requested bucket from X, actual location Y"
- Error message shows 301 redirect from S3

**Diagnosis**:
```bash
# Check actual bucket region
aws s3api get-bucket-location --bucket ecs-fargate-terraform-state
```

**Solutions**:

1. **Update Backend Configuration**:
   - Edit the backend.hcl file for your environment
   - Change the `region` parameter to match the actual bucket location
   - Re-run `terraform init -backend-config=environments/[env]/backend.hcl`

2. **Verify All Environment Configs**:
   ```bash
   # Check all backend configs have correct region
   grep -r "region" terraform/environments/*/backend.hcl
   ```

#### Issue 8: Terraform State Lock

**Symptoms**:
- Terraform commands fail with "Error acquiring the state lock"
- Multiple users trying to apply changes simultaneously

**Diagnosis**:
```bash
# Check DynamoDB for lock
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"terraform-state-bucket/infrastructure/terraform.tfstate-md5"}}'
```

**Solutions**:

1. **Wait for Lock to Release**:
   - Another operation is in progress
   - Wait for it to complete

2. **Force Unlock (Use with Caution)**:
   ```bash
   # Only if you're certain no other operation is running
   terraform force-unlock [lock-id]
   ```

3. **Remove Stale Lock**:
   ```bash
   # If lock is truly stale (operation crashed)
   aws dynamodb delete-item \
     --table-name terraform-state-lock \
     --key '{"LockID":{"S":"[lock-id]"}}'
   ```

#### Issue 9: Kafka Connectivity Issues (Internal Services)

**Symptoms**:
- Internal services can't connect to Kafka
- Connection timeout errors in logs
- Messages not being produced/consumed

**Diagnosis**:
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids [task-sg-id]

# Check network configuration
aws ecs describe-services \
  --cluster ${ENVIRONMENT}-cluster \
  --services my-internal-service \
  --query 'services[0].networkConfiguration'

# Test connectivity from task
aws ecs execute-command \
  --cluster ${ENVIRONMENT}-cluster \
  --task [task-arn] \
  --container my-internal-service \
  --interactive \
  --command "/bin/sh"

# Inside container:
nc -zv kafka-broker-1 9092
```

**Solutions**:

1. **Security Group Rules**:
   - Ensure task security group allows outbound to Kafka ports
   - Ensure Kafka security group allows inbound from task security group

2. **Network Configuration**:
   - Verify tasks are in correct subnets with route to Kafka
   - Check NAT gateway if Kafka is external
   - Verify DNS resolution for Kafka brokers

3. **Kafka Configuration**:
   - Verify Kafka broker addresses are correct
   - Check Kafka authentication credentials
   - Verify Kafka is accessible from VPC

### Debugging Tools and Commands

#### Enable ECS Exec for Interactive Debugging

```bash
# Update service to enable execute command
aws ecs update-service \
  --cluster ${ENVIRONMENT}-cluster \
  --service my-service \
  --enable-execute-command

# Connect to running task
aws ecs execute-command \
  --cluster ${ENVIRONMENT}-cluster \
  --task [task-arn] \
  --container my-service \
  --interactive \
  --command "/bin/bash"

# Inside container, you can:
# - Check environment variables: env
# - Test network connectivity: curl, nc, ping
# - Check processes: ps aux
# - View logs: cat /var/log/*
# - Test application: curl localhost:3000/health
```

#### CloudWatch Logs Insights Queries

```bash
# Find errors in last hour
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100

# Find slow requests
fields @timestamp, duration, path
| filter duration > 1000
| sort duration desc
| limit 50

# Count errors by type
fields @timestamp, error_type
| filter @message like /ERROR/
| stats count() by error_type
```

#### Useful AWS CLI Commands

```bash
# Get service status summary
aws ecs describe-services \
  --cluster ${ENVIRONMENT}-cluster \
  --services my-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}'

# List all services in cluster
aws ecs list-services --cluster ${ENVIRONMENT}-cluster

# Get task definition details
aws ecs describe-task-definition --task-definition my-service:latest

# Check pipeline status
aws codepipeline get-pipeline-state --name my-service-prod

# List recent CloudTrail events
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=my-service \
  --max-results 10
```


## Monitoring and Validation

### CloudWatch Dashboards

Access pre-configured dashboards:

1. **Cluster Overview Dashboard**:
   - Navigate to CloudWatch > Dashboards > `${ENVIRONMENT}-cluster-overview`
   - Metrics: Total tasks, CPU/memory utilization, task failures

2. **Service-Specific Dashboard**:
   - Navigate to CloudWatch > Dashboards > `${ENVIRONMENT}-my-service`
   - Metrics: Request count, latency, error rate, task count

3. **Pipeline Dashboard**:
   - Navigate to CloudWatch > Dashboards > `${ENVIRONMENT}-pipelines`
   - Metrics: Build success rate, deployment frequency, failure rate

### Key Metrics to Monitor

#### Service Health Metrics

```bash
# CPU Utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=my-service Name=ClusterName,Value=${ENVIRONMENT}-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Memory Utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=my-service Name=ClusterName,Value=${ENVIRONMENT}-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Task Count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name RunningTaskCount \
  --dimensions Name=ServiceName,Value=my-service Name=ClusterName,Value=${ENVIRONMENT}-cluster \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

#### ALB Metrics (Public Services)

```bash
# Target Response Time
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=[alb-name] Name=TargetGroup,Value=[tg-name] \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# HTTP 5xx Errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=[alb-name] \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Healthy Host Count
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HealthyHostCount \
  --dimensions Name=TargetGroup,Value=[tg-arn] \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average
```

### CloudWatch Alarms

#### Critical Alarms (PagerDuty)

Monitor these alarms 24/7:

1. **Service Task Count Below Minimum**:
   - Triggers when running tasks < desired count for 5 minutes
   - Action: Investigate why tasks are failing

2. **High Task Failure Rate**:
   - Triggers when > 2 tasks fail in 5 minutes
   - Action: Check CloudWatch logs for errors

3. **ALB 5xx Error Rate High**:
   - Triggers when 5xx errors > 5% of requests
   - Action: Check service health and logs

4. **Production Pipeline Failure**:
   - Triggers on any production pipeline failure
   - Action: Review pipeline logs and fix issues

#### Warning Alarms (Email)

Monitor during business hours:

1. **High CPU Utilization**:
   - Triggers when CPU > 80% for 5 minutes
   - Action: Consider scaling or optimization

2. **High Memory Utilization**:
   - Triggers when memory > 80% for 5 minutes
   - Action: Check for memory leaks or increase allocation

3. **Unhealthy Targets**:
   - Triggers when any target is unhealthy
   - Action: Check health check endpoint

4. **Build Failures (Non-Production)**:
   - Triggers on develop/test build failures
   - Action: Review build logs

### Validation Checklist

After any deployment, verify:

#### Infrastructure Validation

- [ ] VPC and subnets created correctly
- [ ] Security groups have appropriate rules
- [ ] NAT gateways are operational
- [ ] Route tables configured correctly
- [ ] VPC Flow Logs enabled
- [ ] KMS keys created and accessible
- [ ] IAM roles have correct permissions
- [ ] CloudTrail logging enabled
- [ ] AWS Config recording enabled

#### Service Validation

- [ ] ECR repository exists with images
- [ ] ECS service is running
- [ ] Desired task count matches running count
- [ ] All tasks are healthy
- [ ] CloudWatch log group receiving logs
- [ ] No errors in CloudWatch logs
- [ ] Secrets are accessible to tasks
- [ ] Auto-scaling policies configured

#### Public Service Validation

- [ ] ALB is operational
- [ ] Target group has healthy targets
- [ ] Listener rules route correctly
- [ ] HTTPS certificate is valid
- [ ] Health checks passing
- [ ] Service responds to requests
- [ ] No 5xx errors

#### Internal Service Validation

- [ ] Service can connect to Kafka
- [ ] Messages being produced/consumed
- [ ] No connection errors in logs
- [ ] Security groups allow Kafka traffic

#### CI/CD Validation

- [ ] CodePipeline created
- [ ] CodeBuild project configured
- [ ] CodeConnections authenticated
- [ ] Pipeline can be triggered
- [ ] Build succeeds
- [ ] Deployment completes
- [ ] SNS notifications working

### Health Check Endpoints

All services should implement these endpoints:

```
GET /health
Response: 200 OK
Body: {"status": "healthy", "timestamp": "2024-01-01T00:00:00Z"}

GET /ready
Response: 200 OK (when ready to receive traffic)
Body: {"status": "ready", "dependencies": {"database": "ok", "kafka": "ok"}}

GET /metrics
Response: 200 OK
Body: Prometheus-format metrics
```

### Log Analysis

#### Common Log Patterns to Monitor

1. **Application Errors**:
   ```
   ERROR|Exception|Failed|Timeout|Connection refused
   ```

2. **Performance Issues**:
   ```
   Slow query|High latency|Timeout|Request took
   ```

3. **Security Events**:
   ```
   Unauthorized|Forbidden|Authentication failed|Invalid token
   ```

4. **Deployment Events**:
   ```
   Starting|Stopping|Deployment|Health check
   ```

### Cost Monitoring

Monitor costs to stay within budget:

```bash
# Get cost by service (requires Cost Explorer API)
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Service

# Check Fargate usage
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter file://fargate-filter.json
```

**Cost Optimization Tips**:
- Use Fargate Spot for non-production (up to 70% savings)
- Right-size CPU and memory allocations
- Implement auto-scaling to match demand
- Set appropriate log retention periods
- Use ECR lifecycle policies to remove old images
- Monitor and delete unused resources

---

## Additional Resources

### Documentation Links

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS Fargate Documentation](https://docs.aws.amazon.com/fargate/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/)
- [CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)

### Support Contacts

- **Platform Team**: platform-team@example.com
- **Security Team**: security@example.com
- **On-Call**: Use PagerDuty for critical issues
- **Slack Channels**: #platform-support, #deployments, #incidents

### Compliance Documentation

- NIST Controls Mapping: See `docs/compliance/nist-mapping.md`
- SOC-2 Evidence: See `docs/compliance/soc2-evidence.md`
- Audit Procedures: See `docs/compliance/audit-procedures.md`

---

**Document Version**: 1.0
**Last Updated**: 2024-01-01
**Maintained By**: Platform Engineering Team
