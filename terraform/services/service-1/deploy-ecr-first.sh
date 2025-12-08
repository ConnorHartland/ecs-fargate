#!/bin/bash
# Deploy ECR repository first, then apply full service configuration
# This ensures the ECR repo exists before CodeBuild tries to push to it

set -e

echo "=========================================="
echo "Deploying service-1 to develop environment"
echo "=========================================="

# Step 1: Initialize Terraform
echo ""
echo "Step 1: Initializing Terraform..."
terraform init -backend-config=backend-develop.hcl -reconfigure

# Step 2: Plan the deployment
echo ""
echo "Step 2: Planning deployment..."
terraform plan -out=tfplan

# Step 3: Apply to create ECR repository and all resources
echo ""
echo "Step 3: Applying configuration..."
terraform apply tfplan

# Step 4: Get ECR repository URL
echo ""
echo "Step 4: Getting ECR repository details..."
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")

if [ -n "$ECR_REPO" ]; then
  echo ""
  echo "=========================================="
  echo "✓ Deployment successful!"
  echo "=========================================="
  echo ""
  echo "ECR Repository: $ECR_REPO"
  echo ""
  echo "Next steps:"
  echo "1. Build and push your Docker image:"
  echo "   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO"
  echo "   docker build -t service-1 ."
  echo "   docker tag service-1:latest $ECR_REPO:latest"
  echo "   docker push $ECR_REPO:latest"
  echo ""
  echo "2. Trigger the pipeline:"
  echo "   aws codepipeline start-pipeline-execution --name service-1-develop"
  echo ""
else
  echo ""
  echo "⚠ Warning: Could not retrieve ECR repository URL"
  echo "Check terraform outputs manually with: terraform output"
fi
