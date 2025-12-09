# Service Module - Main Resources
# Reusable module that combines all components for deploying a microservice
# Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  service_name = var.service_name

  # Determine if this is a public service (requires ALB resources)
  is_public_service = var.service_type == "public"

  # Determine if this is an internal service (uses service discovery)
  is_internal_service = var.service_type == "internal"

  # Use specific KMS keys if provided, otherwise fall back to general KMS key
  kms_key_ecr_arn        = var.kms_key_ecr_arn != null ? var.kms_key_ecr_arn : var.kms_key_arn
  kms_key_cloudwatch_arn = var.kms_key_cloudwatch_arn != null ? var.kms_key_cloudwatch_arn : var.kms_key_arn
  kms_key_secrets_arn    = var.kms_key_secrets_arn != null ? var.kms_key_secrets_arn : var.kms_key_arn
  kms_key_s3_arn         = var.kms_key_s3_arn != null ? var.kms_key_s3_arn : var.kms_key_arn

  # Environment-specific log retention (production gets longer retention)
  effective_log_retention = var.environment == "prod" ? max(var.log_retention_days, 90) : var.log_retention_days

  # Merge Kafka brokers into environment variables for internal services
  kafka_env_vars = local.is_internal_service && length(var.kafka_brokers) > 0 ? {
    KAFKA_BROKERS = join(",", var.kafka_brokers)
  } : {}

  # Runtime-specific environment variables
  runtime_env_vars = var.runtime == "nodejs" ? {
    NODE_ENV = var.environment == "prod" ? "production" : "development"
    } : {
    PYTHON_ENV = var.environment == "prod" ? "production" : "development"
  }

  # Combined environment variables
  all_env_vars = merge(
    local.runtime_env_vars,
    local.kafka_env_vars,
    var.environment_variables
  )

  common_tags = merge(var.tags, {
    Module      = "service"
    ServiceName = var.service_name
    ServiceType = var.service_type
    Runtime     = var.runtime
    Environment = var.environment
  })
}

# =============================================================================
# ECR Repository
# Creates container registry for the service
# Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
# =============================================================================

module "ecr" {
  source = "../ecr"

  service_name = var.service_name
  environment  = var.environment
  project_name = var.project_name

  kms_key_arn    = local.kms_key_ecr_arn
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region

  image_tag_mutability       = "IMMUTABLE"
  scan_on_push               = true
  untagged_image_expiry_days = 7
  max_tagged_images          = 10

  ecs_task_execution_role_arn = var.task_execution_role_arn
  codebuild_role_arn          = var.codebuild_role_arn

  tags = local.common_tags
}

# =============================================================================
# Security Group for ECS Tasks
# Creates service-specific security group
# Requirements: 7.5, 7.6, 7.7, 7.8
# =============================================================================

resource "aws_security_group" "service" {
  name        = "${local.name_prefix}-${var.service_name}-sg"
  description = "Security group for ${var.service_name} ECS tasks"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${var.service_name}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress from ALB (for public services only)
resource "aws_security_group_rule" "ingress_from_alb" {
  count = local.is_public_service && var.alb_security_group_id != null ? 1 : 0

  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.service.id
  description              = "Allow traffic from ALB"
}

# Ingress from other services (for internal services)
resource "aws_security_group_rule" "ingress_from_services" {
  count = local.is_internal_service ? 1 : 0

  type              = "ingress"
  from_port         = var.container_port
  to_port           = var.container_port
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.service.id
  description       = "Allow traffic from other services"
}

# Egress to Kafka (for services that need Kafka access)
resource "aws_security_group_rule" "egress_to_kafka" {
  count = var.kafka_security_group_id != null ? 1 : 0

  type                     = "egress"
  from_port                = 9092
  to_port                  = 9094
  protocol                 = "tcp"
  source_security_group_id = var.kafka_security_group_id
  security_group_id        = aws_security_group.service.id
  description              = "Allow outbound traffic to Kafka"
}

# General egress (HTTPS for AWS services, etc.)
resource "aws_security_group_rule" "egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.service.id
  description       = "Allow HTTPS outbound for AWS services"
}


# =============================================================================
# ECS Task Definition
# Creates task definition with runtime-specific configuration
# Requirements: 5.2, 5.6, 5.8, 6.1, 9.2, 9.3
# =============================================================================

module "task_definition" {
  source = "../ecs-task-definition"

  service_name = var.service_name
  environment  = var.environment
  project_name = var.project_name
  runtime      = var.runtime

  container_image = "${module.ecr.repository_url}:latest"
  container_port  = var.container_port

  cpu    = var.cpu
  memory = var.memory

  environment_variables = local.all_env_vars
  secrets_arns          = var.secrets_arns

  # Health check configuration
  health_check_interval     = var.health_check_interval
  health_check_timeout      = var.health_check_timeout
  health_check_retries      = 3
  health_check_start_period = 60

  # IAM roles
  task_execution_role_arn = var.task_execution_role_arn
  create_task_role        = true
  task_role_policy_arns   = []

  # Logging
  log_retention_days     = local.effective_log_retention
  kms_key_cloudwatch_arn = local.kms_key_cloudwatch_arn
  kms_key_secrets_arn    = local.kms_key_secrets_arn

  # AWS configuration
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id

  tags = local.common_tags
}

