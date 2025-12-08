#!/bin/bash
# Deploy service-1 to develop environment

set -e

echo "=========================================="
echo "Deploying service-1 to develop"
echo "=========================================="

# Initialize with correct backend
echo "Initializing Terraform..."
terraform init -backend-config=backend-develop.hcl -reconfigure

# Validate configuration
echo "Validating configuration..."
terraform validate

# Plan changes
echo "Planning changes..."
terraform plan -out=tfplan

# Show what will be created
echo ""
echo "Review the plan above. Press Ctrl+C to cancel, or Enter to continue..."
read

# Apply changes
echo "Applying changes..."
terraform apply tfplan

# Clean up
rm -f tfplan

echo ""
echo "=========================================="
echo "✓ service-1 deployed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Push Docker image to ECR:"
echo "   ECR_URL=\$(terraform output -raw ecr_repository_url)"
echo "   docker build -t service-1 ."
echo "   docker tag service-1:latest \$ECR_URL:latest"
echo "   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin \$ECR_URL"
echo "   docker push \$ECR_URL:latest"
echo ""
echo "2. Access your service at:"
echo "   http://ecs-fargate-develop-alb-113241405.us-east-1.elb.amazonaws.com/service1/health"
