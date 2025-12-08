# Example Configuration: Node.js Public-Facing Service
# This example demonstrates a public-facing Node.js microservice with ALB integration
# Requirements: 1.3, 1.4

# This service will:
# - Be accessible via Application Load Balancer
# - Use Node.js runtime
# - Scale automatically based on CPU/memory
# - Connect to Kafka for event processing
# - Have automated CI/CD pipeline from Bitbucket

terraform {
  required_version = ">= 1.0"
}

# =============================================================================
# Service Module Invocation
# =============================================================================

module "nodejs_public_service" {
  source = "../../modules/service"

  # Service Identity
  service_name   = "api-gateway"
  runtime        = "nodejs"
  repository_url = "myorg/api-gateway"
  service_type   = "public"

  # Container Configuration
  container_port = 3000
  cpu            = 512  # 0.5 vCPU
  memory         = 1024 # 1 GB

  # Scaling Configuration
  desired_count   = 3 # Run 3 tasks for high availability
  autoscaling_min = 2
  autoscaling_max = 10

  # Health Check Configuration (required for public services)
  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 5

  # ALB Routing Configuration
  path_patterns          = ["/api/*", "/v1/*"]
  listener_rule_priority = 100
  deregistration_delay   = 30

  # Environment Configuration
  environment = var.environment

  # Environment Variables (non-sensitive)
  environment_variables = {
    NODE_ENV     = var.environment == "prod" ? "production" : "development"
    LOG_LEVEL    = var.environment == "prod" ? "info" : "debug"
    PORT         = "3000"
    SERVICE_NAME = "api-gateway"

    # Kafka Configuration
    KAFKA_BROKERS     = join(",", var.kafka_brokers)
    KAFKA_CLIENT_ID   = "api-gateway-${var.environment}"
    KAFKA_GROUP_ID    = "api-gateway-consumer-${var.environment}"
    KAFKA_TOPIC_INPUT = "api-requests"
    KAFKA_TOPIC_OUTPUT = "api-responses"

    # Feature Flags
    ENABLE_METRICS    = "true"
    ENABLE_TRACING    = var.environment == "prod" ? "true" : "false"
    ENABLE_RATE_LIMIT = "true"
  }

  # Secrets Configuration (sensitive values from Secrets Manager)
  secrets_arns = [
    {
      name       = "DATABASE_URL"
      value_from = "${var.secrets_arn_prefix}/api-gateway/database-url"
    },
    {
      name       = "JWT_SECRET"
      value_from = "${var.secrets_arn_prefix}/api-gateway/jwt-secret"
    },
    {
      name       = "API_KEY"
      value_from = "${var.secrets_arn_prefix}/api-gateway/api-key"
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

  # ALB Configuration (required for public services)
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
      Runtime     = "nodejs"
      Component   = "api-gateway"
    }
  )
}

# =============================================================================
# Outputs
# =============================================================================

output "service_arn" {
  description = "ARN of the ECS service"
  value       = module.nodejs_public_service.service_arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.nodejs_public_service.service_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.nodejs_public_service.ecr_repository_url
}

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.nodejs_public_service.pipeline_name
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.nodejs_public_service.task_role_arn
}

output "security_group_id" {
  description = "Security group ID for the service"
  value       = module.nodejs_public_service.security_group_id
}