# =============================================================================
# Target Group (for public services only)
# Creates ALB target group for routing traffic
# Requirements: 8.1, 8.2, 8.4, 8.6
# =============================================================================

resource "aws_lb_target_group" "service" {
  count = local.is_public_service ? 1 : 0

  name        = "${local.name_prefix}-${var.service_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-299"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${var.service_name}-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# ALB Listener Rule (for public services only)
# Creates path-based routing rule
# Requirements: 8.4
# =============================================================================

resource "aws_lb_listener_rule" "service" {
  count = local.is_public_service && var.alb_listener_arn != null ? 1 : 0

  listener_arn = var.alb_listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[0].arn
  }

  condition {
    path_pattern {
      values = var.path_patterns
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${var.service_name}-rule"
  })
}

# =============================================================================
# ECS Service
# Creates the ECS service with appropriate configuration
# Requirements: 5.1, 5.4, 5.5, 5.7, 8.1
# =============================================================================

module "ecs_service" {
  source = "../ecs-service"

  service_name = var.service_name
  environment  = var.environment
  project_name = var.project_name
  service_type = var.service_type

  # ECS cluster
  cluster_arn  = var.cluster_arn
  cluster_name = var.cluster_name

  # Task definition
  task_definition_arn = module.task_definition.task_definition_arn
  container_name      = module.task_definition.container_name
  container_port      = var.container_port

  # Service configuration
  desired_count = var.desired_count

  # Deployment configuration for zero-downtime
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  enable_circuit_breaker             = true
  enable_circuit_breaker_rollback    = true
  deployment_timeout                 = "15m"

  # Network configuration - tasks run in private subnets
  private_subnet_ids = var.private_subnet_ids
  security_group_ids = [aws_security_group.service.id]
  assign_public_ip   = false

  # Load balancer configuration (for public services only)
  target_group_arn                  = local.is_public_service ? aws_lb_target_group.service[0].arn : null
  health_check_grace_period_seconds = local.is_public_service ? 60 : 0

  # Service discovery configuration (for internal services only)
  enable_service_discovery       = local.is_internal_service && var.enable_service_discovery
  service_discovery_namespace_id = local.is_internal_service ? var.service_discovery_namespace_id : null

  # Auto-scaling
  enable_autoscaling       = true
  autoscaling_min_capacity = var.autoscaling_min
  autoscaling_max_capacity = var.autoscaling_max
  cpu_target_value         = 70
  memory_target_value      = 70

  # Capacity provider strategy
  use_capacity_provider_strategy = true
  fargate_weight                 = var.environment == "prod" ? 100 : 70
  fargate_spot_weight            = var.environment == "prod" ? 0 : 30
  fargate_base                   = 1

  tags = local.common_tags

  depends_on = [
    module.task_definition,
    aws_lb_target_group.service
  ]
}

# =============================================================================
# CI/CD Pipeline
# Creates CodeBuild project and CodePipeline
# Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7
# =============================================================================

module "cicd" {
  count  = var.enable_pipeline ? 1 : 0
  source = "../cicd"

  service_name = var.service_name
  environment  = var.environment
  project_name = var.project_name

  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region

  ecr_repository_url = module.ecr.repository_url
  codebuild_role_arn = var.codebuild_role_arn
  kms_key_arn        = local.kms_key_cloudwatch_arn  # Use CloudWatch KMS key for logs
  s3_kms_key_arn     = local.kms_key_s3_arn

  # Pipeline configuration
  enable_pipeline       = var.enable_pipeline
  codepipeline_role_arn = var.codepipeline_role_arn
  codeconnections_arn   = var.codeconnections_arn
  repository_id         = var.repository_url
  branch_pattern        = var.branch_pattern
  pipeline_type         = var.pipeline_type

  # ECS deployment target
  ecs_cluster_name = var.cluster_name
  ecs_service_name = module.ecs_service.service_name

  # Notifications
  enable_notifications       = var.enable_notifications
  notification_sns_topic_arn = var.notification_sns_topic_arn
  approval_sns_topic_arn     = var.approval_sns_topic_arn
  # Only pass notification_events if explicitly set, otherwise use valid defaults
  # Note: Some event types like 'stopped' and 'resumed' are not valid for CodePipeline
  notification_events = length(var.notification_events) > 0 ? var.notification_events : [
    "codepipeline-pipeline-pipeline-execution-started",
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-pipeline-execution-failed",
    "codepipeline-pipeline-pipeline-execution-canceled",
    "codepipeline-pipeline-pipeline-execution-superseded"
  ]

  # Build configuration
  log_retention_days    = local.effective_log_retention
  build_timeout_minutes = 30
  compute_type          = "BUILD_GENERAL1_SMALL"
  buildspec_path        = var.buildspec_path

  # E2E Testing configuration
  enable_e2e_tests              = var.enable_e2e_tests
  e2e_test_repository_id        = var.e2e_test_repository_id
  e2e_test_branch               = var.e2e_test_branch
  e2e_test_buildspec            = var.e2e_test_buildspec
  e2e_test_environment_variables = var.e2e_test_environment_variables
  e2e_test_timeout_minutes      = var.e2e_test_timeout_minutes

  tags = local.common_tags

  depends_on = [
    module.ecr,
    module.ecs_service
  ]
}
