# Service 1 Configuration
# Public-facing Node.js service

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    # Backend configuration
    bucket         = "con-ecs-fargate-terraform-state"
    key            = "develop/services/service-1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "con-ecs-fargate-terraform-state-lock"
    encrypt        = true
  }
}

# =============================================================================
# Service Module Invocation
# =============================================================================

module "service_1" {
  source = "../../modules/service"

  # Service Identity
  service_name   = "service-1"
  runtime        = "nodejs"
  repository_url = "connor-cicd/service-1"
  service_type   = "public"

  # Container Configuration
  container_port = 3000
  cpu            = 512  # 0.5 vCPU
  memory         = 1024 # 1 GB

  # Scaling Configuration
  desired_count   = 1
  autoscaling_min = 1
  autoscaling_max = 5

  # Health Check Configuration
  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 5

  # ALB Routing Configuration
  path_patterns          = ["/*"]  # Route all traffic to this service
  listener_rule_priority = 101
  deregistration_delay   = 30

  # Environment Configuration
  environment = local.environment

  # Environment Variables
  environment_variables = {
    NODE_ENV     = local.environment == "prod" ? "production" : "development"
    LOG_LEVEL    = local.environment == "prod" ? "info" : "debug"
    PORT         = "3000"
    SERVICE_NAME = "service-1"

    # Kafka Configuration
    KAFKA_BROKERS   = join(",", local.kafka_brokers)
    KAFKA_CLIENT_ID = "service-1-${local.environment}"
    KAFKA_GROUP_ID  = "service-1-consumer-${local.environment}"
  }

  # Secrets Configuration
  # Create secrets in AWS Secrets Manager first, then uncomment:
  # secrets_arns = [
  #   {
  #     name       = "DATABASE_URL"
  #     value_from = "${local.secrets_arn_prefix}/service-1/database-url"
  #   },
  #   {
  #     name       = "API_KEY"
  #     value_from = "${local.secrets_arn_prefix}/service-1/api-key"
  #   }
  # ]
  secrets_arns = []

  # Kafka Configuration
  kafka_brokers           = local.kafka_brokers
  kafka_security_group_id = local.kafka_security_group_id

  # Infrastructure Dependencies
  project_name   = local.project_name
  aws_account_id = local.aws_account_id
  aws_region     = local.aws_region

  # ECS Cluster
  cluster_arn  = local.cluster_arn
  cluster_name = local.cluster_name

  # Network Configuration
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids
  public_subnet_ids  = local.public_subnet_ids

  # ALB Configuration
  alb_listener_arn      = local.alb_listener_arn
  alb_security_group_id = local.alb_security_group_id

  # IAM Roles
  task_execution_role_arn = local.task_execution_role_arn
  codebuild_role_arn      = local.codebuild_role_arn
  codepipeline_role_arn   = local.codepipeline_role_arn

  # KMS Keys
  kms_key_arn            = local.kms_key_arn
  kms_key_ecr_arn        = local.kms_key_ecr_arn
  kms_key_cloudwatch_arn = local.kms_key_cloudwatch_arn
  kms_key_secrets_arn    = local.kms_key_secrets_arn
  kms_key_s3_arn         = local.kms_key_s3_arn

  # CI/CD Configuration
  codeconnections_arn = local.codeconnections_arn
  branch_pattern      = local.environment == "prod" ? "main" : local.environment == "test" || local.environment == "qa" ? "release" : "develop"
  pipeline_type       = local.environment == "prod" ? "production" : "release"
  enable_pipeline     = true  # CI/CD pipeline enabled
  buildspec_path      = ""  # Use inline default buildspec from CICD module

  notification_sns_topic_arn = local.notification_sns_topic_arn
  approval_sns_topic_arn     = local.approval_sns_topic_arn

  # E2E Testing Configuration
  enable_e2e_tests       = true
  e2e_test_repository_id = "connor-cicd/qa-tests"  # Your QA test repository
  e2e_test_branch        = "main"  # Or match environment: develop/test/qa/main
  e2e_test_environment_variables = {
    API_URL = "https://your-alb-url.com"  # Service endpoint to test
    # Note: ENVIRONMENT and SERVICE_NAME are automatically set by the module
  }
  e2e_test_timeout_minutes = 30

  # Logging Configuration
  log_retention_days = local.environment == "prod" ? 90 : 30

  # Tags
  tags = merge(
    local.tags,
    {
      ServiceType = "public"
      Runtime     = "nodejs"
      Component   = "service-1"
    }
  )
}

# =============================================================================
# Outputs
# =============================================================================

output "service_arn" {
  description = "ARN of the ECS service"
  value       = module.service_1.service_arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.service_1.service_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.service_1.ecr_repository_url
}

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.service_1.pipeline_name
}
