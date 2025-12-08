# Example Configuration: Python Internal Service
# This example demonstrates an internal Python microservice without ALB
# Requirements: 1.3, 1.4

# This service will:
# - NOT be accessible via Application Load Balancer
# - Communicate only via Kafka message broker
# - Use Python runtime
# - Scale automatically based on CPU/memory
# - Have automated CI/CD pipeline from Bitbucket
# - Use AWS Cloud Map for service discovery

terraform {
  required_version = ">= 1.0"
}

# =============================================================================
# Service Module Invocation
# =============================================================================

module "python_internal_service" {
  source = "../../modules/service"

  # Service Identity
  service_name   = "data-processor"
  runtime        = "python"
  repository_url = "myorg/data-processor"
  service_type   = "internal"

  # Container Configuration
  container_port = 8000
  cpu            = 512  # 0.5 vCPU
  memory         = 1024 # 1 GB

  # Scaling Configuration
  desired_count   = 2 # Run 2 tasks for redundancy
  autoscaling_min = 1
  autoscaling_max = 6

  # Health Check Configuration (container-level only, no ALB)
  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 5

  # Environment Configuration
  environment = var.environment

  # Environment Variables (non-sensitive)
  environment_variables = {
    # Python Configuration
    PYTHONUNBUFFERED = "1"
    PYTHONPATH       = "/app"
    ENVIRONMENT      = var.environment == "prod" ? "production" : "development"
    LOG_LEVEL        = var.environment == "prod" ? "INFO" : "DEBUG"
    PORT             = "8000"
    SERVICE_NAME     = "data-processor"

    # Worker Configuration
    WORKERS           = "2"
    WORKER_TIMEOUT    = "300"
    GRACEFUL_TIMEOUT  = "30"

    # Kafka Configuration - Primary communication method for internal services
    KAFKA_BROKERS     = join(",", var.kafka_brokers)
    KAFKA_CLIENT_ID   = "data-processor-${var.environment}"
    KAFKA_GROUP_ID    = "data-processor-consumer-${var.environment}"
    KAFKA_TOPIC_INPUT = "raw-data"
    KAFKA_TOPIC_OUTPUT = "processed-data"
    KAFKA_TOPIC_DLQ   = "data-processor-dlq"

    # Consumer Configuration
    KAFKA_AUTO_OFFSET_RESET = "earliest"
    KAFKA_MAX_POLL_RECORDS  = "50"
    KAFKA_SESSION_TIMEOUT   = "30000"
    KAFKA_HEARTBEAT_INTERVAL = "10000"
    KAFKA_ENABLE_AUTO_COMMIT = "false"

    # Producer Configuration
    KAFKA_ACKS              = "all"
    KAFKA_COMPRESSION_TYPE  = "gzip"
    KAFKA_MAX_IN_FLIGHT     = "5"
    KAFKA_LINGER_MS         = "10"
    KAFKA_BATCH_SIZE        = "16384"

    # Data Processing Configuration
    BATCH_SIZE           = "50"
    PROCESSING_TIMEOUT   = "180"
    MAX_RETRIES          = "3"
    RETRY_BACKOFF        = "5"
    ENABLE_PARALLEL_PROCESSING = "true"
    PARALLEL_WORKERS     = "4"

    # Service Discovery
    SERVICE_DISCOVERY_ENABLED = "true"
    SERVICE_DISCOVERY_NAMESPACE = "${var.environment}.internal"

    # Feature Flags
    ENABLE_METRICS    = "true"
    ENABLE_TRACING    = var.environment == "prod" ? "true" : "false"
    ENABLE_DEAD_LETTER_QUEUE = "true"
    ENABLE_DATA_VALIDATION = "true"
  }

  # Secrets Configuration (sensitive values from Secrets Manager)
  secrets_arns = [
    {
      name       = "DATABASE_URL"
      value_from = "${var.secrets_arn_prefix}/data-processor/database-url"
    },
    {
      name       = "REDIS_URL"
      value_from = "${var.secrets_arn_prefix}/data-processor/redis-url"
    },
    {
      name       = "KAFKA_USERNAME"
      value_from = "${var.secrets_arn_prefix}/kafka/username"
    },
    {
      name       = "KAFKA_PASSWORD"
      value_from = "${var.secrets_arn_prefix}/kafka/password"
    },
    {
      name       = "KAFKA_SSL_CA_CERT"
      value_from = "${var.secrets_arn_prefix}/kafka/ssl-ca-cert"
    },
    {
      name       = "KAFKA_SSL_CERT"
      value_from = "${var.secrets_arn_prefix}/kafka/ssl-cert"
    },
    {
      name       = "KAFKA_SSL_KEY"
      value_from = "${var.secrets_arn_prefix}/kafka/ssl-key"
    },
    {
      name       = "ENCRYPTION_KEY"
      value_from = "${var.secrets_arn_prefix}/data-processor/encryption-key"
    }
  ]

  # Kafka Configuration
  kafka_brokers           = var.kafka_brokers
  kafka_security_group_id = var.kafka_security_group_id

  # Service Discovery Configuration (for internal service-to-service communication)
  enable_service_discovery      = true
  service_discovery_namespace_id = var.service_discovery_namespace_id

  # Infrastructure Dependencies
  project_name   = var.project_name
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region

  # ECS Cluster
  cluster_arn  = var.cluster_arn
  cluster_name = var.cluster_name

  # Network Configuration (private subnets only, no public access)
  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids

  # NO ALB Configuration (internal service)
  # alb_listener_arn and alb_security_group_id are not provided

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
      Runtime     = "python"
      Component   = "data-processor"
      Communication = "kafka-only"
      Language    = "python3.11"
    }
  )
}

# =============================================================================
# Outputs
# =============================================================================

output "service_arn" {
  description = "ARN of the ECS service"
  value       = module.python_internal_service.service_arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.python_internal_service.service_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.python_internal_service.ecr_repository_url
}

output "pipeline_name" {
  description = "Name of the CodePipeline"
  value       = module.python_internal_service.pipeline_name
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = module.python_internal_service.task_role_arn
}

output "security_group_id" {
  description = "Security group ID for the service"
  value       = module.python_internal_service.security_group_id
}

output "service_discovery_arn" {
  description = "ARN of the service discovery service"
  value       = module.python_internal_service.service_discovery_arn
}
