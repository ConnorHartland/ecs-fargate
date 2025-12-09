# Requirements Document

## Introduction

This document specifies the requirements for fixing SNS notifications in the ECS Fargate CI/CD infrastructure. The system currently has SNS topics and CodeStar notification rules configured, but notifications are not being delivered to email subscribers when pipeline events occur (pipeline started, succeeded, failed, etc.). The fix must ensure that all pipeline state changes trigger email notifications to subscribed users.

## Glossary

- **SNS Topic**: Amazon Simple Notification Service topic that receives and distributes notifications
- **CodeStar Notifications**: AWS service that sends notifications from CodePipeline to SNS topics
- **Notification Rule**: Configuration that defines which pipeline events trigger notifications
- **SNS Subscription**: Email endpoint registered to receive messages from an SNS topic
- **SNS Topic Policy**: IAM policy that controls which services can publish to the SNS topic
- **CodePipeline**: AWS CI/CD service that builds and deploys applications
- **Pipeline Event**: State change in CodePipeline (started, succeeded, failed, stopped, etc.)

## Requirements

### Requirement 1

**User Story:** As a DevOps engineer, I want to receive email notifications when pipelines start, so that I am aware of deployment activity.

#### Acceptance Criteria

1. WHEN a CodePipeline execution starts, THE SNS Topic SHALL receive a notification message from CodeStar Notifications
2. WHEN the SNS Topic receives a pipeline start notification, THE SNS Topic SHALL deliver the message to all confirmed email subscriptions
3. THE email notification SHALL include the pipeline name, execution ID, and timestamp
4. THE email notification SHALL be delivered within 2 minutes of the pipeline starting

### Requirement 2

**User Story:** As a DevOps engineer, I want to receive email notifications when pipelines succeed, so that I know deployments completed successfully.

#### Acceptance Criteria

1. WHEN a CodePipeline execution succeeds, THE SNS Topic SHALL receive a notification message from CodeStar Notifications
2. WHEN the SNS Topic receives a pipeline success notification, THE SNS Topic SHALL deliver the message to all confirmed email subscriptions
3. THE email notification SHALL include the pipeline name, execution ID, final status, and timestamp
4. THE email notification SHALL be delivered within 2 minutes of the pipeline completing

### Requirement 3

**User Story:** As a DevOps engineer, I want to receive email notifications when pipelines fail, so that I can quickly respond to deployment issues.

#### Acceptance Criteria

1. WHEN a CodePipeline execution fails, THE SNS Topic SHALL receive a notification message from CodeStar Notifications
2. WHEN the SNS Topic receives a pipeline failure notification, THE SNS Topic SHALL deliver the message to all confirmed email subscriptions
3. THE email notification SHALL include the pipeline name, execution ID, failure reason, and timestamp
4. THE email notification SHALL be delivered within 2 minutes of the pipeline failing
5. THE email notification SHALL clearly indicate the failure status in the subject line

### Requirement 4

**User Story:** As a DevOps engineer, I want the SNS topic policy to allow CodeStar Notifications to publish messages, so that notifications can be delivered.

#### Acceptance Criteria

1. THE SNS Topic Policy SHALL include a statement allowing the codestar-notifications.amazonaws.com service principal to publish messages
2. THE SNS Topic Policy SHALL include a statement allowing the codestar-notifications.amazonaws.com service principal to subscribe to the topic
3. THE SNS Topic Policy SHALL restrict CodeStar Notifications access to the specific AWS account using a condition
4. WHEN CodeStar Notifications attempts to publish to the SNS Topic, THE SNS Topic SHALL accept the message without permission errors

### Requirement 5

**User Story:** As a DevOps engineer, I want notification rules to be properly configured with the correct event types, so that all relevant pipeline events trigger notifications.

#### Acceptance Criteria

1. THE Notification Rule SHALL be configured with event types for pipeline execution started
2. THE Notification Rule SHALL be configured with event types for pipeline execution succeeded
3. THE Notification Rule SHALL be configured with event types for pipeline execution failed
4. THE Notification Rule SHALL be configured with event types for pipeline execution stopped
5. THE Notification Rule SHALL have status set to ENABLED
6. THE Notification Rule SHALL target the correct SNS Topic ARN

### Requirement 6

**User Story:** As a DevOps engineer, I want to easily subscribe email addresses to pipeline notifications, so that team members can receive alerts.

#### Acceptance Criteria

1. THE system SHALL provide a mechanism to subscribe email addresses to the SNS Topic
2. WHEN an email address is subscribed, THE SNS Topic SHALL send a confirmation email to that address
3. WHEN a user clicks the confirmation link, THE subscription SHALL become active
4. THE subscription SHALL remain active until explicitly unsubscribed
5. THE system SHALL support multiple email subscriptions to the same SNS Topic

### Requirement 7

**User Story:** As a DevOps engineer, I want to verify that notifications are working correctly, so that I can troubleshoot issues.

#### Acceptance Criteria

1. THE system SHALL provide a test mechanism to send a test notification to the SNS Topic
2. WHEN a test notification is sent, THE SNS Topic SHALL deliver it to all confirmed subscriptions
3. THE system SHALL provide diagnostic information about notification rule status
4. THE system SHALL provide diagnostic information about SNS subscription status
5. THE system SHALL provide CloudWatch metrics showing message publish and delivery counts

### Requirement 8

**User Story:** As a DevOps engineer, I want production pipeline approval notifications to work, so that approvers are notified when manual approval is needed.

#### Acceptance Criteria

1. WHERE the pipeline type is production, WHEN manual approval is needed, THE SNS Topic SHALL receive a notification
2. WHERE the pipeline type is production, THE approval notification SHALL include a link to the approval action
3. WHERE the pipeline type is production, THE approval notification SHALL include the pipeline name and deployment details
4. WHERE the pipeline type is production, WHEN approval is granted, THE SNS Topic SHALL send a confirmation notification
5. WHERE the pipeline type is production, WHEN approval is denied, THE SNS Topic SHALL send a denial notification

### Requirement 9

**User Story:** As a security engineer, I want SNS topics to use KMS encryption, so that notification content is protected at rest.

#### Acceptance Criteria

1. THE SNS Topic SHALL be configured with a KMS master key for encryption
2. THE SNS Topic Policy SHALL allow the KMS key to be used for encryption and decryption
3. THE CodeStar Notifications service SHALL have permission to use the KMS key for publishing encrypted messages
4. WHEN a notification is published, THE message SHALL be encrypted using the configured KMS key

### Requirement 10

**User Story:** As a DevOps engineer, I want notification configuration to be consistent across all environments, so that all pipelines send notifications.

#### Acceptance Criteria

1. THE Terraform module SHALL create SNS topics for each environment (develop, test, qa, prod)
2. THE Terraform module SHALL create notification rules for each pipeline in each environment
3. THE Terraform module SHALL apply consistent event type configurations across all environments
4. THE Terraform module SHALL apply consistent SNS topic policies across all environments
5. WHERE enable_notifications is true, THE module SHALL create all notification resources
6. WHERE enable_notifications is false, THE module SHALL not create notification resources
