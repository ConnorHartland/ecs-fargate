# Backend configuration for Terraform state management
# This file defines the S3 backend with encryption (no DynamoDB locking)
#
# Usage: Initialize with environment-specific backend config:
#   terraform init -backend-config=environments/develop/backend.hcl
#   terraform init -backend-config=environments/prod/backend.hcl

# Note: The actual backend block is in main.tf
# This file documents the backend infrastructure requirements

# =============================================================================
# Backend Infrastructure Requirements
# =============================================================================
#
# Before using this Terraform configuration, ensure the following resources exist:
#
# 1. S3 Bucket for state storage:
#    - Bucket name: ${project_name}-terraform-state-${aws_account_id}
#    - Versioning: Enabled (recommended for state recovery)
#    - Encryption: AES256 or KMS
#    - Public access: Blocked
#
# Note: DynamoDB state locking is disabled to avoid lock conflicts.
# This is suitable for solo development but be careful with concurrent operations.
#
# =============================================================================
# Bootstrap Script
# =============================================================================
#
# Run the following AWS CLI commands to create backend infrastructure:
#
# # Create S3 bucket
# aws s3api create-bucket \
#   --bucket ${project_name}-terraform-state-${aws_account_id} \
#   --region us-east-1
#
# # Enable versioning (recommended for state recovery)
# aws s3api put-bucket-versioning \
#   --bucket ${project_name}-terraform-state-${aws_account_id} \
#   --versioning-configuration Status=Enabled
#
# # Enable encryption
# aws s3api put-bucket-encryption \
#   --bucket ${project_name}-terraform-state-${aws_account_id} \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {
#         "SSEAlgorithm": "AES256"
#       }
#     }]
#   }'
#
# # Block public access
# aws s3api put-public-access-block \
#   --bucket ${project_name}-terraform-state-${aws_account_id} \
#   --public-access-block-configuration '{
#     "BlockPublicAcls": true,
#     "IgnorePublicAcls": true,
#     "BlockPublicPolicy": true,
#     "RestrictPublicBuckets": true
#   }'
#
# Or use the bootstrap script:
#   ./scripts/bootstrap-backend.sh us-east-1
