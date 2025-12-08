# Security Module - Main Resources
# Creates KMS keys and IAM roles for ECS Fargate infrastructure

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Environment-specific settings
  is_production = var.environment == "prod"

  # KMS key deletion window: 30 days for production, 7 days for non-production
  effective_key_deletion_window = var.key_deletion_window_days != null ? var.key_deletion_window_days : (local.is_production ? 30 : 7)

  common_tags = merge(var.tags, {
    Module       = "security"
    IsProduction = tostring(local.is_production)
  })
}

# =============================================================================
# KMS Key for ECS (Task volumes and execute command)
# =============================================================================

resource "aws_kms_key" "ecs" {
  description             = "KMS key for ECS encryption - ${local.name_prefix}"
  deletion_window_in_days = local.effective_key_deletion_window
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow ECS Service"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-ecs-kms"
    Purpose = "ECS"
  })
}

resource "aws_kms_alias" "ecs" {
  name          = "alias/${local.name_prefix}-ecs"
  target_key_id = aws_kms_key.ecs.key_id
}


# =============================================================================
# KMS Key for ECR (Container image encryption)
# =============================================================================

resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR encryption - ${local.name_prefix}"
  deletion_window_in_days = local.effective_key_deletion_window
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow ECR Service"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-ecr-kms"
    Purpose = "ECR"
  })
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${local.name_prefix}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

# =============================================================================
# KMS Key for Secrets Manager
# =============================================================================

resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager - ${local.name_prefix}"
  deletion_window_in_days = local.effective_key_deletion_window
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager Service"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-secrets-kms"
    Purpose = "SecretsManager"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${local.name_prefix}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# =============================================================================
# KMS Key for CloudWatch Logs
# =============================================================================

resource "aws_kms_key" "cloudwatch" {
  description             = "KMS key for CloudWatch Logs - ${local.name_prefix}"
  deletion_window_in_days = local.effective_key_deletion_window
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs Service"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-cloudwatch-kms"
    Purpose = "CloudWatch"
  })
}

resource "aws_kms_alias" "cloudwatch" {
  name          = "alias/${local.name_prefix}-cloudwatch"
  target_key_id = aws_kms_key.cloudwatch.key_id
}

# =============================================================================
# KMS Key for S3 (ALB logs, pipeline artifacts, CloudTrail)
# =============================================================================

resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 encryption - ${local.name_prefix}"
  deletion_window_in_days = local.effective_key_deletion_window
  enable_key_rotation     = var.enable_key_rotation
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail Service"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow ELB Service for Access Logs"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-s3-kms"
    Purpose = "S3"
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${local.name_prefix}-s3"
  target_key_id = aws_kms_key.s3.key_id
}


# =============================================================================
# IAM Role - ECS Task Execution Role
# Used by ECS to pull images, write logs, and read secrets
# =============================================================================

resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.name_prefix}-ecs-task-execution"

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
    Name = "${local.name_prefix}-ecs-task-execution"
    Role = "ECSTaskExecution"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_base" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "${local.name_prefix}-ecs-task-execution-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${local.name_prefix}-*"
      },
      {
        Sid    = "DecryptSecrets"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_execution_ecr" {
  name = "${local.name_prefix}-ecs-task-execution-ecr"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DecryptECRImages"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.ecr.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_execution_logs" {
  name = "${local.name_prefix}-ecs-task-execution-logs"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EncryptLogs"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.cloudwatch.arn
      }
    ]
  })
}

# =============================================================================
# IAM Role - ECS Task Role (Template)
# Used by the application running in the container
# =============================================================================

resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task"

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
    Name = "${local.name_prefix}-ecs-task"
    Role = "ECSTask"
  })
}

# Base policy for task role - read-only access to service-specific secrets
resource "aws_iam_role_policy" "ecs_task_secrets" {
  name = "${local.name_prefix}-ecs-task-secrets"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetServiceSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${local.name_prefix}-*"
      },
      {
        Sid    = "DecryptSecrets"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}


