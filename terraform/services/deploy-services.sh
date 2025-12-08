#!/bin/bash
# Deploy script for service-1, service-2, and service-3
# Usage: ./deploy-services.sh <environment> [service-name]
# Example: ./deploy-services.sh develop
# Example: ./deploy-services.sh develop service-1

set -e

ENVIRONMENT=${1:-develop}
SPECIFIC_SERVICE=$2

if [[ ! "$ENVIRONMENT" =~ ^(develop|test|qa|prod)$ ]]; then
  echo "Error: Environment must be one of: develop, test, qa, prod"
  exit 1
fi

SERVICES=("service-1" "service-2" "service-3")

if [ -n "$SPECIFIC_SERVICE" ]; then
  SERVICES=("$SPECIFIC_SERVICE")
fi

echo "=========================================="
echo "Deploying services to: $ENVIRONMENT"
echo "Services: ${SERVICES[@]}"
echo "=========================================="

for SERVICE in "${SERVICES[@]}"; do
  echo ""
  echo ">>> Deploying $SERVICE..."
  echo ""
  
  cd "$SERVICE"
  
  # Initialize Terraform with environment-specific backend
  echo "Initializing Terraform..."
  terraform init -backend-config="../../environments/$ENVIRONMENT/backend.hcl" -reconfigure
  
  # Plan changes
  echo "Planning changes..."
  terraform plan -var-file="../../environments/$ENVIRONMENT/terraform.tfvars" -out=tfplan
  
  # Apply changes
  echo "Applying changes..."
  terraform apply tfplan
  
  # Clean up plan file
  rm -f tfplan
  
  cd ..
  
  echo ""
  echo "✓ $SERVICE deployed successfully"
  echo ""
done

echo "=========================================="
echo "All services deployed successfully!"
echo "=========================================="
