#!/bin/bash
# Fix KMS key permissions for CodeStar Notifications

TOPIC_ARN="arn:aws:sns:us-east-1:664271361680:ecs-fargate-develop-pipeline-notifications"
ACCOUNT_ID="664271361680"

echo "=== Checking SNS Topic KMS Key ==="
KMS_KEY=$(aws sns get-topic-attributes --topic-arn "$TOPIC_ARN" --query 'Attributes.KmsMasterKeyId' --output text)

if [ "$KMS_KEY" = "None" ] || [ -z "$KMS_KEY" ]; then
    echo "Topic is not encrypted with KMS"
else
    echo "Topic is encrypted with KMS key: $KMS_KEY"
    echo ""
    echo "This is the issue! CodeStar Notifications needs permission to use this KMS key."
    echo ""
    
    # Get the full KMS key ARN
    if [[ $KMS_KEY == arn:* ]]; then
        KMS_KEY_ARN="$KMS_KEY"
    else
        KMS_KEY_ARN="arn:aws:kms:us-east-1:$ACCOUNT_ID:key/$KMS_KEY"
    fi
    
    echo "KMS Key ARN: $KMS_KEY_ARN"
    echo ""
    
    echo "Getting current KMS key policy..."
    CURRENT_POLICY=$(aws kms get-key-policy --key-id "$KMS_KEY" --policy-name default --output text)
    
    echo ""
    echo "Current policy has these principals:"
    echo "$CURRENT_POLICY" | jq -r '.Statement[].Principal' 2>/dev/null || echo "Unable to parse policy"
    echo ""
    
    echo "Checking if codestar-notifications.amazonaws.com has access..."
    if echo "$CURRENT_POLICY" | grep -q "codestar-notifications.amazonaws.com"; then
        echo "✅ CodeStar Notifications already has KMS permission"
    else
        echo "❌ CodeStar Notifications does NOT have KMS permission"
        echo ""
        echo "This needs to be fixed in Terraform (terraform/modules/security/main.tf)"
        echo "Add this statement to the KMS key policy:"
        echo ""
        cat << 'EOF'
{
  "Sid": "AllowCodeStarNotifications",
  "Effect": "Allow",
  "Principal": {
    "Service": "codestar-notifications.amazonaws.com"
  },
  "Action": [
    "kms:Decrypt",
    "kms:GenerateDataKey"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "kms:ViaService": "sns.us-east-1.amazonaws.com",
      "aws:SourceAccount": "664271361680"
    }
  }
}
EOF
        echo ""
        echo "Or temporarily disable KMS encryption on the SNS topic:"
        echo "aws sns set-topic-attributes --topic-arn $TOPIC_ARN --attribute-name KmsMasterKeyId --attribute-value ''"
    fi
fi
