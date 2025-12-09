# PowerShell script to check SNS notification setup for CI/CD pipelines

Write-Host "=== Checking SNS Notification Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check if AWS CLI is available
try {
    $accountId = aws sts get-caller-identity --query Account --output text 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: AWS CLI not configured or no credentials found" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "ERROR: AWS CLI not found or not configured" -ForegroundColor Red
    exit 1
}

$region = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-1" }

Write-Host "Account ID: $accountId"
Write-Host "Region: $region"
Write-Host ""

# List all SNS topics related to pipeline notifications
Write-Host "=== SNS Topics (Pipeline Notifications) ===" -ForegroundColor Cyan
$topics = aws sns list-topics --output json | ConvertFrom-Json
$pipelineTopics = $topics.Topics | Where-Object { $_.TopicArn -match "(pipeline-notifications|approval-notifications)" }

if ($pipelineTopics.Count -eq 0) {
    Write-Host "⚠️  No pipeline notification topics found" -ForegroundColor Yellow
    Write-Host "This means notifications are not enabled or not deployed yet."
} else {
    Write-Host "✅ Found $($pipelineTopics.Count) notification topic(s):" -ForegroundColor Green
    $pipelineTopics | ForEach-Object { Write-Host "  - $($_.TopicArn)" }
}
Write-Host ""

# For each topic, check subscriptions
Write-Host "=== Checking Subscriptions ===" -ForegroundColor Cyan
foreach ($topic in $pipelineTopics) {
    Write-Host "Topic: $($topic.TopicArn)" -ForegroundColor White
    
    $subs = aws sns list-subscriptions-by-topic --topic-arn $topic.TopicArn --output json | ConvertFrom-Json
    
    if ($subs.Subscriptions.Count -eq 0) {
        Write-Host "  ⚠️  NO SUBSCRIPTIONS - This is why you're not getting emails!" -ForegroundColor Yellow
        Write-Host "  To subscribe:" -ForegroundColor Yellow
        Write-Host "  aws sns subscribe --topic-arn $($topic.TopicArn) --protocol email --notification-endpoint your-email@example.com" -ForegroundColor White
    } else {
        Write-Host "  ✅ $($subs.Subscriptions.Count) subscription(s) found:" -ForegroundColor Green
        foreach ($sub in $subs.Subscriptions) {
            $status = if ($sub.SubscriptionArn -eq "PendingConfirmation") { "⏳ Pending Confirmation" } else { "✅ Confirmed" }
            Write-Host "    - $($sub.Protocol): $($sub.Endpoint) (Status: $status)"
        }
    }
    Write-Host ""
}

# Check CodeStar Notification Rules
Write-Host "=== CodeStar Notification Rules ===" -ForegroundColor Cyan
try {
    $rules = aws codestar-notifications list-notification-rules --output json 2>$null | ConvertFrom-Json
    
    if ($rules.NotificationRules.Count -eq 0) {
        Write-Host "⚠️  No notification rules found" -ForegroundColor Yellow
        Write-Host "Check Terraform variable 'enable_notifications' is set to true"
    } else {
        Write-Host "✅ Found $($rules.NotificationRules.Count) notification rule(s):" -ForegroundColor Green
        foreach ($rule in $rules.NotificationRules) {
            Write-Host "  - $($rule.Name) (Status: $($rule.Status))"
            
            # Get details
            $details = aws codestar-notifications describe-notification-rule --arn $rule.Arn --output json | ConvertFrom-Json
            Write-Host "    Events: $($details.EventTypes.Count) configured"
            Write-Host "    Targets: $($details.Targets.Count) configured"
            Write-Host "    Status: $($details.Status)"
        }
    }
} catch {
    Write-Host "⚠️  Unable to list notification rules (may need permissions)" -ForegroundColor Yellow
}
Write-Host ""

# Check recent CodePipeline executions
Write-Host "=== Recent Pipeline Executions ===" -ForegroundColor Cyan
$pipelines = aws codepipeline list-pipelines --output json | ConvertFrom-Json
$relevantPipelines = $pipelines.pipelines | Where-Object { $_.name -match "(develop|test|qa|prod)" }

if ($relevantPipelines.Count -eq 0) {
    Write-Host "No pipelines found"
} else {
    foreach ($pipeline in $relevantPipelines) {
        Write-Host "Pipeline: $($pipeline.name)" -ForegroundColor White
        try {
            $executions = aws codepipeline list-pipeline-executions --pipeline-name $pipeline.name --max-results 3 --output json 2>$null | ConvertFrom-Json
            if ($executions.pipelineExecutionSummaries.Count -eq 0) {
                Write-Host "  No executions found"
            } else {
                foreach ($exec in $executions.pipelineExecutionSummaries) {
                    $statusColor = switch ($exec.status) {
                        "Succeeded" { "Green" }
                        "Failed" { "Red" }
                        default { "Yellow" }
                    }
                    Write-Host "  - $($exec.startTime): $($exec.status)" -ForegroundColor $statusColor
                }
            }
        } catch {
            Write-Host "  Unable to get executions"
        }
        Write-Host ""
    }
}

# Check CloudWatch Logs for CodeBuild
Write-Host "=== CodeBuild Log Groups ===" -ForegroundColor Cyan
$logGroups = aws logs describe-log-groups --log-group-name-prefix "/aws/codebuild" --output json | ConvertFrom-Json
if ($logGroups.logGroups.Count -eq 0) {
    Write-Host "No CodeBuild log groups found"
} else {
    Write-Host "Found $($logGroups.logGroups.Count) CodeBuild log group(s):"
    $logGroups.logGroups | Select-Object -First 5 | ForEach-Object { Write-Host "  - $($_.logGroupName)" }
}
Write-Host ""

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "✓ Check if SNS topics exist"
Write-Host "✓ Check if topics have subscriptions (most common issue)"
Write-Host "✓ Check if notification rules are configured"
Write-Host "✓ Check if pipelines have run recently"
Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Yellow
Write-Host "1. If no SNS topics: Set enable_notifications=true in Terraform and apply"
Write-Host "2. If no subscriptions: Subscribe your email to the SNS topic (command shown above)"
Write-Host "3. If subscription pending: Check your email and confirm the subscription"
Write-Host "4. If no notification rules: Verify enable_notifications=true in your service config"
Write-Host "5. If no pipelines have run: Trigger a pipeline to test notifications"
