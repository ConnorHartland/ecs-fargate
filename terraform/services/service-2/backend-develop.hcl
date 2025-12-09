# Backend configuration for service-2 in develop environment
# Usage: terraform init -backend-config=backend-develop.hcl -reconfigure
# Note: DynamoDB locking removed to avoid state lock issues

bucket         = "con-ecs-fargate-terraform-state"
key            = "develop/services/service-2/terraform.tfstate"
region         = "us-east-1"
encrypt        = true