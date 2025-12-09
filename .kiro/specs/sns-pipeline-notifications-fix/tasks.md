# Implementation Plan

- [x] 1. Update SNS topic policy in CICD module





  - Modify `terraform/modules/cicd/main.tf` to update the SNS topic policy resource
  - Add statement allowing codestar-notifications.amazonaws.com to Publish and Subscribe
  - Include condition restricting to AWS account ID
  - Ensure policy is applied to both pipeline_notifications and approval_notifications topics
  - _Requirements: 4.1, 4.2, 4.3_

- [ ]* 1.1 Write property test for SNS topic policy
  - **Property 1: SNS topic policy allows CodeStar Notifications**
  - **Property 2: SNS topic policy restricts by account**
  - **Validates: Requirements 4.1, 4.2, 4.3**

- [x] 2. Verify and update notification rule event types





  - Check the `notification_events` variable in `terraform/modules/cicd/variables.tf`
  - Ensure it includes all required event types (started, succeeded, failed, stopped, resumed, canceled, superseded)
  - Verify production pipelines include approval event types
  - Update default values if needed
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 8.1, 8.4, 8.5_

- [ ]* 2.1 Write property test for notification rule configuration
  - **Property 3: Notification rule includes all pipeline event types**
  - **Property 4: Notification rule is enabled**
  - **Property 5: Notification rule targets correct SNS topic**
  - **Property 6: Production pipelines include approval events**
  - **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 8.1, 8.4, 8.5**


- [x] 3. Update KMS key policy to allow CodeStar Notifications




  - Modify `terraform/modules/security/main.tf` to add CodeStar Notifications to KMS key policy
  - Add statement allowing codestar-notifications.amazonaws.com to Decrypt and GenerateDataKey
  - Include condition for kms:ViaService restricting to SNS
  - Include condition for aws:SourceAccount
  - _Requirements: 9.2, 9.3_

- [ ]* 3.1 Write property test for KMS key policy
  - **Property 7: SNS topics use KMS encryption**
  - **Property 8: KMS key policy allows CodeStar Notifications**
  - **Validates: Requirements 9.1, 9.2, 9.3**


- [x] 4. Verify service module notification configuration




  - Check `terraform/modules/service/main.tf` to ensure it passes enable_notifications to CICD module
  - Verify SNS topic ARN is properly passed between modules
  - Ensure KMS key ARN is passed to CICD module for SNS encryption
  - _Requirements: 10.1, 10.2_

- [ ]* 4.1 Write property test for cross-environment consistency
  - **Property 9: Notification resources created per environment**
  - **Property 10: Event types consistent across environments**
  - **Property 11: SNS topic policies consistent across environments**
  - **Property 12: Conditional resource creation**
  - **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5, 10.6**

- [x] 5. Update example service configurations




  - Update `terraform/services/service-1/main.tf` to set enable_notifications = true
  - Add comments explaining notification configuration
  - Document how to customize notification_events if needed
  - _Requirements: 10.5_

- [ ] 6. Create email subscription helper script
  - Create `subscribe-email.sh` script in project root
  - Script should prompt for email address and environment
  - Script should list available SNS topics
  - Script should execute aws sns subscribe command
  - Script should provide instructions for confirming subscription
  - _Requirements: 6.1_

- [ ] 7. Update check-notifications.sh diagnostic script
  - Enhance existing script to check SNS topic policies
  - Add check for CodeStar Notifications permission in policy
  - Add check for KMS key permissions
  - Improve diagnosis output with specific fix recommendations
  - Add check for notification rule target status
  - _Requirements: 7.3, 7.4_

- [ ] 8. Update verify-notifications.sh test script
  - Enhance script to verify SNS topic policy before testing
  - Add check for KMS key policy
  - Add CloudWatch metrics check for published vs delivered messages
  - Improve diagnosis to distinguish between policy issues and subscription issues
  - _Requirements: 7.1, 7.2, 7.5_

- [ ] 9. Create documentation for notification setup
  - Create `NOTIFICATIONS.md` in project root
  - Document how to enable notifications for a service
  - Document how to subscribe email addresses
  - Document how to troubleshoot notification issues
  - Include examples of notification emails
  - Document CloudWatch metrics to monitor
  - _Requirements: 6.1, 7.3, 7.4_

