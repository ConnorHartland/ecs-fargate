# Backend configuration for develop environment
# Usage: terraform init -backend-config=environments/develop/backend.hcl

bucket         = "con-ecs-fargate-terraform-state"
key            = "develop/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "con-ecs-fargate-terraform-state-lock"
encrypt        = true
