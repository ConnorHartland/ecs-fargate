#!/bin/bash
# Script to clean up service-1 resources in develop environment

set -e

SERVICE="service-1"
ENV="develop"
PROJECT="ecs-fargate"
REGION="us-east-1"

echo "=== Cleaning up ${SERVICE} in ${ENV} environment ==="
echo ""

# Delete ECS Service first (if exists)
echo "Deleting ECS Service..."
aws ecs delete-service \
  --cluster "${PROJECT}-${ENV}-cluster" \
  --service "${SERVICE}" \
  --force \
  --region ${REGION} 2>/dev/null || echo "  ECS service not found"

# Wait a bit for service deletion
sleep 5

# Delete Target Group
echo ""
echo "Deleting Target Group..."
TG_ARN=$(aws elbv2 describe-target-groups \
  --names "${PROJECT}-${ENV}-${SERVICE}-tg" \
  --region ${REGION} \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null) || true

if [ "$TG_ARN" != "None" ] && [ -n "$TG_ARN" ]; then
  aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region ${REGION} 2>/dev/null || echo "  Target group not found"
else
  echo "  Target group not found"
fi

# Delete ECR Repository
echo ""
echo "Deleting ECR Repository..."
aws ecr delete-repository \
  --repository-name "${PROJECT}-${ENV}-${SERVICE}" \
  --force \
  --region ${REGION} 2>/dev/null || echo "  ECR repository not found"

# Delete CloudWatch Log Group
echo ""
echo "Deleting CloudWatch Log Group..."
aws logs delete-log-group \
  --log-group-name "/ecs/${SERVICE}" \
  --region ${REGION} 2>/dev/null || echo "  Log group not found"

# Delete IAM Role
echo ""
echo "Deleting IAM Role..."
ROLE_NAME="${PROJECT}-${ENV}-${SERVICE}-task"

# Detach managed policies
echo "  Detaching policies from ${ROLE_NAME}..."
aws iam list-attached-role-policies --role-name "${ROLE_NAME}" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null | \
  xargs -r -n1 aws iam detach-role-policy --role-name "${ROLE_NAME}" --policy-arn 2>/dev/null || true

# Delete inline policies
aws iam list-role-policies --role-name "${ROLE_NAME}" --query 'PolicyNames[]' --output text 2>/dev/null | \
  xargs -r -n1 aws iam delete-role-policy --role-name "${ROLE_NAME}" --policy-name 2>/dev/null || true

# Delete role
aws iam delete-role --role-name "${ROLE_NAME}" 2>/dev/null || echo "  Role ${ROLE_NAME} not found"

# Delete CodePipeline (if exists)
echo ""
echo "Deleting CodePipeline..."
aws codepipeline delete-pipeline \
  --name "${PROJECT}-${ENV}-${SERVICE}-pipeline" \
  --region ${REGION} 2>/dev/null || echo "  Pipeline not found"

# Delete CodeBuild Project (if exists)
echo ""
echo "Deleting CodeBuild Project..."
aws codebuild delete-project \
  --name "${PROJECT}-${ENV}-${SERVICE}-build" \
  --region ${REGION} 2>/dev/null || echo "  CodeBuild project not found"

# Delete CodeBuild Log Group
echo ""
echo "Deleting CodeBuild Log Group..."
aws logs delete-log-group \
  --log-group-name "/aws/codebuild/${PROJECT}-${ENV}-${SERVICE}-build" \
  --region ${REGION} 2>/dev/null || echo "  CodeBuild log group not found"

echo ""
echo "=== Service-1 Cleanup Complete ==="
echo ""
echo "You can now run:"
echo "  cd terraform/services/service-1"
echo "  terraform apply"
