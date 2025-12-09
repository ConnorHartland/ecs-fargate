#!/bin/bash
# Bootstrap script for creating Terraform backend infrastructure
# This script creates the S3 bucket for state management (no DynamoDB locking)
#
# Usage: ./bootstrap-backend.sh <aws-region> <aws-account-id>
# Example: ./bootstrap-backend.sh us-east-1 123456789012

set -e

# Configuration
PROJECT_NAME="ecs-fargate"
REGION="${1:-us-east-1}"
ACCOUNT_ID="${2:-$(aws sts get-caller-identity --query Account --output text)}"
BUCKET_NAME="${PROJECT_NAME}-terraform-state-${ACCOUNT_ID}"

echo "=== Terraform Backend Bootstrap ==="
echo "Region: ${REGION}"
echo "Account ID: ${ACCOUNT_ID}"
echo "S3 Bucket: ${BUCKET_NAME}"
echo "Note: DynamoDB locking disabled to avoid state lock issues"
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

echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "Update your backend.hcl files with:"
echo "  bucket  = \"${BUCKET_NAME}\""
echo "  region  = \"${REGION}\""
echo "  encrypt = true"
echo ""
echo "Initialize Terraform with:"
echo "  cd terraform"
echo "  terraform init -backend-config=environments/develop/backend.hcl"
echo ""
echo "Note: DynamoDB state locking is disabled. This is fine for solo development"
echo "but be careful if multiple people are running Terraform simultaneously."
