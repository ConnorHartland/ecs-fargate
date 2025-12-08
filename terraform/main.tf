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

# =============================================================================
# Module Instantiations
# =============================================================================

# Networking Module - VPC, Subnets, Security Groups
module "networking" {
  source = "./modules/networking"

  environment        = var.environment
  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

  tags = {
    Environment = var.environment
    Owner       = var.mandatory_tags.Owner
    CostCenter  = var.mandatory_tags.CostCenter
    Compliance  = var.mandatory_tags.Compliance
  }
}

# Security Module - KMS Keys and IAM Roles
module "security" {
  source = "./modules/security"

  environment    = var.environment
  project_name   = var.project_name
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id

  # Environment-specific settings
  key_deletion_window_days   = var.kms_key_deletion_window_override != null ? var.kms_key_deletion_window_override : local.kms_key_deletion_window
  require_mfa_for_production = true

  tags = {
    Environment = var.environment
    Owner       = var.mandatory_tags.Owner
    CostCenter  = var.mandatory_tags.CostCenter
    Compliance  = var.mandatory_tags.Compliance
  }
}

# Secrets Module - Secrets Manager Configuration
module "secrets" {
  source = "./modules/secrets"

  environment  = var.environment
  project_name = var.project_name
  aws_region   = var.aws_region
  kms_key_arn  = module.security.kms_key_secrets_arn

  secrets = var.secrets
  # Environment-specific recovery window: 30 days for production, 7 days for non-production
  recovery_window_days = local.secrets_recovery_window

  tags = {
    Environment = var.environment
    Owner       = var.mandatory_tags.Owner
    CostCenter  = var.mandatory_tags.CostCenter
    Compliance  = var.mandatory_tags.Compliance
  }
}
