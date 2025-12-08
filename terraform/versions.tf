# Terraform and provider version constraints
# This file ensures consistent provider versions across all environments

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # S3 backend configuration with encryption and DynamoDB state locking
  # Backend configuration is partially configured here and completed via backend config files
  backend "s3" {
    # These values are provided via backend config files per environment
    # bucket         = "terraform-state-bucket"
    # key            = "ecs-fargate/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-state-lock"
    encrypt = true
  }
}
