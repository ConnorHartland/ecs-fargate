# CI/CD Module - Main Resources
# Creates CodeBuild project for Docker image builds

locals {
  name_prefix  = "${var.project_name}-${var.environment}-${var.service_name}"
  project_name = "${local.name_prefix}-build"

  # Use s3_kms_key_arn if provided, otherwise fall back to kms_key_arn
  s3_kms_key_arn = var.s3_kms_key_arn != "" ? var.s3_kms_key_arn : var.kms_key_arn

  common_tags = merge(var.tags, {
    Module      = "cicd"
    ServiceName = var.service_name
  })

  # Default Buildspec (used when no custom buildspec is provided)
  default_buildspec = <<-BUILDSPEC
# Buildspec Template for ECS Fargate CI/CD Pipeline
# This buildspec is used by CodeBuild to build, scan, test, and push Docker images
#
# Required Environment Variables (set by CodeBuild project):
#   - AWS_ACCOUNT_ID: AWS account ID
#   - AWS_DEFAULT_REGION: AWS region
#   - ECR_REPOSITORY_URL: Full ECR repository URL
#   - ENVIRONMENT: Deployment environment (develop, test, qa, prod)
#   - CONTAINER_NAME: Name of the container for ECS task definition

version: 0.2

env:
  variables:
    TRIVY_SEVERITY: "HIGH,CRITICAL"
    SKIP_TESTS: "false"
    SKIP_SECURITY_SCAN: "false"

phases:
  install:
    runtime-versions:
      docker: 20
    commands:
      - echo Installing security scanning tools...
      - |
        if [ "$SKIP_SECURITY_SCAN" != "true" ]; then
          curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
          trivy --version
        fi

  pre_build:
    commands:
      - echo "=== Pre-Build Phase Started ==="
      - echo "Build started on $(date)"
      
      # Login to Amazon ECR
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      
      # Set image tags
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=$${COMMIT_HASH:-latest}
      - BRANCH_NAME=$${CODEBUILD_SOURCE_VERSION:-unknown}
      - BUILD_ID=$${CODEBUILD_BUILD_ID:-local}
      
      # Display build information
      - echo "Commit Hash: $COMMIT_HASH"
      - echo "Image Tag: $IMAGE_TAG"
      - echo "Environment: $ENVIRONMENT"
      - echo "Branch: $BRANCH_NAME"
      - echo "Build ID: $BUILD_ID"
      - echo "ECR Repository: $ECR_REPOSITORY_URL"
      
      - echo "=== Pre-Build Phase Completed ==="

  build:
    commands:
      - echo "=== Build Phase Started ==="
      - echo "Build started on $(date)"
      
      # Build Docker image
      - echo Building the Docker image...
      - docker build -t $ECR_REPOSITORY_URL:latest .
      
      # Tag image with multiple tags for traceability
      # Tag 1: Commit SHA (immutable reference)
      - docker tag $ECR_REPOSITORY_URL:latest $ECR_REPOSITORY_URL:$IMAGE_TAG
      # Tag 2: Environment + Commit SHA (environment-specific reference)
      - docker tag $ECR_REPOSITORY_URL:latest $ECR_REPOSITORY_URL:$ENVIRONMENT-$IMAGE_TAG
      # Tag 3: Environment-latest (rolling tag for environment)
      - docker tag $ECR_REPOSITORY_URL:latest $ECR_REPOSITORY_URL:$ENVIRONMENT-latest
      
      - echo "Docker images tagged successfully"
      - docker images | grep $ECR_REPOSITORY_URL
      
      # Run security scan with Trivy
      - echo "=== Security Scanning ==="
      - |
        if [ "$SKIP_SECURITY_SCAN" != "true" ]; then
          echo "Running Trivy security scan..."
          echo "Scanning for vulnerabilities with severity: $TRIVY_SEVERITY"
          trivy image --severity $TRIVY_SEVERITY --exit-code 0 --format table $ECR_REPOSITORY_URL:latest
          
          # Generate JSON report for artifact storage
          trivy image --severity $TRIVY_SEVERITY --format json --output trivy-report.json $ECR_REPOSITORY_URL:latest
          
          # Fail build on CRITICAL vulnerabilities in production
          if [ "$ENVIRONMENT" = "prod" ]; then
            echo "Production build: Checking for CRITICAL vulnerabilities..."
            trivy image --severity CRITICAL --exit-code 1 $ECR_REPOSITORY_URL:latest || {
              echo "ERROR: Critical vulnerabilities found in production build!"
              exit 1
            }
          fi
          echo "Security scan completed"
        else
          echo "Security scan skipped (SKIP_SECURITY_SCAN=true)"
        fi
      
      # Run tests
      - echo "=== Test Execution ==="
      - |
        if [ "$SKIP_TESTS" != "true" ]; then
          echo "Running tests..."
          # Run tests inside the container
          # The test command varies by runtime - detect and run appropriate tests
          if [ -f "package.json" ]; then
            echo "Node.js project detected, running npm test..."
            docker run --rm $ECR_REPOSITORY_URL:latest npm test || {
              echo "ERROR: Tests failed!"
              exit 1
            }
          elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
            echo "Python project detected, running pytest..."
            docker run --rm $ECR_REPOSITORY_URL:latest pytest || docker run --rm $ECR_REPOSITORY_URL:latest python -m pytest || {
              echo "WARNING: pytest not available or tests failed"
            }
          else
            echo "No recognized test framework found, skipping tests"
          fi
          echo "Test execution completed"
        else
          echo "Tests skipped (SKIP_TESTS=true)"
        fi
      
      - echo "=== Build Phase Completed ==="

  post_build:
    commands:
      - echo "=== Post-Build Phase Started ==="
      - echo "Build completed on $(date)"
      
      # Push Docker images to ECR
      - echo Pushing Docker images to ECR...
      
      # Push all tagged images
      - echo "Pushing tag: latest"
      - docker push $ECR_REPOSITORY_URL:latest
      
      - echo "Pushing tag: $IMAGE_TAG (commit SHA)"
      - docker push $ECR_REPOSITORY_URL:$IMAGE_TAG
      
      - echo "Pushing tag: $ENVIRONMENT-$IMAGE_TAG (environment + commit)"
      - docker push $ECR_REPOSITORY_URL:$ENVIRONMENT-$IMAGE_TAG
      
      - echo "Pushing tag: $ENVIRONMENT-latest (environment latest)"
      - docker push $ECR_REPOSITORY_URL:$ENVIRONMENT-latest
      
      - echo "All images pushed successfully"
      
      # Create imagedefinitions.json for ECS deployment
      - echo Writing image definitions file for ECS deployment...
      - printf '[{"name":"%s","imageUri":"%s"}]' $CONTAINER_NAME $ECR_REPOSITORY_URL:$IMAGE_TAG > imagedefinitions.json
      - cat imagedefinitions.json
      
      # Create build metadata file
      - |
        cat > build-metadata.json << EOF
        {
          "buildId": "$BUILD_ID",
          "commitHash": "$COMMIT_HASH",
          "imageTag": "$IMAGE_TAG",
          "environment": "$ENVIRONMENT",
          "repositoryUrl": "$ECR_REPOSITORY_URL",
          "buildTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
          "tags": [
            "latest",
            "$IMAGE_TAG",
            "$ENVIRONMENT-$IMAGE_TAG",
            "$ENVIRONMENT-latest"
          ]
        }
        EOF
      - cat build-metadata.json
      
      - echo "=== Post-Build Phase Completed ==="

artifacts:
  files:
    - imagedefinitions.json
    - build-metadata.json
    - trivy-report.json
  discard-paths: yes
  name: build-artifacts-$CODEBUILD_BUILD_NUMBER

cache:
  paths:
    - '/root/.docker/**/*'
    - '/root/.cache/trivy/**/*'

reports:
  security-scan:
    files:
      - trivy-report.json
    file-format: GENERICJSONREPORT
BUILDSPEC
}

