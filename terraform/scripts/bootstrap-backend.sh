#!/bin/bash
# Bootstrap script for creating Terraform backend infrastructure
# This script creates the S3 bucket and DynamoDB table required for state management
#
# Usage: ./bootstrap-backend.sh <aws-region> <aws-account-id>
# Example: ./bootstrap-backend.sh us-east-1 123456789012

set -e

# Configuration
PROJECT_NAME="ecs-fargate"
REGION="${1:-us-east-1}"
ACCOUNT_ID="${2:-$(aws sts get-caller-identity --query Account --output text)}"
BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ACCOUNT_ID}"
TABLE_NAME="${PROJECT_NAME}-terraform-state-lock"

echo "=== Terraform Backend Bootstrap ==="
echo "Region: ${REGION}"
echo "Account ID: ${ACCOUNT_ID}"
echo "S3 Bucket: ${BUCKET_NAME}"
echo "DynamoDB Table: ${TABLE_NAME}"
echo ""

# Create S3 bucket
echo "Creating S3 bucket for Terraform state..."
if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${REGION}" \
        2>/dev/null || echo "Bucket already exists or creation failed"
else
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${REGION}" \
        --create-bucket-configuration LocationConstraint="${REGION}" \
        2>/dev/null || echo "Bucket already exists or creation failed"
fi

# Enable versioning
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

# Enable encryption
echo "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'

# Block public access
echo "Blocking public access on S3 bucket..."
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'

# Create DynamoDB table for state locking
echo "Creating DynamoDB table for state locking..."
aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" \
    --tags Key=Project,Value="${PROJECT_NAME}" Key=ManagedBy,Value=Terraform \
    2>/dev/null || echo "Table already exists or creation failed"

echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "Update your backend.hcl files with:"
echo "  bucket         = \"${BUCKET_NAME}\""
echo "  dynamodb_table = \"${TABLE_NAME}\""
echo "  region         = \"${REGION}\""
echo ""
echo "Initialize Terraform with:"
echo "  cd terraform"
echo "  terraform init -backend-config=environments/develop/backend.hcl"