# =============================================================================
# IAM Role - CodeBuild Service Role
# Used by CodeBuild to build Docker images and push to ECR
# =============================================================================

resource "aws_iam_role" "codebuild" {
  name = "${local.name_prefix}-codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-codebuild"
    Role = "CodeBuild"
  })
}

resource "aws_iam_role_policy" "codebuild_base" {
  name = "${local.name_prefix}-codebuild-base"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/codebuild/${local.name_prefix}-*",
          "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/codebuild/${local.name_prefix}-*:*"
        ]
      },
      {
        Sid    = "EncryptLogs"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.cloudwatch.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_ecr" {
  name = "${local.name_prefix}-codebuild-ecr"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${local.name_prefix}-*"
      },
      {
        Sid    = "ECREncryption"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.ecr.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_s3" {
  name = "${local.name_prefix}-codebuild-s3"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${local.name_prefix}-*/*"
      },
      {
        Sid    = "S3ArtifactsBucket"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${local.name_prefix}-*"
      },
      {
        Sid    = "S3Encryption"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.s3.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild_secrets" {
  name = "${local.name_prefix}-codebuild-secrets"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetBuildSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${local.name_prefix}-build-*"
      },
      {
        Sid    = "DecryptSecrets"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.secrets.arn
      }
    ]
  })
}


# =============================================================================
# IAM Role - CodePipeline Service Role
# Used by CodePipeline to orchestrate CI/CD workflows
# =============================================================================

resource "aws_iam_role" "codepipeline" {
  name = "${local.name_prefix}-codepipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-codepipeline"
    Role = "CodePipeline"
  })
}

resource "aws_iam_role_policy" "codepipeline_base" {
  name = "${local.name_prefix}-codepipeline-base"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::${local.name_prefix}-*",
          "arn:aws:s3:::${local.name_prefix}-*/*"
        ]
      },
      {
        Sid    = "S3Encryption"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.s3.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_codeconnections" {
  name = "${local.name_prefix}-codepipeline-codeconnections"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CodeConnections"
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = "arn:aws:codestar-connections:${var.aws_region}:${var.aws_account_id}:connection/*"
      },
      {
        Sid    = "CodeConnectionsNew"
        Effect = "Allow"
        Action = [
          "codeconnections:UseConnection"
        ]
        Resource = "arn:aws:codeconnections:${var.aws_region}:${var.aws_account_id}:connection/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_codebuild" {
  name = "${local.name_prefix}-codepipeline-codebuild"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CodeBuild"
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codebuild:StopBuild"
        ]
        Resource = "arn:aws:codebuild:${var.aws_region}:${var.aws_account_id}:project/${local.name_prefix}-*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_ecs" {
  name = "${local.name_prefix}-codepipeline-ecs"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECS"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      },
      {
        Sid    = "ECSUnconditional"
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution.arn,
          aws_iam_role.ecs_task.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_sns" {
  name = "${local.name_prefix}-codepipeline-sns"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SNS"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:${local.name_prefix}-*"
      }
    ]
  })
}

# =============================================================================
# Production-Specific IAM Policies
# Stricter access controls for production environment
# Requirements: 10.5, 11.3
# =============================================================================

