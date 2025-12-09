# Backend configuration for develop environment
# Usage: terraform init -backend-config=environments/develop/backend.hcl
# Note: DynamoDB locking removed to avoid state lock issues

bucket  = "con-ecs-fargate-terraform-state"
key     = "develop/terraform.tfstate"
region  = "us-east-1"
encrypt = true
