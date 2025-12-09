# Backend configuration for QA environment
# Usage: terraform init -backend-config=environments/qa/backend.hcl
# Note: DynamoDB locking removed to avoid state lock issues

bucket  = "ecs-fargate-terraform-state"
key     = "qa/terraform.tfstate"
region  = "us-east-1"
encrypt = true
