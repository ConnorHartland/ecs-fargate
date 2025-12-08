# Service 3 Configuration
# Internal Node.js service (no ALB, Kafka-based)

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

module "service_3" {
  source = "../../modules/service"

  # Service Identity
  service_name   = "service-3"
  runtime        = "nodejs"
  repository_url = "myorg/service-3"
  service_type   = "internal"

  # Container Configuration
  container_port = 3000
  cpu            = 256  # 0.25 vCPU
  memory         = 512  # 512 MB

  # Scaling Configuration
  desired_count   = 2
  autoscaling_min = 1
  autoscaling_max = 4

  # Environment Configuration
  environment = var.environment

  # Environment Variables
  environment_variables = {
    NODE_ENV     = var.environment == "prod" ? "production" : "development"
    LOG_LEVEL    = var.environment == "prod" ? "info" : "debug"
    PORT         = "3000"
    SERVICE_NAME = "service-3"

    # Kafka Configuration (primary communication method)
    KAFKA_BROKERS     = join(",", var.kafka_brokers)
    KAFKA_CLIENT_ID   = "service-3-${var.environment}"
    KAFKA_GROUP_ID    = "service-3-consumer-${var.environment}"
    KAFKA_TOPIC_INPUT = "service-3-input"
    KAFKA_TOPIC_OUTPUT = "service-3-output"
  }

  # Secrets Configuration
  secrets_arns = [
    {
      name       = "DATABASE_URL"
      value_from = "${var.secrets_arn_prefix}/service-3/database-url"
    },
    {
      name       = "KAFKA_USERNAME"
      value_from = "${var.secrets_arn_prefix}/kafka/username"
    },
    {
      name       = "KAFKA_PASSWORD"
      value_from = "${var.secrets_arn_prefix}/kafka/password"
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

  # ALB Configuration (not used for internal services)
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
      ServiceType = "internal"
      Runtime     = "nodejs"
      Component   = "service-3"
    }
  )
}

# =============================================================================
# Outputs
# =============================================================================

output "service_arn" {
  description = "ARN of the ECS service"
  value       = module.service_3.service_arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.service_3.service_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.service_3.ecr_repository_url
}

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.service_3.pipeline_name
}
