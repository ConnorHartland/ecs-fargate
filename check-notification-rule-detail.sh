#!/bin/bash
# Check notification rule detail type

RULE_ARN="arn:aws:codestar-notifications:us-east-1:664271361680:notificationrule/473148d57b8de5d25e1f81ff190b81e338fa54c0"

echo "=== Notification Rule Configuration ==="
RULE=$(aws codestar-notifications describe-notification-rule --arn "$RULE_ARN" --output json)

echo "Name: $(echo "$RULE" | jq -r '.Name')"
echo "Status: $(echo "$RULE" | jq -r '.Status')"
echo "Detail Type: $(echo "$RULE" | jq -r '.DetailType')"
echo ""

DETAIL_TYPE=$(echo "$RULE" | jq -r '.DetailType')

if [ "$DETAIL_TYPE" = "BASIC" ]; then
    echo "⚠️  FOUND THE ISSUE!"
    echo ""
    echo "The notification rule is set to 'BASIC' detail type."
    echo "This means it sends minimal information and may not trigger for all events."
    echo ""
    echo "Recommendation: Change to 'FULL' detail type"
    echo ""
    echo "Fix with AWS CLI:"
    echo "aws codestar-notifications update-notification-rule \\"
    echo "  --arn $RULE_ARN \\"
    echo "  --detail-type FULL"
elif [ "$DETAIL_TYPE" = "FULL" ]; then
    echo "✅ Detail type is FULL (correct)"
    echo ""
    echo "The issue might be that the notification rule was created before the policy was fixed."
    echo "Try updating the notification rule to refresh it:"
    echo ""
    echo "aws codestar-notifications update-notification-rule \\"
    echo "  --arn $RULE_ARN \\"
    echo "  --status ENABLED"
fi
echo ""

echo "=== Checking Target Configuration ==="
echo "$RULE" | jq -r '.Targets[] | "Type: \(.TargetType)\nAddress: \(.TargetAddress)\nStatus: \(.TargetStatus // "N/A")"'
echo ""

echo "=== Testing: Manually Trigger Notification ==="
echo "Unfortunately, there's no direct way to test CodeStar Notifications."
echo "Let's trigger a pipeline and watch for the notification..."
echo ""

PIPELINE_NAME="ecs-fargate-develop-service-1-pipeline"
echo "Triggering pipeline: $PIPELINE_NAME"
aws codepipeline start-pipeline-execution --name "$PIPELINE_NAME"
echo ""
echo "Pipeline triggered. Check your email in 1-2 minutes."
echo "Also check CloudWatch Metrics in AWS Console:"
echo "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#metricsV2:graph=~();query=~'*7bAWS*2fSNS*2cTopicName*7d*20ecs-fargate-develop-pipeline-notifications"