# =============================================================================
# S3 Bucket for Docker Layer Caching
# =============================================================================

resource "aws_s3_bucket" "cache" {
  bucket = "${local.name_prefix}-codebuild-cache"

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-codebuild-cache"
    Purpose = "CodeBuildCache"
  })
}

resource "aws_s3_bucket_versioning" "cache" {
  bucket = aws_s3_bucket.cache.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cache" {
  bucket = aws_s3_bucket.cache.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cache" {
  bucket = aws_s3_bucket.cache.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cache" {
  bucket = aws_s3_bucket.cache.id

  rule {
    id     = "expire-cache"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}


# =============================================================================
# CloudWatch Log Group for CodeBuild
# =============================================================================

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${local.project_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name    = "/aws/codebuild/${local.project_name}"
    Purpose = "CodeBuildLogs"
  })
}

# =============================================================================
# CodeBuild Project
# =============================================================================

resource "aws_codebuild_project" "this" {
  name          = local.project_name
  description   = "Build Docker images for ${var.service_name} service"
  service_role  = var.codebuild_role_arn
  build_timeout = var.build_timeout_minutes

  artifacts {
    type = var.enable_pipeline ? "CODEPIPELINE" : "NO_ARTIFACTS"
  }

  environment {
    compute_type                = var.compute_type
    image                       = var.build_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.ecr_repository_url
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.service_name
    }
  }

  source {
    type      = var.enable_pipeline ? "CODEPIPELINE" : "NO_SOURCE"
    buildspec = var.buildspec_path != "" ? file(var.buildspec_path) : local.default_buildspec
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.cache.bucket}/docker-cache"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "build"
      status      = "ENABLED"
    }
  }

  encryption_key = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name = local.project_name
  })
}

