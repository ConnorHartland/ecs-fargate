# ECR Module - Main Resources
# Creates ECR repository with encryption, scanning, and lifecycle policies

locals {
  repository_name = "${var.project_name}-${var.environment}-${var.service_name}"

  common_tags = merge(var.tags, {
    Module      = "ecr"
    ServiceName = var.service_name
  })
}

# =============================================================================
# ECR Repository
# =============================================================================

resource "aws_ecr_repository" "this" {
  name                 = local.repository_name
  image_tag_mutability = var.image_tag_mutability

  # Enable image scanning on push for vulnerability detection
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  # Enable KMS encryption for images at rest
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = var.kms_key_arn
  }

  tags = merge(local.common_tags, {
    Name = local.repository_name
  })
}

# =============================================================================
# ECR Lifecycle Policy
# Removes untagged images after specified days and limits tagged images
# =============================================================================

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep images tagged with prod-* indefinitely"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = 9999
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after ${var.untagged_image_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_expiry_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep last ${var.max_tagged_images} tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["develop-", "test-", "qa-"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_tagged_images
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Keep last ${var.max_tagged_images} any tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_tagged_images * 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# =============================================================================
# ECR Repository Policy
# Restricts access to authorized ECS tasks and CodeBuild
# =============================================================================

resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSTaskExecutionPull"
        Effect = "Allow"
        Principal = {
          AWS = var.ecs_task_execution_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      },
      {
        Sid    = "AllowCodeBuildPush"
        Effect = "Allow"
        Principal = {
          AWS = var.codebuild_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      },
      {
        Sid       = "DenyPublicAccess"
        Effect    = "Deny"
        Principal = "*"
        Action = [
          "ecr:*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
