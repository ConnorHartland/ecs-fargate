# Implementation Plan

- [x] 1. Fix Config module S3 path inconsistencies





  - Update IAM role policy to use consistent path pattern matching bucket policy and delivery channel
  - Add local variable for config prefix to ensure single source of truth
  - Verify all S3 resource ARNs reference the same path pattern
  - _Requirements: 2.3, 2.5_

- [ ]* 1.1 Write property test for Config path consistency
  - **Property 3: S3 path consistency**
  - **Validates: Requirements 2.3, 2.5**

- [x] 2. Verify and fix ALB module S3 bucket policy







  - Review bucket policy to ensure all three required service principals have correct permissions
  - Verify resource ARN patterns match the access_logs_prefix configuration
  - Add local variable for ALB logs path if not already present
  - _Requirements: 1.1, 1.2, 1.3, 1.5_

- [ ]* 2.1 Write property test for ALB bucket policy completeness
  - **Property 1: ALB bucket policy completeness**
  - **Validates: Requirements 1.1, 1.2, 1.3**

- [ ] 3. Ensure proper Terraform dependency ordering
  - Verify ALB resource has depends_on for S3 bucket policy
  - Verify Config delivery channel has depends_on for S3 bucket policy
  - Add explicit dependencies if missing
  - _Requirements: 1.4, 2.4_

- [ ]* 3.1 Write property test for Terraform dependency ordering
  - **Property 4: Terraform dependency ordering**
  - **Validates: Requirements 1.4, 2.4**

- [ ]* 4. Write property test for Config bucket policy completeness
  - **Property 2: Config bucket policy completeness**
  - **Validates: Requirements 2.1, 2.2**

- [ ] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ]* 6. Create integration test for ALB access logs
  - Deploy ALB module with access logs enabled
  - Verify no "Access Denied" errors during deployment
  - Verify logs are written to S3 bucket
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ]* 7. Create integration test for Config delivery channel
  - Deploy Config module with delivery channel
  - Verify no "Insufficient delivery policy" errors during deployment
  - Verify Config snapshots are written to S3 bucket
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