- [ ] 10. Checkpoint - Validate Terraform configuration
  - Run `terraform fmt -recursive` to format all files
  - Run `terraform validate` in modules/cicd
  - Run `terraform validate` in modules/security
  - Run `terraform plan` in a test service to verify changes
  - Ensure no errors in plan output
  - _Requirements: All_

- [ ] 11. Deploy to develop environment
  - Navigate to `terraform/services/service-1`
  - Run `terraform plan` to review changes
  - Run `terraform apply` to deploy SNS policy updates
  - Verify SNS topic policy updated in AWS console
  - Verify notification rule exists and is enabled
  - _Requirements: 4.1, 4.2, 4.3, 5.5, 5.6_

- [ ] 12. Subscribe test email to develop notifications
  - Use subscribe-email.sh script or AWS CLI
  - Subscribe a test email address to develop pipeline notifications topic
  - Check email for confirmation message
  - Click confirmation link
  - Verify subscription status is "Confirmed" in AWS console
  - _Requirements: 6.1, 6.2, 6.3_

- [ ] 13. Test notification delivery in develop
  - Trigger a pipeline execution in develop environment
  - Monitor CloudWatch metrics for NumberOfMessagesPublished
  - Monitor CloudWatch metrics for NumberOfNotificationsDelivered
  - Check email inbox for notification within 2 minutes
  - Verify email contains pipeline name, execution ID, and status
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3_

- [ ] 14. Test failure notifications in develop
  - Trigger a pipeline that will fail (or stop a running pipeline)
  - Verify failure notification received
  - Verify email subject line indicates failure
  - Verify email body contains failure details
  - _Requirements: 3.1, 3.2, 3.3, 3.5_

- [ ]* 14.1 Write integration test for notification delivery
  - **Property 13: CodeStar Notifications can publish without errors**
  - **Property 14: Notification messages contain required fields**
  - **Property 15: Failure notifications indicate failure in subject**
  - **Validates: Requirements 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.5, 4.4**

- [ ] 15. Deploy to test environment
  - Navigate to test environment service configuration
  - Ensure enable_notifications = true
  - Run `terraform apply`
  - Verify SNS topic and notification rule created
  - Subscribe test email
  - Trigger test pipeline and verify notification
  - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ] 16. Deploy to qa environment
  - Navigate to qa environment service configuration
  - Ensure enable_notifications = true
  - Run `terraform apply`
  - Verify SNS topic and notification rule created
  - Subscribe test email
  - Trigger test pipeline and verify notification
  - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ] 17. Deploy to production environment
  - Navigate to production environment service configuration
  - Ensure enable_notifications = true
  - Run `terraform apply`
  - Verify SNS topic and notification rule created
  - Verify approval notification topic created
  - Subscribe production team emails
  - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ] 18. Test production approval notifications
  - Trigger a production pipeline execution (manual trigger)
  - Verify pipeline reaches approval stage
  - Verify approval notification email received
  - Verify email contains approval link
  - Approve the deployment
  - Verify approval confirmation notification received
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 19. Update deployment documentation
  - Update `DEPLOYMENT.md` with notification setup steps
  - Add section on subscribing to notifications
  - Add section on troubleshooting notifications
  - Include links to diagnostic scripts
  - _Requirements: 6.1, 7.3, 7.4_

- [ ] 20. Checkpoint - Final verification
  - Run check-notifications.sh in all environments
  - Verify all SNS topics have correct policies
  - Verify all notification rules are enabled
  - Verify all subscriptions are confirmed
  - Test notifications in each environment
  - _Requirements: All_

- [ ] 21. Subscribe team members to notifications
  - Collect email addresses from team members
  - Subscribe emails to appropriate environment topics
  - Provide confirmation instructions
  - Verify all subscriptions confirmed
  - Send test notifications to verify delivery
  - _Requirements: 6.1, 6.5_

- [ ] 22. Create monitoring dashboard
  - Create CloudWatch dashboard for notification metrics
  - Add widget for NumberOfMessagesPublished per topic
  - Add widget for NumberOfNotificationsDelivered per topic
  - Add widget for NumberOfNotificationsFailed per topic
  - Add widget showing recent pipeline executions
  - _Requirements: 7.5_

- [ ] 23. Document lessons learned
  - Document root cause of notification failure
  - Document fix applied
  - Document verification steps
  - Add to troubleshooting guide
  - Share with team
  - _Requirements: All_

