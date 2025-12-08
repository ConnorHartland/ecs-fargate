#!/bin/bash
# Script to create Terraform backend infrastructure in us-east-1
# This creates the exact bucket name referenced in backend.hcl files

set -e

BUCKET_NAME="con-ecs-fargate-terraform-state"
TABLE_NAME="con-ecs-fargate-terraform-state-lock"
REGION="us-east-1"

echo "=== Creating Terraform Backend in us-east-1 ==="
echo "Bucket: ${BUCKET_NAME}"
echo "Table: ${TABLE_NAME}"
echo "Region: ${REGION}"
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

# Create DynamoDB table
echo "Creating DynamoDB table..."
aws dynamodb create-table \
  --table-name "${TABLE_NAME}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "${REGION}" \
  --tags Key=Project,Value=ecs-fargate Key=ManagedBy,Value=Terraform \
  2>/dev/null && echo "✓ DynamoDB table created" || echo "⚠ Table already exists or creation failed"

echo ""
echo "=== Backend Setup Complete ==="
echo ""
echo "You can now initialize Terraform with:"
echo "  cd terraform"
echo "  terraform init -backend-config=environments/develop/backend.hcl"
