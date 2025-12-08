# Backend configuration for test environment
# Usage: terraform init -backend-config=environments/test/backend.hcl

bucket         = "ecs-fargate-terraform-state"
key            = "test/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "ecs-fargate-terraform-state-lock"
encrypt        = true
