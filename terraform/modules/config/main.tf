# AWS Config Module - Main Resources
# Creates AWS Config recorder, delivery channel, and compliance rules
# Requirements: 11.5

locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  is_production = var.environment == "prod"

  # S3 bucket name for Config delivery
  config_bucket_name = var.config_bucket_name != null ? var.config_bucket_name : "${local.name_prefix}-config-${var.aws_account_id}"

  common_tags = merge(var.tags, {
    Module       = "config"
    IsProduction = tostring(local.is_production)
    Compliance   = "NIST-CM-2,SOC2-CC8.1"
  })
}

# =============================================================================
# S3 Bucket for Config Delivery
# Requirements: 11.5 - Store configuration snapshots
# =============================================================================

resource "aws_s3_bucket" "config" {
  bucket = local.config_bucket_name

  # Prevent accidental deletion in production
  force_destroy = !local.is_production

  tags = merge(local.common_tags, {
    Name    = local.config_bucket_name
    Purpose = "AWSConfigDelivery"
  })
}

# Enable versioning on the Config S3 bucket
resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption configuration using KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Block public access to Config S3 bucket
resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Lifecycle configuration for Config snapshots
resource "aws_s3_bucket_lifecycle_configuration" "config" {
  bucket = aws_s3_bucket.config.id

  rule {
    id     = "config-snapshot-retention"
    status = "Enabled"

    filter {}

    # Transition to Glacier after retention period for cost optimization
    transition {
      days          = var.log_retention_days
      storage_class = "GLACIER"
    }

    # Delete snapshots after extended retention period
    expiration {
      days = var.log_retention_days * 2
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "noncurrent-version-retention"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.log_retention_days
    }
  }
}

# S3 bucket policy for AWS Config
resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = var.aws_account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config.arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = var.aws_account_id
          }
        }
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config.arn}/AWSLogs/${var.aws_account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "AWS:SourceAccount" = var.aws_account_id
          }
        }
      },
      {
        Sid       = "DenyUnencryptedTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.config.arn,
          "${aws_s3_bucket.config.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "DenyIncorrectEncryptionHeader"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.config]
}

# =============================================================================
# IAM Role for AWS Config
# =============================================================================

resource "aws_iam_role" "config" {
  name = "${local.name_prefix}-config"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-config"
    Role = "AWSConfig"
  })
}

