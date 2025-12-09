#!/bin/bash
# Check detailed notification rule configuration

echo "=== Detailed Notification Rule Analysis ==="
echo ""

# Get the notification rule details
RULE_ARN="arn:aws:codestar-notifications:us-east-1:664271361680:notificationrule/473148d57b8de5d25e1f81ff190b81e338fa54c0"

echo "Fetching notification rule details..."
RULE_DETAILS=$(aws codestar-notifications describe-notification-rule --arn "$RULE_ARN" --output json)

echo "Rule Name: $(echo "$RULE_DETAILS" | jq -r '.Name')"
echo "Status: $(echo "$RULE_DETAILS" | jq -r '.Status')"
echo ""

echo "=== Resource (Pipeline) ==="
RESOURCE=$(echo "$RULE_DETAILS" | jq -r '.Resource')
echo "Connected to: $RESOURCE"
echo ""

# Extract pipeline name from ARN
PIPELINE_NAME=$(echo "$RESOURCE" | awk -F: '{print $NF}')
echo "Pipeline Name: $PIPELINE_NAME"
echo ""

echo "=== Target (SNS Topic) ==="
echo "$RULE_DETAILS" | jq -r '.Targets[] | "Type: \(.TargetType)\nAddress: \(.TargetAddress)"'
echo ""

echo "=== Event Types Configured ==="
echo "$RULE_DETAILS" | jq -r '.EventTypes[]'
echo ""

echo "=== All Pipelines in Account ==="
aws codepipeline list-pipelines --output json | jq -r '.pipelines[] | "- \(.name)"'
echo ""

echo "=== Checking if service-1 pipeline has its own notification rule ==="
SERVICE1_PIPELINE="ecs-fargate-develop-service-1-pipeline"
echo "Looking for notification rules for: $SERVICE1_PIPELINE"
echo ""

# List all notification rules and check which pipeline they're for
ALL_RULES=$(aws codestar-notifications list-notification-rules --output json)
echo "$ALL_RULES" | jq -r '.NotificationRules[] | "\(.Arn)"' | while read -r rule_arn; do
    rule_info=$(aws codestar-notifications describe-notification-rule --arn "$rule_arn" --output json 2>/dev/null)
    resource=$(echo "$rule_info" | jq -r '.Resource')
    name=$(echo "$rule_info" | jq -r '.Name')
    status=$(echo "$rule_info" | jq -r '.Status')
    
    echo "Rule: $name"
    echo "  Status: $status"
    echo "  Resource: $resource"
    
    if echo "$resource" | grep -q "$SERVICE1_PIPELINE"; then
        echo "  ✅ THIS RULE IS FOR SERVICE-1!"
    else
        echo "  ⚠️  This rule is for a different pipeline"
    fi
    echo ""
done

echo "=== Diagnosis ==="
if echo "$RESOURCE" | grep -q "$SERVICE1_PIPELINE"; then
    echo "✅ The notification rule IS connected to service-1 pipeline"
    echo ""
    echo "If you're not getting emails, possible causes:"
    echo "1. Emails are going to spam"
    echo "2. SNS delivery is failing (check CloudWatch Logs)"
    echo "3. The events aren't matching (check event types)"
else
    echo "❌ FOUND THE ISSUE!"
    echo ""
    echo "The notification rule is connected to: $PIPELINE_NAME"
    echo "But you're running: $SERVICE1_PIPELINE"
    echo ""
    echo "This means service-1 doesn't have its own notification rule."
    echo "The SNS topic exists but isn't connected to service-1's pipeline."
fi
