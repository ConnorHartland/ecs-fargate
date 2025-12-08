# ALB Module - Main Resources
# Creates Application Load Balancer for public-facing services

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Enable deletion protection for production by default
  deletion_protection = var.enable_deletion_protection != null ? var.enable_deletion_protection : (var.environment == "prod")

  # Create bucket name if not provided
  access_logs_bucket = var.access_logs_bucket_name != "" ? var.access_logs_bucket_name : "${local.name_prefix}-alb-logs"

  # Standardize ALB logs path for consistency across bucket policy and ALB configuration
  # Ensures trailing slash is handled correctly
  alb_logs_prefix = var.access_logs_prefix != "" ? var.access_logs_prefix : ""
  alb_logs_path_pattern = var.access_logs_prefix != "" ? "${var.access_logs_prefix}/*" : "*"

  common_tags = merge(var.tags, {
    Module = "alb"
  })
}

# =============================================================================
# Data Sources
# =============================================================================

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# ELB service account for access logs
data "aws_elb_service_account" "main" {}

# =============================================================================
# S3 Bucket for ALB Access Logs
# =============================================================================

resource "aws_s3_bucket" "access_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = local.access_logs_bucket

  tags = merge(local.common_tags, {
    Name    = local.access_logs_bucket
    Purpose = "ALBAccessLogs"
  })
}

resource "aws_s3_bucket_versioning" "access_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_s3_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_s3_arn != "" ? var.kms_key_s3_arn : null
    }
    bucket_key_enabled = var.kms_key_s3_arn != "" ? true : false
  }
}


resource "aws_s3_bucket_public_access_block" "access_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "access_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = var.environment == "prod" ? 365 : 180
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.access_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowELBAccessLogs"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.access_logs[0].arn}/*"
      },
      {
        Sid    = "AllowELBServiceAccountAclCheck"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.access_logs[0].arn
      },
      {
        Sid    = "AllowALBServiceAccount"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.access_logs[0].arn}/*"
      },
      {
        Sid    = "AllowALBServiceAccountAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.access_logs[0].arn
      },
      {
        Sid    = "AllowLogDeliveryService"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.access_logs[0].arn}/*"
      },
      {
        Sid    = "AllowLogDeliveryServiceAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.access_logs[0].arn
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.access_logs,
    aws_s3_bucket_ownership_controls.access_logs
  ]
}

# =============================================================================
# ALB Security Group
# =============================================================================

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress rule for HTTP (port 80)
resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP traffic from allowed CIDR blocks"
}

# Ingress rule for HTTPS (port 443)
resource "aws_security_group_rule" "alb_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS traffic from allowed CIDR blocks"
}

# Egress rule - allow all outbound traffic to VPC
resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"
}

# =============================================================================
# Application Load Balancer
# =============================================================================

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = local.deletion_protection
  drop_invalid_header_fields       = var.drop_invalid_header_fields
  enable_http2                     = var.enable_http2
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  idle_timeout                     = var.idle_timeout

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = aws_s3_bucket.access_logs[0].id
      prefix  = local.alb_logs_prefix
      enabled = true
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })

  depends_on = [
    aws_s3_bucket_policy.access_logs,
    aws_s3_bucket_public_access_block.access_logs
  ]
}


# =============================================================================
# HTTPS Listener (Port 443)
# =============================================================================

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "No route configured"
      status_code  = "404"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-https-listener"
  })
}

# =============================================================================
# HTTP Listener (Port 80) - Redirect to HTTPS
# =============================================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-http-listener"
  })
}

# =============================================================================
# Target Groups for Public Services
# =============================================================================

resource "aws_lb_target_group" "services" {
  for_each = var.target_groups

  name        = "${local.name_prefix}-${each.key}-tg"
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  # Deregistration delay - allows in-flight requests to complete
  deregistration_delay = each.value.deregistration_delay

  # Slow start duration - gradually increases traffic to new targets
  slow_start = each.value.slow_start

  # Health check configuration
  health_check {
    enabled             = true
    path                = each.value.health_check_path
    port                = each.value.health_check_port
    protocol            = each.value.health_check_protocol
    interval            = each.value.health_check_interval
    timeout             = each.value.health_check_timeout
    healthy_threshold   = each.value.healthy_threshold
    unhealthy_threshold = each.value.unhealthy_threshold
    matcher             = each.value.health_check_matcher
  }

  # Stickiness configuration (disabled by default for stateless services)
  dynamic "stickiness" {
    for_each = each.value.stickiness_enabled ? [1] : []
    content {
      type            = each.value.stickiness_type
      cookie_duration = each.value.stickiness_cookie_duration
      enabled         = true
    }
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-${each.key}-tg"
    ServiceName = each.key
  })

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# Listener Rules for Path-Based Routing
# =============================================================================

resource "aws_lb_listener_rule" "services" {
  for_each = var.target_groups

  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  # Path-based routing condition
  dynamic "condition" {
    for_each = length(each.value.path_patterns) > 0 ? [1] : []
    content {
      path_pattern {
        values = each.value.path_patterns
      }
    }
  }

  # Host-based routing condition (optional)
  dynamic "condition" {
    for_each = length(each.value.host_headers) > 0 ? [1] : []
    content {
      host_header {
        values = each.value.host_headers
      }
    }
  }

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-${each.key}-rule"
    ServiceName = each.key
  })

  depends_on = [aws_lb_target_group.services]
}
