#!/bin/bash
# Script to migrate the S3 bucket from us-east-2 to us-east-1

set -e

BUCKET_NAME="ecs-fargate-terraform-state"
OLD_REGION="us-east-2"
NEW_REGION="us-east-1"

echo "=== Migrating S3 Bucket from ${OLD_REGION} to ${NEW_REGION} ==="
echo "Bucket: ${BUCKET_NAME}"
echo ""

# Check if bucket has any objects
echo "Checking bucket contents in ${OLD_REGION}..."
OBJECT_COUNT=$(aws s3 ls s3://${BUCKET_NAME}/ --region ${OLD_REGION} 2>/dev/null | wc -l || echo "0")

if [ "$OBJECT_COUNT" -gt 0 ]; then
    echo "⚠ WARNING: Bucket contains $OBJECT_COUNT objects"
    echo "Contents:"
    aws s3 ls s3://${BUCKET_NAME}/ --region ${OLD_REGION} --recursive
    echo ""
    read -p "Do you want to delete this bucket and all its contents? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Migration cancelled"
        exit 1
    fi
else
    echo "✓ Bucket is empty"
fi

# Delete the bucket in us-east-2
echo "Deleting bucket in ${OLD_REGION}..."
aws s3 rb s3://${BUCKET_NAME} --region ${OLD_REGION} --force \
  && echo "✓ Bucket deleted from ${OLD_REGION}" \
  || echo "⚠ Failed to delete bucket (it may not exist)"

# Wait a moment for AWS to propagate the deletion
echo "Waiting for deletion to propagate..."
sleep 5

# Create bucket in us-east-1
echo "Creating bucket in ${NEW_REGION}..."
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${NEW_REGION}" \
  && echo "✓ Bucket created in ${NEW_REGION}"

# Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --region "${NEW_REGION}" \
  --versioning-configuration Status=Enabled \
  && echo "✓ Versioning enabled"

# Enable encryption
echo "Enabling encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --region "${NEW_REGION}" \
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
  --region "${NEW_REGION}" \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }' \
  && echo "✓ Public access blocked"

echo ""
echo "=== Migration Complete ==="
echo ""
echo "Bucket ${BUCKET_NAME} is now in ${NEW_REGION}"
echo ""
echo "You can now initialize Terraform with:"
echo "  terraform init -backend-config=environments/develop/backend.hcl"
