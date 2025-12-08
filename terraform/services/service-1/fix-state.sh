#!/bin/bash
# Fix state checksum mismatch

set -e

echo "=========================================="
echo "Fixing state checksum mismatch"
echo "=========================================="

# Remove local state
echo "Removing local state files..."
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f terraform.tfstate*

# Delete the corrupted state from S3
echo "Deleting corrupted state from S3..."
aws s3 rm s3://con-ecs-fargate-terraform-state/develop/services/service-1/terraform.tfstate || true

# Delete the DynamoDB lock entry
echo "Deleting DynamoDB lock entry..."
aws dynamodb delete-item \
  --table-name con-ecs-fargate-terraform-state-lock \
  --key '{"LockID":{"S":"con-ecs-fargate-terraform-state/develop/services/service-1/terraform.tfstate-md5"}}' \
  2>/dev/null || true

echo ""
echo "✓ State cleaned up"
echo ""
echo "Now run: ./deploy.sh"
