# Backend configuration for Terraform state management
# This file defines the S3 backend with encryption and DynamoDB state locking
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
#    - Versioning: Enabled
#    - Encryption: AES256 or KMS
#    - Public access: Blocked
#
# 2. DynamoDB Table for state locking:
#    - Table name: ${project_name}-terraform-state-lock
#    - Partition key: LockID (String)
#    - Billing mode: PAY_PER_REQUEST
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
# # Enable versioning
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
# # Create DynamoDB table for state locking
# aws dynamodb create-table \
#   --table-name ${project_name}-terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1
