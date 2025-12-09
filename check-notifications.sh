#!/bin/bash
# Script to check SNS notification setup for CI/CD pipelines

echo "=== Checking SNS Notification Setup ==="
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS CLI not configured or no credentials found"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "Account ID: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Current Directory: $(pwd)"
echo ""

# List all SNS topics related to pipeline notifications
echo "=== SNS Topics (Pipeline Notifications) ==="
TOPICS=$(aws sns list-topics --output json 2>&1)
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to list SNS topics"
    echo "$TOPICS"
    exit 1
fi

PIPELINE_TOPICS=$(echo "$TOPICS" | jq -r '.Topics[].TopicArn' | grep -E "(pipeline-notifications|approval-notifications)" || true)

if [ -z "$PIPELINE_TOPICS" ]; then
    echo "⚠️  No pipeline notification topics found"
    echo ""
    echo "This could mean:"
    echo "  1. Notifications are not enabled in Terraform (enable_notifications = false)"
    echo "  2. Terraform hasn't been applied yet"
    echo "  3. You're checking the wrong AWS account/region"
    echo ""
    echo "To enable notifications, add to your service configuration:"
    echo "  enable_notifications = true"
else
    echo "✅ Found pipeline notification topics:"
    echo "$PIPELINE_TOPICS" | while read -r topic; do
        echo "  - $topic"
    done
fi
echo ""

# For each topic, check subscriptions
echo "=== Checking Subscriptions ==="
if [ -z "$PIPELINE_TOPICS" ]; then
    echo "Skipping - no topics found"
else
    echo "$PIPELINE_TOPICS" | while read -r topic_arn; do
        echo "Topic: $topic_arn"
        
        # Get subscriptions
        subs=$(aws sns list-subscriptions-by-topic --topic-arn "$topic_arn" --output json 2>&1)
        if [ $? -ne 0 ]; then
            echo "  ⚠️  ERROR: Unable to list subscriptions"
            echo "  $subs"
        else
            sub_count=$(echo "$subs" | jq '.Subscriptions | length')
            
            if [ "$sub_count" -eq 0 ]; then
                echo "  ⚠️  NO SUBSCRIPTIONS - This is why you're not getting emails!"
                echo ""
                echo "  To subscribe your email:"
                echo "  aws sns subscribe --topic-arn $topic_arn --protocol email --notification-endpoint your-email@example.com"
                echo ""
            else
                echo "  ✅ $sub_count subscription(s) found:"
                echo "$subs" | jq -r '.Subscriptions[] | "    - \(.Protocol): \(.Endpoint) (Status: \(if .SubscriptionArn == "PendingConfirmation" then "⏳ Pending Confirmation - CHECK YOUR EMAIL!" else "✅ Confirmed" end))"'
            fi
        fi
        echo ""
    done
fi
echo ""

# Check CodeStar Notification Rules
echo "=== CodeStar Notification Rules ==="
rules=$(aws codestar-notifications list-notification-rules --output json 2>&1)
if [ $? -eq 0 ]; then
    rule_count=$(echo "$rules" | jq '.NotificationRules | length')
    if [ "$rule_count" -eq 0 ]; then
        echo "⚠️  No notification rules found"
        echo ""
        echo "This means notifications are NOT configured. To fix:"
        echo "  1. In your service Terraform config, set: enable_notifications = true"
        echo "  2. Run: terraform apply"
        echo ""
    else
        echo "✅ Found $rule_count notification rule(s):"
        echo "$rules" | jq -r '.NotificationRules[] | "  - \(.Name) (Status: \(.Status))"'
        echo ""
        
        # Get details for each rule
        for rule_arn in $(echo "$rules" | jq -r '.NotificationRules[].Arn'); do
            echo "  Rule Details:"
            rule_details=$(aws codestar-notifications describe-notification-rule --arn "$rule_arn" --output json 2>&1)
            if [ $? -eq 0 ]; then
                echo "    Name: $(echo "$rule_details" | jq -r '.Name')"
                echo "    Status: $(echo "$rule_details" | jq -r '.Status')"
                echo "    Events: $(echo "$rule_details" | jq -r '.EventTypes | length') configured"
                echo "    Targets: $(echo "$rule_details" | jq -r '.Targets | length') configured"
                echo "    Event Types:"
                echo "$rule_details" | jq -r '.EventTypes[] | "      - \(.)"'
            fi
            echo ""
        done
    fi
else
    echo "⚠️  Unable to list notification rules"
    echo "$rules"
fi

# Check recent CodePipeline executions
echo "=== Recent Pipeline Executions ==="
pipelines=$(aws codepipeline list-pipelines --output json | jq -r '.pipelines[].name' | grep -E "(develop|test|qa|prod)")
if [ -z "$pipelines" ]; then
    echo "No pipelines found"
else
    for pipeline in $pipelines; do
        echo "Pipeline: $pipeline"
        executions=$(aws codepipeline list-pipeline-executions --pipeline-name "$pipeline" --max-results 3 --output json 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "$executions" | jq -r '.pipelineExecutionSummaries[] | "  - \(.startTime): \(.status)"'
        else
            echo "  Unable to get executions"
        fi
        echo ""
    done
fi

# Check CloudWatch Logs for CodeBuild
echo "=== Recent CodeBuild Logs ==="
log_groups=$(aws logs describe-log-groups --log-group-name-prefix "/aws/codebuild" --output json | jq -r '.logGroups[].logGroupName' | head -5)
if [ -z "$log_groups" ]; then
    echo "No CodeBuild log groups found"
else
    echo "Found CodeBuild log groups:"
    echo "$log_groups"
fi
echo ""

echo "=== Diagnosis Summary ==="
echo ""

# Determine the issue
if [ -z "$PIPELINE_TOPICS" ]; then
    echo "❌ ISSUE: No SNS topics found"
    echo ""
    echo "ROOT CAUSE: Notifications are not enabled or not deployed"
    echo ""
    echo "FIX:"
    echo "  1. Check your service configuration (terraform/services/YOUR-SERVICE/main.tf)"
    echo "  2. Ensure: enable_notifications = true"
    echo "  3. Run: terraform apply"
    echo ""
elif [ "$rule_count" -eq 0 ]; then
    echo "❌ ISSUE: SNS topics exist but no notification rules"
    echo ""
    echo "ROOT CAUSE: Notification rules weren't created"
    echo ""
    echo "FIX:"
    echo "  1. Check enable_notifications = true in your service config"
    echo "  2. Run: terraform apply"
    echo ""
else
    # Check if any topic has no subscriptions
    has_subs=false
    echo "$PIPELINE_TOPICS" | while read -r topic_arn; do
        subs=$(aws sns list-subscriptions-by-topic --topic-arn "$topic_arn" --output json 2>/dev/null)
        sub_count=$(echo "$subs" | jq '.Subscriptions | length' 2>/dev/null || echo "0")
        if [ "$sub_count" -gt 0 ]; then
            has_subs=true
        fi
    done
    
    echo "⚠️  ISSUE: Everything is configured but you need to subscribe"
    echo ""
    echo "ROOT CAUSE: No email subscriptions to the SNS topics"
    echo ""
    echo "FIX: Subscribe your email (see commands above in 'Checking Subscriptions' section)"
    echo ""
fi

echo "=== Quick Test ==="
echo "After subscribing, trigger a pipeline to test:"
echo "  aws codepipeline start-pipeline-execution --name YOUR-PIPELINE-NAME"
echo ""
