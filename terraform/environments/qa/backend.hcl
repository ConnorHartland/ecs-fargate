# Backend configuration for QA environment
# Usage: terraform init -backend-config=environments/qa/backend.hcl

bucket         = "ecs-fargate-terraform-state"
key            = "qa/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "ecs-fargate-terraform-state-lock"
encrypt        = true
