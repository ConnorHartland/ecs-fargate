# Backend configuration for production environment
# Usage: terraform init -backend-config=environments/prod/backend.hcl

bucket         = "ecs-fargate-terraform-state"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "ecs-fargate-terraform-state-lock"
encrypt        = true
