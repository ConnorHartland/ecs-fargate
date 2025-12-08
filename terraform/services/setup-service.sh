#!/bin/bash
# Helper script to set up service configuration
# Usage: ./setup-service.sh <service-name> <environment>
# Example: ./setup-service.sh service-1 develop

set -e

SERVICE_NAME=${1}
ENVIRONMENT=${2:-develop}

if [ -z "$SERVICE_NAME" ]; then
  echo "Error: Service name required"
  echo "Usage: ./setup-service.sh <service-name> <environment>"
  exit 1
fi

if [ ! -d "$SERVICE_NAME" ]; then
  echo "Error: Service directory $SERVICE_NAME not found"
  exit 1
fi

echo "=========================================="
echo "Setting up $SERVICE_NAME for $ENVIRONMENT"
echo "=========================================="

cd "$SERVICE_NAME"

# Check if root infrastructure is deployed
echo ""
echo "Checking root infrastructure..."
cd ../../
if ! terraform output > /dev/null 2>&1; then
  echo "Error: Root infrastructure not deployed or outputs not available"
  echo "Please deploy root infrastructure first:"
  echo "  cd terraform"
  echo "  terraform init -backend-config=environments/$ENVIRONMENT/backend.hcl"
  echo "  terraform apply -var-file=environments/$ENVIRONMENT/terraform.tfvars"
  exit 1
fi

echo "✓ Root infrastructure found"
echo ""
echo "Available outputs from root infrastructure:"
echo "  - ECS Cluster: $(terraform output -raw ecs_cluster_name)"
echo "  - VPC ID: $(terraform output -raw vpc_id)"
echo "  - ALB DNS: $(terraform output -raw alb_dns_name)"
echo ""

cd "services/$SERVICE_NAME"

echo "=========================================="
echo "Configuration Checklist"
echo "=========================================="
echo ""
echo "1. Update provider.tf:"
echo "   - Set AWS region"
echo "   - Set S3 backend bucket name"
echo "   - Add CodeConnections ARN"
echo "   - Add Kafka brokers (if needed)"
echo ""
echo "2. Update main.tf:"
echo "   - Set repository_url to your Bitbucket repo"
echo ""
echo "3. Create secrets in AWS Secrets Manager:"
echo "   aws secretsmanager create-secret \\"
echo "     --name $ENVIRONMENT/$SERVICE_NAME/database-url \\"
echo "     --secret-string 'your-database-url'"
echo ""
echo "   aws secretsmanager create-secret \\"
echo "     --name $ENVIRONMENT/$SERVICE_NAME/api-key \\"
echo "     --secret-string 'your-api-key'"
echo ""
echo "4. Initialize and deploy:"
echo "   terraform init -backend-config=../../environments/$ENVIRONMENT/backend.hcl"
echo "   terraform plan"
echo "   terraform apply"
echo ""
echo "=========================================="