# IAM Policy for human user access to production resources (requires MFA)
resource "aws_iam_policy" "production_access" {
  count = local.is_production && var.require_mfa_for_production ? 1 : 0

  name        = "${local.name_prefix}-production-access"
  description = "Policy for human user access to production resources - requires MFA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAccessWithoutMFA"
        Effect = "Deny"
        Action = [
          "ecs:*",
          "ecr:*",
          "secretsmanager:*",
          "kms:*",
          "s3:*",
          "logs:*"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
          StringEquals = {
            "aws:ResourceTag/Environment" = "prod"
          }
        }
      },
      {
        Sid    = "AllowAccessWithMFA"
        Effect = "Allow"
        Action = [
          "ecs:Describe*",
          "ecs:List*",
          "ecr:Describe*",
          "ecr:List*",
          "ecr:GetAuthorizationToken",
          "secretsmanager:Describe*",
          "secretsmanager:List*",
          "kms:Describe*",
          "kms:List*",
          "s3:Get*",
          "s3:List*",
          "logs:Describe*",
          "logs:Get*",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-production-access"
    Purpose    = "ProductionMFAEnforcement"
    Compliance = "NIST-IA-2,SOC2-CC6.1"
  })
}

# IAM Policy to restrict destructive actions in production
resource "aws_iam_policy" "production_protection" {
  count = local.is_production ? 1 : 0

  name        = "${local.name_prefix}-production-protection"
  description = "Policy to restrict destructive actions in production environment"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDestructiveECSActions"
        Effect = "Deny"
        Action = [
          "ecs:DeleteCluster",
          "ecs:DeleteService",
          "ecs:DeregisterTaskDefinition"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = "prod"
          }
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      },
      {
        Sid    = "DenyDestructiveECRActions"
        Effect = "Deny"
        Action = [
          "ecr:DeleteRepository",
          "ecr:DeleteRepositoryPolicy",
          "ecr:BatchDeleteImage"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${local.name_prefix}-*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      },
      {
        Sid    = "DenyDestructiveSecretsActions"
        Effect = "Deny"
        Action = [
          "secretsmanager:DeleteSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${local.name_prefix}-*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      },
      {
        Sid    = "DenyKMSKeyDeletion"
        Effect = "Deny"
        Action = [
          "kms:ScheduleKeyDeletion",
          "kms:DisableKey"
        ]
        Resource = [
          aws_kms_key.ecs.arn,
          aws_kms_key.ecr.arn,
          aws_kms_key.secrets.arn,
          aws_kms_key.cloudwatch.arn,
          aws_kms_key.s3.arn
        ]
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-production-protection"
    Purpose    = "ProductionResourceProtection"
    Compliance = "NIST-AC-3,SOC2-CC6.1"
  })
}

# =============================================================================
# Environment-Specific IAM Role Permissions Boundary
# Limits the maximum permissions for roles in production
# =============================================================================

resource "aws_iam_policy" "permissions_boundary" {
  count = local.is_production ? 1 : 0

  name        = "${local.name_prefix}-permissions-boundary"
  description = "Permissions boundary for production environment roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSOperations"
        Effect = "Allow"
        Action = [
          "ecs:*"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:cluster/${local.name_prefix}-*",
          "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:service/${local.name_prefix}-*/*",
          "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:task/${local.name_prefix}-*/*",
          "arn:aws:ecs:${var.aws_region}:${var.aws_account_id}:task-definition/${local.name_prefix}-*:*"
        ]
      },
      {
        Sid    = "AllowECROperations"
        Effect = "Allow"
        Action = [
          "ecr:*"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${local.name_prefix}-*"
      },
      {
        Sid    = "AllowECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsOperations"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${local.name_prefix}-*"
      },
      {
        Sid    = "AllowKMSOperations"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = [
          aws_kms_key.ecs.arn,
          aws_kms_key.ecr.arn,
          aws_kms_key.secrets.arn,
          aws_kms_key.cloudwatch.arn,
          aws_kms_key.s3.arn
        ]
      },
      {
        Sid    = "AllowLogsOperations"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/${local.name_prefix}-*:*"
      },
      {
        Sid    = "AllowS3Operations"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.name_prefix}-*",
          "arn:aws:s3:::${local.name_prefix}-*/*"
        ]
      },
      {
        Sid    = "DenyIAMModifications"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-permissions-boundary"
    Purpose    = "PermissionsBoundary"
    Compliance = "NIST-AC-2,SOC2-CC6.1"
  })
}