# Attach AWS managed policy for Config
resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Additional policy for S3 delivery
resource "aws_iam_role_policy" "config_s3" {
  name = "${local.name_prefix}-config-s3"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BucketAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.config.arn}/AWSLogs/${var.aws_account_id}/Config/*"
        Condition = {
          StringLike = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "S3BucketCheck"
        Effect = "Allow"
        Action = [
          "s3:GetBucketAcl"
        ]
        Resource = aws_s3_bucket.config.arn
      },
      {
        Sid    = "KMSEncryption"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}


# =============================================================================
# SNS Topic for Config Notifications
# =============================================================================

resource "aws_sns_topic" "config" {
  count = var.enable_sns_notifications && var.sns_topic_arn == null ? 1 : 0

  name              = "${local.name_prefix}-config-notifications"
  kms_master_key_id = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-config-notifications"
    Purpose = "ConfigNotifications"
  })
}

locals {
  sns_topic_arn = var.enable_sns_notifications ? (
    var.sns_topic_arn != null ? var.sns_topic_arn : aws_sns_topic.config[0].arn
  ) : null
}

# SNS topic policy for Config
resource "aws_sns_topic_policy" "config" {
  count = var.enable_sns_notifications && var.sns_topic_arn == null ? 1 : 0

  arn = aws_sns_topic.config[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigSNSPolicy"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.config[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = var.aws_account_id
          }
        }
      }
    ]
  })
}

# =============================================================================
# AWS Config Recorder
# Requirements: 11.5 - Track configuration changes to all resource types
# =============================================================================

resource "aws_config_configuration_recorder" "main" {
  name     = "${local.name_prefix}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported = true

    # Include global resources only in one region to avoid duplicates
    include_global_resource_types = var.include_global_resources

    recording_strategy {
      use_only = "ALL_SUPPORTED_RESOURCE_TYPES"
    }
  }

  recording_mode {
    recording_frequency = var.recording_frequency
  }
}

# =============================================================================
# AWS Config Delivery Channel
# Requirements: 11.5 - Set up Config delivery channel to S3
# =============================================================================

resource "aws_config_delivery_channel" "main" {
  name           = "${local.name_prefix}-delivery"
  s3_bucket_name = aws_s3_bucket.config.id
  s3_key_prefix  = "AWSLogs/${var.aws_account_id}/Config"
  sns_topic_arn  = local.sns_topic_arn

  snapshot_delivery_properties {
    delivery_frequency = local.is_production ? "One_Hour" : "Six_Hours"
  }

  depends_on = [
    aws_config_configuration_recorder.main,
    aws_s3_bucket_policy.config
  ]
}

# Enable the Config recorder
resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# =============================================================================
# AWS Config Rules - ECS Compliance
# Requirements: 11.5 - Enable Config rules for compliance checks
# =============================================================================

# Rule: ECS Task Definition Memory Hard Limit
resource "aws_config_config_rule" "ecs_task_definition_memory_hard_limit" {
  count = var.enable_managed_rules && var.enable_ecs_rules ? 1 : 0

  name        = "${local.name_prefix}-ecs-task-def-memory-limit"
  description = "Checks if ECS task definitions have a memory hard limit set"

  source {
    owner             = "AWS"
    source_identifier = "ECS_TASK_DEFINITION_MEMORY_HARD_LIMIT"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-ecs-task-def-memory-limit"
    Compliance = "NIST-SC-6"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: ECS Task Definition Nonroot User
resource "aws_config_config_rule" "ecs_task_definition_nonroot_user" {
  count = var.enable_managed_rules && var.enable_ecs_rules ? 1 : 0

  name        = "${local.name_prefix}-ecs-task-def-nonroot"
  description = "Checks if ECS task definitions specify a non-root user"

  source {
    owner             = "AWS"
    source_identifier = "ECS_TASK_DEFINITION_NONROOT_USER"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-ecs-task-def-nonroot"
    Compliance = "NIST-AC-6"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: ECS Task Definition Log Configuration
resource "aws_config_config_rule" "ecs_task_definition_log_configuration" {
  count = var.enable_managed_rules && var.enable_ecs_rules ? 1 : 0

  name        = "${local.name_prefix}-ecs-task-def-logging"
  description = "Checks if ECS task definitions have log configuration enabled"

  source {
    owner             = "AWS"
    source_identifier = "ECS_TASK_DEFINITION_LOG_CONFIGURATION"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-ecs-task-def-logging"
    Compliance = "NIST-AU-2"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: ECS Containers Readonly Access
resource "aws_config_config_rule" "ecs_containers_readonly_access" {
  count = var.enable_managed_rules && var.enable_ecs_rules ? 1 : 0

  name        = "${local.name_prefix}-ecs-containers-readonly"
  description = "Checks if ECS containers have read-only access to root filesystem"

  source {
    owner             = "AWS"
    source_identifier = "ECS_CONTAINERS_READONLY_ACCESS"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-ecs-containers-readonly"
    Compliance = "NIST-AC-6"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}


# =============================================================================
# AWS Config Rules - Encryption Compliance
# =============================================================================

# Rule: S3 Bucket Server Side Encryption Enabled
resource "aws_config_config_rule" "s3_bucket_server_side_encryption" {
  count = var.enable_managed_rules && var.enable_encryption_rules ? 1 : 0

  name        = "${local.name_prefix}-s3-bucket-sse"
  description = "Checks if S3 buckets have server-side encryption enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-s3-bucket-sse"
    Compliance = "NIST-SC-28"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: S3 Bucket SSL Requests Only
resource "aws_config_config_rule" "s3_bucket_ssl_requests_only" {
  count = var.enable_managed_rules && var.enable_encryption_rules ? 1 : 0

  name        = "${local.name_prefix}-s3-bucket-ssl"
  description = "Checks if S3 buckets require SSL for requests"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SSL_REQUESTS_ONLY"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-s3-bucket-ssl"
    Compliance = "NIST-SC-8"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: ECR Private Repository KMS Encryption
resource "aws_config_config_rule" "ecr_private_image_scanning" {
  count = var.enable_managed_rules && var.enable_encryption_rules ? 1 : 0

  name        = "${local.name_prefix}-ecr-image-scanning"
  description = "Checks if ECR private repositories have image scanning enabled"

  source {
    owner             = "AWS"
    source_identifier = "ECR_PRIVATE_IMAGE_SCANNING_ENABLED"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-ecr-image-scanning"
    Compliance = "NIST-RA-5"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: CloudWatch Log Group Encrypted
resource "aws_config_config_rule" "cloudwatch_log_group_encrypted" {
  count = var.enable_managed_rules && var.enable_encryption_rules ? 1 : 0

  name        = "${local.name_prefix}-cw-log-encrypted"
  description = "Checks if CloudWatch Log Groups are encrypted with KMS"

  source {
    owner             = "AWS"
    source_identifier = "CLOUDWATCH_LOG_GROUP_ENCRYPTED"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-cw-log-encrypted"
    Compliance = "NIST-SC-28"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: KMS CMK Not Scheduled For Deletion
resource "aws_config_config_rule" "kms_cmk_not_scheduled_for_deletion" {
  count = var.enable_managed_rules && var.enable_encryption_rules ? 1 : 0

  name        = "${local.name_prefix}-kms-cmk-not-deleted"
  description = "Checks if KMS CMKs are not scheduled for deletion"

  source {
    owner             = "AWS"
    source_identifier = "KMS_CMK_NOT_SCHEDULED_FOR_DELETION"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-kms-cmk-not-deleted"
    Compliance = "NIST-SC-12"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# =============================================================================
# AWS Config Rules - IAM Compliance
# =============================================================================

# Rule: IAM Root Access Key Check
resource "aws_config_config_rule" "iam_root_access_key_check" {
  count = var.enable_managed_rules && var.enable_iam_rules ? 1 : 0

  name        = "${local.name_prefix}-iam-root-access-key"
  description = "Checks if root account has access keys"

  source {
    owner             = "AWS"
    source_identifier = "IAM_ROOT_ACCESS_KEY_CHECK"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-iam-root-access-key"
    Compliance = "NIST-AC-2"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: IAM User MFA Enabled
resource "aws_config_config_rule" "iam_user_mfa_enabled" {
  count = var.enable_managed_rules && var.enable_iam_rules ? 1 : 0

  name        = "${local.name_prefix}-iam-user-mfa"
  description = "Checks if IAM users have MFA enabled"

  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_MFA_ENABLED"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-iam-user-mfa"
    Compliance = "NIST-IA-2"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: IAM Policy No Statements With Admin Access
resource "aws_config_config_rule" "iam_policy_no_admin_access" {
  count = var.enable_managed_rules && var.enable_iam_rules ? 1 : 0

  name        = "${local.name_prefix}-iam-no-admin-access"
  description = "Checks if IAM policies do not have statements with admin access"

  source {
    owner             = "AWS"
    source_identifier = "IAM_POLICY_NO_STATEMENTS_WITH_ADMIN_ACCESS"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-iam-no-admin-access"
    Compliance = "NIST-AC-6"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: IAM User Unused Credentials Check
resource "aws_config_config_rule" "iam_user_unused_credentials" {
  count = var.enable_managed_rules && var.enable_iam_rules ? 1 : 0

  name        = "${local.name_prefix}-iam-unused-credentials"
  description = "Checks if IAM users have unused credentials"

  source {
    owner             = "AWS"
    source_identifier = "IAM_USER_UNUSED_CREDENTIALS_CHECK"
  }

  input_parameters = jsonencode({
    maxCredentialUsageAge = "90"
  })

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-iam-unused-credentials"
    Compliance = "NIST-AC-2"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# =============================================================================
# AWS Config Rules - VPC Compliance
# =============================================================================

# Rule: VPC Flow Logs Enabled
resource "aws_config_config_rule" "vpc_flow_logs_enabled" {
  count = var.enable_managed_rules && var.enable_vpc_rules ? 1 : 0

  name        = "${local.name_prefix}-vpc-flow-logs"
  description = "Checks if VPC Flow Logs are enabled"

  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-vpc-flow-logs"
    Compliance = "NIST-AU-2"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: VPC Default Security Group Closed
resource "aws_config_config_rule" "vpc_default_security_group_closed" {
  count = var.enable_managed_rules && var.enable_vpc_rules ? 1 : 0

  name        = "${local.name_prefix}-vpc-default-sg-closed"
  description = "Checks if default VPC security group is closed"

  source {
    owner             = "AWS"
    source_identifier = "VPC_DEFAULT_SECURITY_GROUP_CLOSED"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-vpc-default-sg-closed"
    Compliance = "NIST-SC-7"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: Restricted SSH
resource "aws_config_config_rule" "restricted_ssh" {
  count = var.enable_managed_rules && var.enable_vpc_rules ? 1 : 0

  name        = "${local.name_prefix}-restricted-ssh"
  description = "Checks if security groups allow unrestricted SSH access"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-restricted-ssh"
    Compliance = "NIST-SC-7"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# Rule: Restricted Common Ports
resource "aws_config_config_rule" "restricted_common_ports" {
  count = var.enable_managed_rules && var.enable_vpc_rules ? 1 : 0

  name        = "${local.name_prefix}-restricted-common-ports"
  description = "Checks if security groups allow unrestricted access to common ports"

  source {
    owner             = "AWS"
    source_identifier = "RESTRICTED_INCOMING_TRAFFIC"
  }

  input_parameters = jsonencode({
    blockedPort1 = "20"
    blockedPort2 = "21"
    blockedPort3 = "3389"
    blockedPort4 = "3306"
    blockedPort5 = "4333"
  })

  tags = merge(local.common_tags, {
    Name       = "${local.name_prefix}-restricted-common-ports"
    Compliance = "NIST-SC-7"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}


# =============================================================================
# AWS Config Aggregator (Multi-Account/Multi-Region)
# Requirements: 11.5 - Configure Config aggregator for multi-account
# =============================================================================

resource "aws_config_configuration_aggregator" "main" {
  count = var.enable_aggregator ? 1 : 0

  name = "${local.name_prefix}-aggregator"

  # Account aggregation source (for multi-account setup)
  dynamic "account_aggregation_source" {
    for_each = length(var.aggregator_account_ids) > 0 ? [1] : []
    content {
      account_ids = var.aggregator_account_ids
      regions     = length(var.aggregator_regions) > 0 ? var.aggregator_regions : [var.aws_region]
      all_regions = length(var.aggregator_regions) == 0
    }
  }

  # Organization aggregation source (alternative to account aggregation)
  # Uncomment if using AWS Organizations
  # dynamic "organization_aggregation_source" {
  #   for_each = var.use_organization_aggregation ? [1] : []
  #   content {
  #     all_regions = true
  #     role_arn    = var.organization_aggregation_role_arn
  #   }
  # }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-aggregator"
    Purpose = "ConfigAggregation"
  })

  depends_on = [aws_config_configuration_recorder_status.main]
}

# IAM Role for Config Aggregator (if using cross-account aggregation)
resource "aws_iam_role" "config_aggregator" {
  count = var.enable_aggregator && length(var.aggregator_account_ids) > 0 ? 1 : 0

  name = "${local.name_prefix}-config-aggregator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-config-aggregator"
    Role = "ConfigAggregator"
  })
}

resource "aws_iam_role_policy" "config_aggregator" {
  count = var.enable_aggregator && length(var.aggregator_account_ids) > 0 ? 1 : 0

  name = "${local.name_prefix}-config-aggregator"
  role = aws_iam_role.config_aggregator[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AggregatorPermissions"
        Effect = "Allow"
        Action = [
          "config:BatchGetAggregateResourceConfig",
          "config:GetAggregateComplianceDetailsByConfigRule",
          "config:GetAggregateConfigRuleComplianceSummary",
          "config:GetAggregateDiscoveredResourceCounts",
          "config:GetAggregateResourceConfig",
          "config:ListAggregateDiscoveredResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# CloudWatch Alarms for Config Compliance
# =============================================================================

# SNS Topic for compliance alerts (if not using existing topic)
resource "aws_sns_topic" "compliance_alerts" {
  count = var.enable_sns_notifications && var.sns_topic_arn == null ? 1 : 0

  name              = "${local.name_prefix}-compliance-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-compliance-alerts"
    Purpose = "ComplianceAlerts"
  })
}

# CloudWatch Event Rule for Config compliance changes
resource "aws_cloudwatch_event_rule" "config_compliance_change" {
  count = var.enable_sns_notifications ? 1 : 0

  name        = "${local.name_prefix}-config-compliance-change"
  description = "Capture AWS Config compliance state changes"

  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      messageType = ["ComplianceChangeNotification"]
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-config-compliance-change"
  })
}

# CloudWatch Event Target for compliance alerts
resource "aws_cloudwatch_event_target" "config_compliance_sns" {
  count = var.enable_sns_notifications ? 1 : 0

  rule      = aws_cloudwatch_event_rule.config_compliance_change[0].name
  target_id = "SendToSNS"
  arn       = local.sns_topic_arn

  input_transformer {
    input_paths = {
      configRuleName = "$.detail.configRuleName"
      resourceType   = "$.detail.resourceType"
      resourceId     = "$.detail.resourceId"
      awsRegion      = "$.detail.awsRegion"
      complianceType = "$.detail.newEvaluationResult.complianceType"
    }
    input_template = "\"AWS Config Compliance Alert: Rule <configRuleName> found <resourceType> <resourceId> in <awsRegion> is <complianceType>\""
  }
}

# Allow EventBridge to publish to SNS
resource "aws_sns_topic_policy" "compliance_alerts" {
  count = var.enable_sns_notifications && var.sns_topic_arn == null ? 1 : 0

  arn = aws_sns_topic.compliance_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.compliance_alerts[0].arn
      }
    ]
  })
}
