# CloudTrail Module - Main Resources
# Creates CloudTrail with encryption, S3 bucket with versioning and MFA delete
# Requirements: 11.1, 11.2

locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  is_production = var.environment == "prod"

  # S3 bucket name for CloudTrail logs
  cloudtrail_bucket_name = "${local.name_prefix}-cloudtrail-logs-${var.aws_account_id}"

  common_tags = merge(var.tags, {
    Module       = "cloudtrail"
    IsProduction = tostring(local.is_production)
    Compliance   = "NIST-AU-2,NIST-AU-9,SOC2-CC7.2"
  })
}

# =============================================================================
# S3 Bucket for CloudTrail Logs
# Requirements: 11.2 - Versioning and MFA delete enabled
# =============================================================================

resource "aws_s3_bucket" "cloudtrail" {
  bucket = local.cloudtrail_bucket_name

  # Prevent accidental deletion in production
  force_destroy = !local.is_production

  tags = merge(local.common_tags, {
    Name    = local.cloudtrail_bucket_name
    Purpose = "CloudTrailLogs"
  })
}

# Enable versioning on the CloudTrail S3 bucket
# Requirements: 11.2
resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = var.enable_mfa_delete ? "Enabled" : "Disabled"
  }
}

# Server-side encryption configuration using KMS
# Requirements: 11.1
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}


# Block public access to CloudTrail S3 bucket
resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for CloudTrail logs
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    id     = "cloudtrail-log-retention"
    status = "Enabled"

    filter {}

    # Transition to Glacier after retention period for cost optimization
    transition {
      days          = var.log_retention_days
      storage_class = "GLACIER"
    }

    # Delete logs after extended retention period
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

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.log_retention_days
    }
  }
}

# S3 bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${var.aws_account_id}:trail/${local.name_prefix}-trail"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${var.aws_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.aws_region}:${var.aws_account_id}:trail/${local.name_prefix}-trail"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail.arn,
          "${aws_s3_bucket.cloudtrail.arn}/*"
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
        Resource  = "${aws_s3_bucket.cloudtrail.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.cloudtrail]
}


# =============================================================================
# CloudWatch Log Group for CloudTrail
# For real-time log analysis and alerting
# =============================================================================

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/${local.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_cloudwatch_arn

  tags = merge(local.common_tags, {
    Name    = "/aws/cloudtrail/${local.name_prefix}"
    Purpose = "CloudTrailLogs"
  })
}

# IAM Role for CloudTrail to write to CloudWatch Logs
resource "aws_iam_role" "cloudtrail_cloudwatch" {
  name = "${local.name_prefix}-cloudtrail-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cloudtrail-cloudwatch"
    Role = "CloudTrailCloudWatch"
  })
}

resource "aws_iam_role_policy" "cloudtrail_cloudwatch" {
  name = "${local.name_prefix}-cloudtrail-cloudwatch"
  role = aws_iam_role.cloudtrail_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# =============================================================================
# CloudTrail
# Requirements: 11.1 - Encryption enabled, log file validation
# =============================================================================

resource "aws_cloudtrail" "main" {
  name                          = "${local.name_prefix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = var.is_multi_region_trail
  enable_logging                = true

  # Log file validation for integrity
  # Requirements: 11.1
  enable_log_file_validation = true

  # KMS encryption for CloudTrail logs
  # Requirements: 11.1
  kms_key_id = var.kms_key_arn

  # CloudWatch Logs integration for real-time analysis
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  # Event selectors for management and data events
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Log S3 data events for audit trail
    dynamic "data_resource" {
      for_each = var.enable_s3_data_events ? [1] : []
      content {
        type   = "AWS::S3::Object"
        values = ["arn:aws:s3"]
      }
    }
  }

  # Advanced event selectors for more granular control (optional)
  dynamic "advanced_event_selector" {
    for_each = var.enable_advanced_event_selectors ? [1] : []
    content {
      name = "Log all management events"

      field_selector {
        field  = "eventCategory"
        equals = ["Management"]
      }
    }
  }

  # Insight selectors for anomaly detection (production only)
  dynamic "insight_selector" {
    for_each = local.is_production && var.enable_insights ? [1] : []
    content {
      insight_type = "ApiCallRateInsight"
    }
  }

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-trail"
    Purpose = "AuditLogging"
  })

  depends_on = [
    aws_s3_bucket_policy.cloudtrail,
    aws_iam_role_policy.cloudtrail_cloudwatch
  ]
}


# =============================================================================
# CloudWatch Alarms for CloudTrail Security Events
# Detect suspicious activity and security-related events
# =============================================================================

# SNS Topic for CloudTrail alerts
resource "aws_sns_topic" "cloudtrail_alerts" {
  count = var.enable_cloudtrail_alerts ? 1 : 0

  name              = "${local.name_prefix}-cloudtrail-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-cloudtrail-alerts"
    Purpose = "CloudTrailAlerts"
  })
}

