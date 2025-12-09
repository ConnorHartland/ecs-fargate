#!/bin/bash
# Script to clean up existing develop environment resources
# Run this to remove all resources before fresh terraform apply

set -e

ENV="develop"
PROJECT="ecs-fargate"
REGION="us-east-1"

echo "=== Cleaning up ${ENV} environment resources ==="
echo "This will delete resources that are blocking Terraform"
echo ""

# Delete CloudTrail
echo "Deleting CloudTrail..."
aws cloudtrail delete-trail --name "${PROJECT}-${ENV}-trail" --region ${REGION} 2>/dev/null || echo "  CloudTrail ${PROJECT}-${ENV}-trail not found"

# Delete CloudWatch Log Groups
echo ""
echo "Deleting CloudWatch Log Groups..."
aws logs delete-log-group --log-group-name "/aws/cloudtrail/${PROJECT}-${ENV}" --region ${REGION} 2>/dev/null || echo "  Log group /aws/cloudtrail/${PROJECT}-${ENV} not found"
aws logs delete-log-group --log-group-name "/ecs/${PROJECT}-${ENV}-cluster/execute-command" --region ${REGION} 2>/dev/null || echo "  Log group /ecs/${PROJECT}-${ENV}-cluster/execute-command not found"
aws logs delete-log-group --log-group-name "/ecs/${PROJECT}-${ENV}-cluster" --region ${REGION} 2>/dev/null || echo "  Log group /ecs/${PROJECT}-${ENV}-cluster not found"
aws logs delete-log-group --log-group-name "/aws/vpc/${PROJECT}-${ENV}-flow-logs" --region ${REGION} 2>/dev/null || echo "  Log group /aws/vpc/${PROJECT}-${ENV}-flow-logs not found"

# Delete IAM Roles (must detach policies first)
echo ""
echo "Deleting IAM Roles..."

# Function to delete IAM role with all attached policies
delete_iam_role() {
  local role_name=$1
  echo "  Deleting role: ${role_name}"
  
  # Detach managed policies
  aws iam list-attached-role-policies --role-name "${role_name}" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | \
    xargs -r -n1 aws iam detach-role-policy --role-name "${role_name}" --policy-arn 2>/dev/null || true
  
  # Delete inline policies
  aws iam list-role-policies --role-name "${role_name}" --query 'PolicyNames[]' --output text 2>/dev/null | \
    xargs -r -n1 aws iam delete-role-policy --role-name "${role_name}" --policy-name 2>/dev/null || true
  
  # Delete role
  aws iam delete-role --role-name "${role_name}" 2>/dev/null || echo "    Role ${role_name} not found"
}

delete_iam_role "${PROJECT}-${ENV}-cloudtrail-cloudwatch"
delete_iam_role "${PROJECT}-${ENV}-config"
delete_iam_role "${PROJECT}-${ENV}-vpc-flow-logs-role"
delete_iam_role "${PROJECT}-${ENV}-ecs-task-execution"
delete_iam_role "${PROJECT}-${ENV}-ecs-task"
delete_iam_role "${PROJECT}-${ENV}-codebuild"
delete_iam_role "${PROJECT}-${ENV}-codepipeline"

# Delete KMS Aliases (not the keys, just aliases)
echo ""
echo "Deleting KMS Aliases..."
aws kms delete-alias --alias-name "alias/${PROJECT}-${ENV}-ecs" --region ${REGION} 2>/dev/null || echo "  Alias alias/${PROJECT}-${ENV}-ecs not found"
aws kms delete-alias --alias-name "alias/${PROJECT}-${ENV}-ecr" --region ${REGION} 2>/dev/null || echo "  Alias alias/${PROJECT}-${ENV}-ecr not found"
aws kms delete-alias --alias-name "alias/${PROJECT}-${ENV}-secrets" --region ${REGION} 2>/dev/null || echo "  Alias alias/${PROJECT}-${ENV}-secrets not found"
aws kms delete-alias --alias-name "alias/${PROJECT}-${ENV}-cloudwatch" --region ${REGION} 2>/dev/null || echo "  Alias alias/${PROJECT}-${ENV}-cloudwatch not found"
aws kms delete-alias --alias-name "alias/${PROJECT}-${ENV}-s3" --region ${REGION} 2>/dev/null || echo "  Alias alias/${PROJECT}-${ENV}-s3 not found"

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "You can now run:"
echo "  cd terraform"
echo "  terraform init -reconfigure -backend-config=environments/develop/backend.hcl"
echo "  terraform apply"
