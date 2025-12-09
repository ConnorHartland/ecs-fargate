#!/bin/bash
# Script to create Terraform backend infrastructure in us-east-1
# This creates the S3 bucket for state storage (no DynamoDB locking)

set -e

BUCKET_NAME="con-ecs-fargate-terraform-state"
REGION="us-east-1"

echo "=== Creating Terraform Backend in us-east-1 ==="
echo "Bucket: ${BUCKET_NAME}"
echo "Region: ${REGION}"
echo "Note: DynamoDB locking disabled to avoid state lock issues"
echo ""

# Create S3 bucket in us-east-1
echo "Creating S3 bucket..."
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}" \
  2>/dev/null && echo "✓ Bucket created" || echo "⚠ Bucket already exists or creation failed"

# Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}" \
  --versioning-configuration Status=Enabled \
  && echo "✓ Versioning enabled"

# Enable encryption
echo "Enabling encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }' \
  && echo "✓ Encryption enabled"

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}" \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }' \
  && echo "✓ Public access blocked"

echo ""
echo "=== Backend Setup Complete ==="
echo ""
echo "You can now initialize Terraform with:"
echo "  cd terraform"
echo "  terraform init -backend-config=environments/develop/backend.hcl"
echo ""
echo "Note: DynamoDB state locking is disabled. This is fine for solo development"
echo "but be careful if multiple people are running Terraform simultaneously."
