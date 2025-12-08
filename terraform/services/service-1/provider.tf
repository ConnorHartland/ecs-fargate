# Provider configuration for service-1

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Change to your region
}

# Data source to get root infrastructure outputs
data "terraform_remote_state" "infra" {
  backend = "s3"
  
  config = {
    bucket = "con-ecs-fargate-terraform-state"
    key    = "develop/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_caller_identity" "current" {}

# Local values from infrastructure outputs
locals {
  # Core infrastructure
  environment    = data.terraform_remote_state.infra.outputs.environment
  project_name   = "ecs-fargate"
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.name
  
  # ECS Cluster
  cluster_arn  = data.terraform_remote_state.infra.outputs.ecs_cluster_arn
  cluster_name = data.terraform_remote_state.infra.outputs.ecs_cluster_name
  
  # Networking
  vpc_id             = data.terraform_remote_state.infra.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.infra.outputs.private_subnet_ids
  public_subnet_ids  = data.terraform_remote_state.infra.outputs.public_subnet_ids
  
  # ALB
  alb_listener_arn      = data.terraform_remote_state.infra.outputs.alb_listener_arn
  alb_security_group_id = data.terraform_remote_state.infra.outputs.alb_security_group_id
  
  # IAM Roles
  task_execution_role_arn = data.terraform_remote_state.infra.outputs.iam_role_arns["ecs_task_execution"]
  codebuild_role_arn      = data.terraform_remote_state.infra.outputs.iam_role_arns["codebuild"]
  codepipeline_role_arn   = data.terraform_remote_state.infra.outputs.iam_role_arns["codepipeline"]
  
  # KMS Keys
  kms_key_arn            = data.terraform_remote_state.infra.outputs.kms_key_arns["ecs"]
  kms_key_ecr_arn        = data.terraform_remote_state.infra.outputs.kms_key_arns["ecr"]
  kms_key_cloudwatch_arn = data.terraform_remote_state.infra.outputs.kms_key_arns["cloudwatch"]
  kms_key_secrets_arn    = data.terraform_remote_state.infra.outputs.kms_key_arns["secrets"]
  kms_key_s3_arn         = data.terraform_remote_state.infra.outputs.kms_key_arns["s3"]
  
  # SNS Topics
  notification_sns_topic_arn = data.terraform_remote_state.infra.outputs.monitoring_sns_topics["pipeline_notifications"]
  approval_sns_topic_arn     = data.terraform_remote_state.infra.outputs.monitoring_sns_topics["critical_alarms"]
  
  # Secrets
  secrets_arn_prefix = "arn:aws:secretsmanager:${local.aws_region}:${local.aws_account_id}:secret:${local.environment}"
  
  # Kafka (if you have it)
  kafka_brokers           = []    # Add your Kafka brokers here
  kafka_security_group_id = null  # Add your Kafka SG here (use null if no Kafka)
  
  # CodeConnections (required for CI/CD pipeline)
  codeconnections_arn = "arn:aws:codeconnections:us-east-1:664271361680:connection/ed05861e-fbf8-4f17-b554-fe3f0bf223a8" # Add your CodeConnections ARN here or set to null to skip pipeline
  
  # Tags
  tags = data.terraform_remote_state.infra.outputs.common_tags
}

data "aws_region" "current" {}
