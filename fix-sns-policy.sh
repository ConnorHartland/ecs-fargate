#!/bin/bash
# Fix SNS policy to allow CodeStar Notifications to subscribe

TOPIC_ARN="arn:aws:sns:us-east-1:664271361680:ecs-fargate-develop-pipeline-notifications"
ACCOUNT_ID="664271361680"

echo "=== Updating SNS Topic Policy ==="
echo "Adding Subscribe permission for CodeStar Notifications..."
echo ""

aws sns set-topic-attributes \
  --topic-arn "$TOPIC_ARN" \
  --attribute-name Policy \
  --attribute-value '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowAccountOwner",
        "Effect": "Allow",
        "Principal": {"AWS": "*"},
        "Action": [
          "SNS:GetTopicAttributes",
          "SNS:SetTopicAttributes",
          "SNS:AddPermission",
          "SNS:RemovePermission",
          "SNS:DeleteTopic",
          "SNS:Subscribe",
          "SNS:ListSubscriptionsByTopic",
          "SNS:Publish"
        ],
        "Resource": "'"$TOPIC_ARN"'",
        "Condition": {
          "StringEquals": {"AWS:SourceOwner": "'"$ACCOUNT_ID"'"}
        }
      },
      {
        "Sid": "AllowCodeStarNotifications",
        "Effect": "Allow",
        "Principal": {"Service": "codestar-notifications.amazonaws.com"},
        "Action": [
          "SNS:Publish",
          "SNS:Subscribe"
        ],
        "Resource": "'"$TOPIC_ARN"'",
        "Condition": {
          "StringEquals": {"aws:SourceAccount": "'"$ACCOUNT_ID"'"}
        }
      }
    ]
  }'

if [ $? -eq 0 ]; then
    echo "✅ Policy updated successfully"
else
    echo "❌ Failed to update policy"
    exit 1
fi

echo ""
echo "Waiting 3 seconds for policy to propagate..."
sleep 3
echo ""

echo "Now re-subscribing the notification target..."
RULE_ARN="arn:aws:codestar-notifications:us-east-1:664271361680:notificationrule/473148d57b8de5d25e1f81ff190b81e338fa54c0"

# Remove old target
aws codestar-notifications unsubscribe \
  --arn "$RULE_ARN" \
  --target-address "$TOPIC_ARN" 2>/dev/null

sleep 2

# Re-add target
aws codestar-notifications subscribe \
  --arn "$RULE_ARN" \
  --target '{
    "TargetType": "SNS",
    "TargetAddress": "'"$TOPIC_ARN"'"
  }'

echo ""
echo "Waiting 3 seconds for validation..."
sleep 3
echo ""

echo "Checking target status..."
STATUS=$(aws codestar-notifications describe-notification-rule \
  --arn "$RULE_ARN" \
  --query 'Targets[0].TargetStatus' \
  --output text)

echo "Target status: $STATUS"
echo ""

if [ "$STATUS" = "ACTIVE" ]; then
    echo "✅ SUCCESS! Notifications are now configured correctly."
    echo ""
    echo "Test it:"
    echo "aws codepipeline start-pipeline-execution --name ecs-fargate-develop-service-1-pipeline"
else
    echo "❌ Still $STATUS"
    echo ""
    echo "Let's check CloudTrail for permission errors..."
    echo "aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=$TOPIC_ARN --max-results 5"
fi
