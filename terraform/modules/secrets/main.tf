# Secrets Manager Module - Main Resources
# Creates Secrets Manager secrets with KMS encryption and rotation configuration

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.tags, {
    Module = "secrets"
  })
}

# =============================================================================
# Secrets Manager Secret
# =============================================================================

resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name        = "${local.name_prefix}-${each.key}"
  description = each.value.description
  kms_key_id  = var.kms_key_arn

  # Recovery window for deletion (7-30 days, or 0 for immediate deletion in non-prod)
  recovery_window_in_days = var.environment == "prod" ? var.recovery_window_days : 0

  # Force overwrite of secret if it exists during recreation
  force_overwrite_replica_secret = false

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-${each.key}"
    SecretType  = each.value.secret_type
    ServiceName = lookup(each.value, "service_name", "shared")
  })
}

# =============================================================================
# Secrets Manager Secret Version
# Initial secret value (should be updated manually or via rotation)
# =============================================================================

resource "aws_secretsmanager_secret_version" "this" {
  for_each = var.secrets

  secret_id = aws_secretsmanager_secret.this[each.key].id

  # Use secret_string for key-value pairs, secret_binary for binary data
  secret_string = jsonencode(each.value.initial_value)

  lifecycle {
    # Ignore changes to secret value after initial creation
    # Secrets should be updated manually or via rotation
    ignore_changes = [secret_string]
  }
}


# =============================================================================
# Secrets Manager Secret Rotation
# Configures automatic rotation for supported secret types
# =============================================================================

resource "aws_secretsmanager_secret_rotation" "this" {
  for_each = {
    for k, v in var.secrets : k => v
    if v.enable_rotation && v.rotation_lambda_arn != null
  }

  secret_id           = aws_secretsmanager_secret.this[each.key].id
  rotation_lambda_arn = each.value.rotation_lambda_arn

  rotation_rules {
    # Rotate every N days
    automatically_after_days = each.value.rotation_days

    # Optional: Schedule expression for rotation (cron or rate)
    schedule_expression = lookup(each.value, "rotation_schedule", null)
  }
}

# =============================================================================
# IAM Policy for Secret Access
# Grants read-only access to specific secrets
# =============================================================================

data "aws_iam_policy_document" "secret_read_policy" {
  statement {
    sid    = "GetSecretValue"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      for secret in aws_secretsmanager_secret.this : secret.arn
    ]
  }

  statement {
    sid    = "DecryptSecret"
    effect = "Allow"

    actions = [
      "kms:Decrypt"
    ]

    resources = [
      var.kms_key_arn
    ]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "secret_read" {
  count = length(var.secrets) > 0 ? 1 : 0

  name        = "${local.name_prefix}-secrets-read"
  description = "Policy to read secrets from Secrets Manager for ${local.name_prefix}"
  policy      = data.aws_iam_policy_document.secret_read_policy.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-secrets-read"
  })
}

# =============================================================================
# Service-Specific IAM Policies
# Creates individual policies for each service to access only their secrets
# =============================================================================

data "aws_iam_policy_document" "service_secret_policy" {
  for_each = toset(distinct([
    for k, v in var.secrets : v.service_name
    if v.service_name != null && v.service_name != "shared"
  ]))

  statement {
    sid    = "GetServiceSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      for k, v in var.secrets : aws_secretsmanager_secret.this[k].arn
      if v.service_name == each.key || v.service_name == "shared"
    ]
  }

  statement {
    sid    = "DecryptServiceSecrets"
    effect = "Allow"

    actions = [
      "kms:Decrypt"
    ]

    resources = [
      var.kms_key_arn
    ]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "service_secret" {
  for_each = toset(distinct([
    for k, v in var.secrets : v.service_name
    if v.service_name != null && v.service_name != "shared"
  ]))

  name        = "${local.name_prefix}-${each.key}-secrets"
  description = "Policy for ${each.key} service to read its secrets"
  policy      = data.aws_iam_policy_document.service_secret_policy[each.key].json

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-${each.key}-secrets"
    ServiceName = each.key
  })
}

# =============================================================================
# Secret Resource Policy
# Controls who can access the secret at the resource level
# =============================================================================

resource "aws_secretsmanager_secret_policy" "this" {
  for_each = {
    for k, v in var.secrets : k => v
    if v.resource_policy != null
  }

  secret_arn = aws_secretsmanager_secret.this[each.key].arn
  policy     = each.value.resource_policy
}
