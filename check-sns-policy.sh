#!/bin/bash
# Check SNS topic policy to verify CodeStar Notifications has permission

TOPIC_ARN="arn:aws:sns:us-east-1:664271361680:ecs-fargate-develop-pipeline-notifications"

echo "=== Checking SNS Topic Policy ==="
echo "Topic: $TOPIC_ARN"
echo ""

# Get the topic policy
echo "Current Policy:"
POLICY=$(aws sns get-topic-attributes --topic-arn "$TOPIC_ARN" --output json)

echo "$POLICY" | jq -r '.Attributes.Policy' | jq '.'

echo ""
echo "=== Checking for CodeStar Notifications Permission ==="

# Check if codestar-notifications.amazonaws.com is in the policy
if echo "$POLICY" | jq -r '.Attributes.Policy' | grep -q "codestar-notifications.amazonaws.com"; then
    echo "✅ CodeStar Notifications service IS allowed to publish"
else
    echo "❌ FOUND THE ISSUE!"
    echo ""
    echo "CodeStar Notifications service is NOT in the SNS topic policy."
    echo "This is why notifications aren't being sent."
    echo ""
    echo "The policy needs to allow 'codestar-notifications.amazonaws.com' to publish."
fi

echo ""
echo "=== Checking Topic Subscription ==="
aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --output json | \
    jq -r '.Subscriptions[] | "Protocol: \(.Protocol), Endpoint: \(.Endpoint), Status: \(.SubscriptionArn)"'

echo ""
echo "=== Testing SNS Publish Permission ==="
echo "Attempting to publish a test message..."

RESULT=$(aws sns publish \
    --topic-arn "$TOPIC_ARN" \
    --subject "Test from CLI" \
    --message "Testing SNS delivery" 2>&1)

if [ $? -eq 0 ]; then
    echo "✅ Successfully published test message"
    echo "Message ID: $(echo "$RESULT" | jq -r '.MessageId')"
    echo ""
    echo "Check your email (connorhartland@gmail.com) - you should receive this test."
else
    echo "❌ Failed to publish: $RESULT"
fi

echo ""
echo "=== Recommended Fix ==="
echo "If CodeStar Notifications permission is missing, you need to:"
echo "1. Check if the SNS topic was created by Terraform with enable_notifications=true"
echo "2. If not, the policy wasn't applied correctly"
echo "3. Run: cd terraform && terraform apply"
echo ""
echo "Or manually add the policy:"
echo "aws sns set-topic-attributes --topic-arn $TOPIC_ARN --attribute-name Policy --attribute-value '{...}'"
