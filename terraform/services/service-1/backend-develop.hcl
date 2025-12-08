# Backend configuration for service-1 in develop environment
# Usage: terraform init -backend-config=backend-develop.hcl -reconfigure

bucket         = "con-ecs-fargate-terraform-state"
key            = "develop/services/service-1/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "con-ecs-fargate-terraform-state-lock"
encrypt        = true
