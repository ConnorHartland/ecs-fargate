# Backend configuration for test environment
# Usage: terraform init -backend-config=environments/test/backend.hcl
# Note: DynamoDB locking removed to avoid state lock issues

bucket  = "ecs-fargate-terraform-state"
key     = "test/terraform.tfstate"
region  = "us-east-1"
encrypt = true