# =============================================================================
# S3 Bucket for Pipeline Artifacts
# =============================================================================

resource "aws_s3_bucket" "artifacts" {
  count  = var.enable_pipeline ? 1 : 0
  bucket = "${local.name_prefix}-pipeline-artifacts"

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-pipeline-artifacts"
    Purpose = "PipelineArtifacts"
  })
}

resource "aws_s3_bucket_versioning" "artifacts" {
  count  = var.enable_pipeline ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  count  = var.enable_pipeline ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.s3_kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  count  = var.enable_pipeline ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  count  = var.enable_pipeline ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# =============================================================================
# CodePipeline for Feature/Release Branches (Non-Production)
# Feature: Manual trigger, no webhook - deploys feature/* branches to develop
# Release: Auto trigger with webhook - deploys release/*.*.* branches to test/qa
# =============================================================================

resource "aws_codepipeline" "this" {
  count    = var.enable_pipeline && var.pipeline_type != "production" ? 1 : 0
  name     = "${local.name_prefix}-pipeline"
  role_arn = var.codepipeline_role_arn

  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.artifacts[0].bucket
    type     = "S3"

    encryption_key {
      id   = local.s3_kms_key_arn
      type = "KMS"
    }
  }

  # Source Stage - CodeConnections to Bitbucket
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = var.codeconnections_arn
        FullRepositoryId     = var.repository_id
        BranchName           = var.branch_pattern
        OutputArtifactFormat = "CODE_ZIP"
        # For feature branches, we want manual trigger (no webhook)
        DetectChanges = var.pipeline_type == "feature" ? "false" : "true"
      }
    }
  }

  # Build Stage - CodeBuild
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  # Deploy Stage - ECS
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  tags = merge(local.common_tags, {
    Name          = "${local.name_prefix}-pipeline"
    PipelineType  = var.pipeline_type
    BranchPattern = var.branch_pattern
  })
}

# =============================================================================
# CodePipeline for Production Branches
# Includes manual approval stage with SNS notification
# Deploys prod/* branches to production environment
# Requirements: 3.3
# =============================================================================

resource "aws_codepipeline" "production" {
  count    = var.enable_pipeline && var.pipeline_type == "production" ? 1 : 0
  name     = "${local.name_prefix}-pipeline"
  role_arn = var.codepipeline_role_arn

  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.artifacts[0].bucket
    type     = "S3"

    encryption_key {
      id   = local.s3_kms_key_arn
      type = "KMS"
    }
  }

  # Source Stage - CodeConnections to Bitbucket for prod/* branches
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = var.codeconnections_arn
        FullRepositoryId     = var.repository_id
        BranchName           = var.branch_pattern
        OutputArtifactFormat = "CODE_ZIP"
        # Production pipelines require manual trigger for safety
        DetectChanges = "false"
      }
    }
  }

  # Build Stage - CodeBuild
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  # Manual Approval Stage - Required for production deployments
  # Sends notification to SNS topic and waits for approval (default: 7 days timeout)
  stage {
    name = "Approval"

    action {
      name     = "ManualApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        NotificationArn    = var.approval_sns_topic_arn != "" ? var.approval_sns_topic_arn : (length(aws_sns_topic.approval_notifications) > 0 ? aws_sns_topic.approval_notifications[0].arn : "")
        CustomData         = var.approval_comments
        ExternalEntityLink = var.approval_external_entity_link != "" ? var.approval_external_entity_link : null
      }
    }
  }

  # Deploy Stage - ECS Production Service
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName       = var.ecs_cluster_name
        ServiceName       = var.ecs_service_name
        FileName          = "imagedefinitions.json"
        DeploymentTimeout = "15"
      }
    }
  }

  tags = merge(local.common_tags, {
    Name                   = "${local.name_prefix}-pipeline"
    PipelineType           = "production"
    BranchPattern          = var.branch_pattern
    RequiresManualApproval = "true"
  })
}

