# Main Terraform configuration for ECS Fargate CI/CD Infrastructure
# This file orchestrates all modules and defines the root configuration

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

# AWS Provider configuration with default tags for compliance
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Owner       = var.mandatory_tags.Owner
      CostCenter  = var.mandatory_tags.CostCenter
      Compliance  = var.mandatory_tags.Compliance
      ManagedBy   = "Terraform"
      Project     = "ecs-fargate-cicd"
    }
  }
}

# Data source for current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
