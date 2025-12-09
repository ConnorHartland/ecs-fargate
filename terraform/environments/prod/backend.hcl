# Backend configuration for production environment
# Usage: terraform init -backend-config=environments/prod/backend.hcl
# Note: DynamoDB locking removed to avoid state lock issues

bucket  = "ecs-fargate-terraform-state"
key     = "prod/terraform.tfstate"
region  = "us-east-1"
encrypt = true