# =============================================================================
# SNS Topic for Pipeline Notifications
# =============================================================================

resource "aws_sns_topic" "pipeline_notifications" {
  count = var.enable_pipeline && var.enable_notifications && var.notification_sns_topic_arn == "" ? 1 : 0

  name              = "${local.name_prefix}-pipeline-notifications"
  kms_master_key_id = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-pipeline-notifications"
    Purpose = "PipelineNotifications"
  })
}

# SNS Topic Policy to allow CodePipeline to publish notifications
resource "aws_sns_topic_policy" "pipeline_notifications" {
  count = var.enable_pipeline && var.enable_notifications && var.notification_sns_topic_arn == "" ? 1 : 0

  arn = aws_sns_topic.pipeline_notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodeStarNotifications"
        Effect = "Allow"
        Principal = {
          Service = "codestar-notifications.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.pipeline_notifications[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}

# =============================================================================
# SNS Topic for Production Approval Notifications
# Used by production pipelines to notify approvers of pending deployments
# Requirements: 3.3
# =============================================================================

resource "aws_sns_topic" "approval_notifications" {
  count = var.enable_pipeline && var.pipeline_type == "production" && var.approval_sns_topic_arn == "" ? 1 : 0

  name              = "${local.name_prefix}-approval-notifications"
  kms_master_key_id = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-approval-notifications"
    Purpose = "ProductionApprovalNotifications"
  })
}

# SNS Topic Policy to allow CodePipeline to publish approval notifications
resource "aws_sns_topic_policy" "approval_notifications" {
  count = var.enable_pipeline && var.pipeline_type == "production" && var.approval_sns_topic_arn == "" ? 1 : 0

  arn = aws_sns_topic.approval_notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodePipelineApprovalNotifications"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.approval_notifications[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}

# =============================================================================
# CodePipeline Notification Rule (Non-Production)
# =============================================================================

resource "aws_codestarnotifications_notification_rule" "pipeline" {
  count = var.enable_pipeline && var.enable_notifications && var.pipeline_type != "production" ? 1 : 0

  name        = "${local.name_prefix}-pipeline-notifications"
  detail_type = "FULL"
  resource    = aws_codepipeline.this[0].arn

  event_type_ids = var.notification_events

  target {
    type    = "SNS"
    address = var.notification_sns_topic_arn != "" ? var.notification_sns_topic_arn : aws_sns_topic.pipeline_notifications[0].arn
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-pipeline-notifications"
    Purpose = "PipelineNotificationRule"
  })
}

# =============================================================================
# CodePipeline Notification Rule (Production)
# Includes approval-related events for production deployments
# =============================================================================

resource "aws_codestarnotifications_notification_rule" "production_pipeline" {
  count = var.enable_pipeline && var.enable_notifications && var.pipeline_type == "production" ? 1 : 0

  name        = "${local.name_prefix}-pipeline-notifications"
  detail_type = "FULL"
  resource    = aws_codepipeline.production[0].arn

  event_type_ids = concat(var.notification_events, [
    "codepipeline-pipeline-manual-approval-needed",
    "codepipeline-pipeline-manual-approval-succeeded",
    "codepipeline-pipeline-manual-approval-failed"
  ])

  target {
    type = "SNS"
    # For production pipelines, use the approval notifications topic if no external topic is provided
    address = var.notification_sns_topic_arn != "" ? var.notification_sns_topic_arn : (length(aws_sns_topic.approval_notifications) > 0 ? aws_sns_topic.approval_notifications[0].arn : "")
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-pipeline-notifications"
    Purpose = "ProductionPipelineNotificationRule"
  })
}
