# ECS Task Definition Module - Main Resources
# Creates ECS Fargate task definitions with awsvpc network mode

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  family_name = "${var.service_name}-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "ecs-task-definition"
    ServiceName = var.service_name
    Runtime     = var.runtime
  })

  # Valid Fargate CPU/Memory combinations
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
  valid_memory_for_cpu = {
    256  = [512, 1024, 2048]
    512  = [1024, 2048, 3072, 4096]
    1024 = [2048, 3072, 4096, 5120, 6144, 7168, 8192]
    2048 = [4096, 5120, 6144, 7168, 8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360, 16384]
    4096 = [8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360, 16384, 17408, 18432, 19456, 20480, 21504, 22528, 23552, 24576, 25600, 26624, 27648, 28672, 29696, 30720]
  }

  # Validate CPU/Memory combination
  is_valid_memory = contains(local.valid_memory_for_cpu[var.cpu], var.memory)

  # Log group name - use provided or generate default
  log_group_name = var.log_group_name != null ? var.log_group_name : "/ecs/${var.service_name}"

  # Default health check command based on runtime
  default_health_check_command = var.runtime == "nodejs" ? [
    "CMD-SHELL",
    "node -e \"require('http').get('http://localhost:${var.container_port}/health', (res) => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))\""
    ] : [
    "CMD-SHELL",
    "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:${var.container_port}/health')\" || exit 1"
  ]

  health_check_command = var.health_check_command != null ? var.health_check_command : local.default_health_check_command
}


# =============================================================================
# CPU/Memory Validation
# Terraform will fail if invalid combination is provided
# =============================================================================

resource "null_resource" "validate_cpu_memory" {
  count = local.is_valid_memory ? 0 : 1

  provisioner "local-exec" {
    command = "echo 'ERROR: Invalid CPU/Memory combination. CPU ${var.cpu} supports memory values: ${join(", ", local.valid_memory_for_cpu[var.cpu])}' && exit 1"
  }
}

# =============================================================================
# CloudWatch Log Group for Container Logs
# =============================================================================

resource "aws_cloudwatch_log_group" "container" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_cloudwatch_arn

  tags = merge(local.common_tags, {
    Name = "${var.service_name}-logs"
  })
}

# =============================================================================
# Service-Specific Task Role (Optional)
# =============================================================================

resource "aws_iam_role" "task" {
  count = var.create_task_role && var.task_role_arn == null ? 1 : 0

  name = "${local.name_prefix}-${var.service_name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${var.service_name}-task"
    Role = "ECSTask"
  })
}

# Attach provided policy ARNs to the task role
resource "aws_iam_role_policy_attachment" "task_policies" {
  for_each = var.create_task_role && var.task_role_arn == null ? toset(var.task_role_policy_arns) : toset([])

  role       = aws_iam_role.task[0].name
  policy_arn = each.value
}

# Policy for task role to read service-specific secrets
resource "aws_iam_role_policy" "task_secrets" {
  count = var.create_task_role && var.task_role_arn == null && length(var.secrets_arns) > 0 ? 1 : 0

  name = "${local.name_prefix}-${var.service_name}-task-secrets"
  role = aws_iam_role.task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetServiceSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [for secret in var.secrets_arns : split(":", secret.value_from)[0]]
      },
      {
        Sid    = "DecryptSecrets"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_secrets_arn != null ? [var.kms_key_secrets_arn] : []
      }
    ]
  })
}


# =============================================================================
# ECS Task Definition
# =============================================================================

resource "aws_ecs_task_definition" "main" {
  family                   = local.family_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn != null ? var.task_role_arn : (var.create_task_role ? aws_iam_role.task[0].arn : null)

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      # Environment variables (non-sensitive)
      environment = [
        for key, value in merge(
          {
            # Default environment variables based on runtime
            NODE_ENV     = var.runtime == "nodejs" ? (var.environment == "prod" ? "production" : "development") : null
            PYTHON_ENV   = var.runtime == "python" ? (var.environment == "prod" ? "production" : "development") : null
            ENVIRONMENT  = var.environment
            SERVICE_NAME = var.service_name
            PORT         = tostring(var.container_port)
          },
          var.environment_variables
          ) : {
          name  = key
          value = value
        } if value != null
      ]

      # Secrets from Secrets Manager (sensitive)
      secrets = [
        for secret in var.secrets_arns : {
          name      = secret.name
          valueFrom = secret.value_from
        }
      ]

      # CloudWatch Logs configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.container.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Health check configuration
      healthCheck = {
        command     = local.health_check_command
        interval    = var.health_check_interval
        timeout     = var.health_check_timeout
        retries     = var.health_check_retries
        startPeriod = var.health_check_start_period
      }

      # Resource limits (soft limits for container)
      cpu    = var.cpu
      memory = var.memory

      # Linux parameters for security
      linuxParameters = {
        initProcessEnabled = true
      }
    }
  ])

  # Runtime platform for Fargate
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = merge(local.common_tags, {
    Name = local.family_name
  })

  # Lifecycle: Ignore changes to container image
  # The CI/CD pipeline updates the image, so Terraform shouldn't overwrite it
  lifecycle {
    ignore_changes = [
      container_definitions
    ]
  }

  # Ensure log group exists before task definition
  depends_on = [aws_cloudwatch_log_group.container]
}
