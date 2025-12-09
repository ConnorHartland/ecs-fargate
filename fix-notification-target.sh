#!/bin/bash
# Fix unreachable notification target by recreating it

RULE_ARN="arn:aws:codestar-notifications:us-east-1:664271361680:notificationrule/473148d57b8de5d25e1f81ff190b81e338fa54c0"
TOPIC_ARN="arn:aws:sns:us-east-1:664271361680:ecs-fargate-develop-pipeline-notifications"

echo "=== Fixing Unreachable Notification Target ==="
echo ""

echo "Step 1: Get current notification rule configuration..."
RULE=$(aws codestar-notifications describe-notification-rule --arn "$RULE_ARN" --output json)
echo "Current status: $(echo "$RULE" | jq -r '.Status')"
echo "Current target status: $(echo "$RULE" | jq -r '.Targets[0].TargetStatus')"
echo ""

echo "Step 2: Remove the unreachable target..."
aws codestar-notifications unsubscribe \
  --arn "$RULE_ARN" \
  --target-address "$TOPIC_ARN"

if [ $? -eq 0 ]; then
    echo "✅ Target removed"
else
    echo "⚠️  Target removal failed or target already removed"
fi
echo ""

echo "Step 3: Wait 2 seconds..."
sleep 2
echo ""

echo "Step 4: Re-add the target..."
aws codestar-notifications subscribe \
  --arn "$RULE_ARN" \
  --target '{
    "TargetType": "SNS",
    "TargetAddress": "'"$TOPIC_ARN"'"
  }'

if [ $? -eq 0 ]; then
    echo "✅ Target re-added"
else
    echo "❌ Failed to re-add target"
    exit 1
fi
echo ""

echo "Step 5: Wait 2 seconds for validation..."
sleep 2
echo ""

echo "Step 6: Verify target status..."
NEW_STATUS=$(aws codestar-notifications describe-notification-rule \
  --arn "$RULE_ARN" \
  --query 'Targets[0].TargetStatus' \
  --output text)

echo "New target status: $NEW_STATUS"
echo ""

if [ "$NEW_STATUS" = "ACTIVE" ]; then
    echo "✅ SUCCESS! Target is now ACTIVE"
    echo ""
    echo "Notifications should now work. Test by triggering a pipeline:"
    echo "aws codepipeline start-pipeline-execution --name ecs-fargate-develop-service-1-pipeline"
elif [ "$NEW_STATUS" = "PENDING" ]; then
    echo "⏳ Target is PENDING validation. Wait 30 seconds and check again:"
    echo "aws codestar-notifications describe-notification-rule --arn $RULE_ARN --query 'Targets[0].TargetStatus' --output text"
else
    echo "❌ Target is still: $NEW_STATUS"
    echo ""
    echo "This means there's still a permission issue. Let's verify the SNS topic policy..."
    echo ""
    aws sns get-topic-attributes --topic-arn "$TOPIC_ARN" --query 'Attributes.Policy' --output text | jq '.'
fi
