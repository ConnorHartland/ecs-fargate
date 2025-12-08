#!/bin/bash
# Import existing resources into Terraform state

set -e

echo "=========================================="
echo "Importing existing service-1 resources"
echo "=========================================="

# Import ECR repository
echo "Importing ECR repository..."
terraform import 'module.service_1.module.ecr.aws_ecr_repository.this' ecs-fargate-develop-service-1 || true

# Import CloudWatch log group
echo "Importing CloudWatch log group..."
terraform import 'module.service_1.module.task_definition.aws_cloudwatch_log_group.container' /ecs/service-1 || true

# Import IAM role
echo "Importing IAM role..."
terraform import 'module.service_1.module.task_definition.aws_iam_role.task[0]' ecs-fargate-develop-service-1-task || true

# Import security group
echo "Importing security group..."
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=ecs-fargate-develop-service-1-sg" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)
if [ "$SG_ID" != "None" ] && [ -n "$SG_ID" ]; then
  terraform import "module.service_1.aws_security_group.service" "$SG_ID" || true
fi

# Import target group
echo "Importing target group..."
TG_ARN=$(aws elbv2 describe-target-groups \
  --names ecs-fargate-develop-service-1-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text 2>/dev/null || echo "")
if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
  terraform import 'module.service_1.aws_lb_target_group.service[0]' "$TG_ARN" || true
fi

echo ""
echo "✓ Import complete"
echo ""
echo "Now run: terraform plan"