# Metric filter for unauthorized API calls
resource "aws_cloudwatch_log_metric_filter" "unauthorized_api_calls" {
  count = var.enable_cloudtrail_alerts ? 1 : 0

  name           = "${local.name_prefix}-unauthorized-api-calls"
  pattern        = "{ ($.errorCode = \"*UnauthorizedAccess*\") || ($.errorCode = \"AccessDenied*\") }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "UnauthorizedAPICalls"
    namespace = "${local.name_prefix}/CloudTrail"
    value     = "1"
  }
}

# Alarm for unauthorized API calls
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  count = var.enable_cloudtrail_alerts ? 1 : 0

  alarm_name          = "${local.name_prefix}-unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "${local.name_prefix}/CloudTrail"
  period              = 300
  statistic           = "Sum"
  threshold           = var.unauthorized_api_calls_threshold
  alarm_description   = "Alarm when unauthorized API calls exceed threshold"
  alarm_actions       = [aws_sns_topic.cloudtrail_alerts[0].arn]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-unauthorized-api-calls-alarm"
  })
}

# Metric filter for root account usage
resource "aws_cloudwatch_log_metric_filter" "root_account_usage" {
  count = var.enable_cloudtrail_alerts ? 1 : 0

  name           = "${local.name_prefix}-root-account-usage"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "RootAccountUsage"
    namespace = "${local.name_prefix}/CloudTrail"
    value     = "1"
  }
}

# Alarm for root account usage
resource "aws_cloudwatch_metric_alarm" "root_account_usage" {
  count = var.enable_cloudtrail_alerts ? 1 : 0

  alarm_name          = "${local.name_prefix}-root-account-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "${local.name_prefix}/CloudTrail"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarm when root account is used"
  alarm_actions       = [aws_sns_topic.cloudtrail_alerts[0].arn]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-root-account-usage-alarm"
  })
}

# Metric filter for IAM policy changes
resource "aws_cloudwatch_log_metric_filter" "iam_policy_changes" {
  count = var.enable_cloudtrail_alerts ? 1 : 0

  name           = "${local.name_prefix}-iam-policy-changes"
  pattern        = "{ ($.eventName = DeleteGroupPolicy) || ($.eventName = DeleteRolePolicy) || ($.eventName = DeleteUserPolicy) || ($.eventName = PutGroupPolicy) || ($.eventName = PutRolePolicy) || ($.eventName = PutUserPolicy) || ($.eventName = CreatePolicy) || ($.eventName = DeletePolicy) || ($.eventName = CreatePolicyVersion) || ($.eventName = DeletePolicyVersion) || ($.eventName = AttachRolePolicy) || ($.eventName = DetachRolePolicy) || ($.eventName = AttachUserPolicy) || ($.eventName = DetachUserPolicy) || ($.eventName = AttachGroupPolicy) || ($.eventName = DetachGroupPolicy) }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "IAMPolicyChanges"
    namespace = "${local.name_prefix}/CloudTrail"
    value     = "1"
  }
}

# Alarm for IAM policy changes
resource "aws_cloudwatch_metric_alarm" "iam_policy_changes" {
  count = var.enable_cloudtrail_alerts ? 1 : 0

  alarm_name          = "${local.name_prefix}-iam-policy-changes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "IAMPolicyChanges"
  namespace           = "${local.name_prefix}/CloudTrail"
  period              = 300
  statistic           = "Sum"
  threshold           = var.iam_policy_changes_threshold
  alarm_description   = "Alarm when IAM policies are changed"
  alarm_actions       = [aws_sns_topic.cloudtrail_alerts[0].arn]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-iam-policy-changes-alarm"
  })
}

# Metric filter for security group changes
resource "aws_cloudwatch_log_metric_filter" "security_group_changes" {
  count = var.enable_cloudtrail_alerts ? 1 : 0

  name           = "${local.name_prefix}-security-group-changes"
  pattern        = "{ ($.eventName = AuthorizeSecurityGroupIngress) || ($.eventName = AuthorizeSecurityGroupEgress) || ($.eventName = RevokeSecurityGroupIngress) || ($.eventName = RevokeSecurityGroupEgress) || ($.eventName = CreateSecurityGroup) || ($.eventName = DeleteSecurityGroup) }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail.name

  metric_transformation {
    name      = "SecurityGroupChanges"
    namespace = "${local.name_prefix}/CloudTrail"
    value     = "1"
  }
}

# Alarm for security group changes
resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  count = var.enable_cloudtrail_alerts ? 1 : 0

  alarm_name          = "${local.name_prefix}-security-group-changes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityGroupChanges"
  namespace           = "${local.name_prefix}/CloudTrail"
  period              = 300
  statistic           = "Sum"
  threshold           = var.security_group_changes_threshold
  alarm_description   = "Alarm when security groups are changed"
  alarm_actions       = [aws_sns_topic.cloudtrail_alerts[0].arn]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-security-group-changes-alarm"
  })
}
