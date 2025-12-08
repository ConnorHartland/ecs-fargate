# Service 2 Configuration
# Public-facing Python service

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    # Backend configuration provided via -backend-config flag
    # See: ../../environments/{environment}/backend.hcl
  }
}

# =============================================================================
# Service Module Invocation
# =============================================================================

module "service_2" {
  source = "../../modules/service"

  # Service Identity
  service_name   = "service-2"
  runtime        = "python"
  repository_url = "myorg/service-2"
  service_type   = "public"

  # Container Configuration
  container_port = 8000
  cpu            = 512  # 0.5 vCPU
  memory         = 1024 # 1 GB

  # Scaling Configuration
  desired_count   = 2
  autoscaling_min = 1
  autoscaling_max = 5

  # Health Check Configuration
  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 5

  # ALB Routing Configuration
  path_patterns          = ["/service2/*"]
  listener_rule_priority = 102
  deregistration_delay   = 30

  # Environment Configuration
  environment = var.environment

  # Environment Variables
  environment_variables = {
    PYTHON_ENV   = var.environment == "prod" ? "production" : "development"
    LOG_LEVEL    = var.environment == "prod" ? "info" : "debug"
    PORT         = "8000"
    SERVICE_NAME = "service-2"

    # Kafka Configuration
    KAFKA_BROKERS   = join(",", var.kafka_brokers)
    KAFKA_CLIENT_ID = "service-2-${var.environment}"
    KAFKA_GROUP_ID  = "service-2-consumer-${var.environment}"
  }

  # Secrets Configuration
  secrets_arns = [
    {
      name       = "DATABASE_URL"
      value_from = "${var.secrets_arn_prefix}/service-2/database-url"
    },
    {
      name       = "API_KEY"
      value_from = "${var.secrets_arn_prefix}/service-2/api-key"
    }
  ]

  # Kafka Configuration
  kafka_brokers           = var.kafka_brokers
  kafka_security_group_id = var.kafka_security_group_id

  # Infrastructure Dependencies
  project_name   = var.project_name
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region

  # ECS Cluster
  cluster_arn  = var.cluster_arn
  cluster_name = var.cluster_name

  # Network Configuration
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids

  # ALB Configuration
  alb_listener_arn      = var.alb_listener_arn
  alb_security_group_id = var.alb_security_group_id

  # IAM Roles
  task_execution_role_arn = var.task_execution_role_arn
  codebuild_role_arn      = var.codebuild_role_arn
  codepipeline_role_arn   = var.codepipeline_role_arn

  # KMS Keys
  kms_key_arn            = var.kms_key_arn
  kms_key_ecr_arn        = var.kms_key_ecr_arn
  kms_key_cloudwatch_arn = var.kms_key_cloudwatch_arn
  kms_key_secrets_arn    = var.kms_key_secrets_arn
  kms_key_s3_arn         = var.kms_key_s3_arn

  # CI/CD Configuration
  codeconnections_arn = var.codeconnections_arn
  branch_pattern      = var.environment == "prod" ? "prod/*" : var.environment == "test" || var.environment == "qa" ? "release/*" : "feature/*"
  pipeline_type       = var.environment == "prod" ? "production" : var.environment == "test" || var.environment == "qa" ? "release" : "feature"
  enable_pipeline     = true

  notification_sns_topic_arn = var.notification_sns_topic_arn
  approval_sns_topic_arn     = var.approval_sns_topic_arn

  # Logging Configuration
  log_retention_days = var.environment == "prod" ? 90 : 30

  # Tags
  tags = merge(
    var.tags,
    {
      ServiceType = "public"
      Runtime     = "python"
      Component   = "service-2"
    }
  )
}

# =============================================================================
# Outputs
# =============================================================================

output "service_arn" {
  description = "ARN of the ECS service"
  value       = module.service_2.service_arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.service_2.service_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.service_2.ecr_repository_url
}

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.service_2.pipeline_name
}
