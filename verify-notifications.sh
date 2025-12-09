#!/bin/bash
# Comprehensive notification verification

TOPIC_ARN="arn:aws:sns:us-east-1:664271361680:ecs-fargate-develop-pipeline-notifications"
PIPELINE_NAME="ecs-fargate-develop-service-1-pipeline"

echo "=== Step 1: Verify SNS Topic Policy ==="
echo "Checking if CodeStar Notifications has permission..."
POLICY=$(aws sns get-topic-attributes --topic-arn "$TOPIC_ARN" --query 'Attributes.Policy' --output text)

if echo "$POLICY" | grep -q "codestar-notifications.amazonaws.com"; then
    echo "✅ CodeStar Notifications permission EXISTS"
else
    echo "❌ CodeStar Notifications permission MISSING"
    echo ""
    echo "The Terraform apply may not have updated the policy yet."
    echo "Check: cd terraform && terraform plan"
fi
echo ""

echo "=== Step 2: Verify Notification Rule ==="
RULE_ARN="arn:aws:codestar-notifications:us-east-1:664271361680:notificationrule/473148d57b8de5d25e1f81ff190b81e338fa54c0"

RULE_DETAILS=$(aws codestar-notifications describe-notification-rule --arn "$RULE_ARN" --output json)
echo "Rule Status: $(echo "$RULE_DETAILS" | jq -r '.Status')"
echo "Target SNS Topic: $(echo "$RULE_DETAILS" | jq -r '.Targets[0].TargetAddress')"
echo "Connected Pipeline: $(echo "$RULE_DETAILS" | jq -r '.Resource')"
echo ""

echo "Event Types Configured:"
echo "$RULE_DETAILS" | jq -r '.EventTypes[]' | while read event; do
    echo "  - $event"
done
echo ""

echo "=== Step 3: Check Recent Pipeline Executions ==="
EXECUTIONS=$(aws codepipeline list-pipeline-executions --pipeline-name "$PIPELINE_NAME" --max-results 5 --output json)
echo "Recent executions:"
echo "$EXECUTIONS" | jq -r '.pipelineExecutionSummaries[] | "\(.startTime): \(.status)"'
echo ""

echo "=== Step 4: Check CloudWatch Logs for Notification Delivery ==="
echo "Checking if CodeStar Notifications is attempting to send..."

# Check CloudWatch Logs for SNS delivery
LOG_GROUP="/aws/sns/us-east-1/664271361680/ecs-fargate-develop-pipeline-notifications/Failure"
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" 2>/dev/null | grep -q "$LOG_GROUP"; then
    echo "⚠️  Found SNS failure logs - checking recent failures..."
    aws logs tail "$LOG_GROUP" --since 2h --format short 2>/dev/null || echo "No recent failures"
else
    echo "No SNS failure log group found (this is good - means no delivery failures)"
fi
echo ""

echo "=== Step 5: Test Direct SNS Publish ==="
echo "Sending test message to verify email delivery works..."
RESULT=$(aws sns publish \
    --topic-arn "$TOPIC_ARN" \
    --subject "Test: Direct SNS Publish" \
    --message "If you receive this, SNS email delivery is working. The issue is with CodeStar Notifications." \
    --output json)

if [ $? -eq 0 ]; then
    echo "✅ Test message sent successfully"
    echo "Message ID: $(echo "$RESULT" | jq -r '.MessageId')"
    echo ""
    echo "Check your email (connorhartland@gmail.com) in the next 1-2 minutes."
    echo "If you receive this test but not pipeline notifications, the issue is with CodeStar Notifications."
else
    echo "❌ Failed to send test message"
fi
echo ""

echo "=== Step 6: Trigger Pipeline and Monitor ==="
echo "Triggering pipeline execution..."
EXEC_RESULT=$(aws codepipeline start-pipeline-execution --pipeline-name "$PIPELINE_NAME" --output json)
EXEC_ID=$(echo "$EXEC_RESULT" | jq -r '.pipelineExecutionId')
echo "Pipeline execution started: $EXEC_ID"
echo ""
echo "Waiting 10 seconds for notification to be sent..."
sleep 10
echo ""

echo "=== Step 7: Check SNS Metrics ==="
echo "Checking if messages were published to SNS in the last 15 minutes..."

# Get current time and 15 minutes ago in ISO format
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%S)
START_TIME=$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-15M +%Y-%m-%dT%H:%M:%S)

PUBLISHED=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/SNS \
    --metric-name NumberOfMessagesPublished \
    --dimensions Name=TopicName,Value=ecs-fargate-develop-pipeline-notifications \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Sum \
    --output json)

TOTAL_PUBLISHED=$(echo "$PUBLISHED" | jq '[.Datapoints[].Sum] | add // 0')
echo "Messages published to SNS: $TOTAL_PUBLISHED"

DELIVERED=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/SNS \
    --metric-name NumberOfNotificationsDelivered \
    --dimensions Name=TopicName,Value=ecs-fargate-develop-pipeline-notifications \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --period 300 \
    --statistics Sum \
    --output json)

TOTAL_DELIVERED=$(echo "$DELIVERED" | jq '[.Datapoints[].Sum] | add // 0')
echo "Messages delivered by SNS: $TOTAL_DELIVERED"
echo ""

echo "=== Diagnosis ==="
if [ "$TOTAL_PUBLISHED" -eq 0 ]; then
    echo "❌ ISSUE: CodeStar Notifications is NOT publishing to SNS"
    echo ""
    echo "Possible causes:"
    echo "1. Notification rule is disabled"
    echo "2. Event types don't match pipeline events"
    echo "3. Notification rule target is wrong"
    echo "4. CodeStar Notifications doesn't have permission (check Step 1)"
    echo ""
    echo "Next steps:"
    echo "- Verify notification rule status is ENABLED"
    echo "- Check if the rule's Resource ARN matches your pipeline"
    echo "- Ensure the SNS topic policy allows codestar-notifications.amazonaws.com"
elif [ "$TOTAL_DELIVERED" -eq 0 ]; then
    echo "⚠️  ISSUE: SNS is receiving messages but not delivering them"
    echo ""
    echo "Possible causes:"
    echo "1. Email subscription is not confirmed (check your email for confirmation)"
    echo "2. Email is being filtered/blocked"
    echo ""
    echo "Check your spam folder and search for emails from: no-reply@sns.amazonaws.com"
else
    echo "✅ Everything looks good!"
    echo "Messages are being published and delivered."
    echo "Check your email (including spam folder) for notifications."
fi
