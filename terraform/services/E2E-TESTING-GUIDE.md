# E2E Testing Configuration Guide

## Overview

Your CI/CD pipeline now supports E2E testing as a separate stage that runs **after** deployment. The E2E tests are pulled from a separate QA repository and executed against the deployed service.

## Pipeline Flow

```
Source → Build → Deploy → E2E Tests
         (Docker)  (ECS)    (QA Repo)
```

## How It Works

1. **Source Stage**: Pulls your service code from Bitbucket
2. **Build Stage**: Builds Docker image, runs security scans, runs unit tests
3. **Deploy Stage**: Deploys to ECS Fargate
4. **E2E Test Stage** (NEW):
   - Clones your separate QA test repository
   - Runs E2E tests against the deployed service
   - Fails the pipeline if tests fail

## Configuration

### 1. Enable E2E Tests in Your Service

Add these variables to your service module in `terraform/services/your-service/main.tf`:

```hcl
module "your_service" {
  source = "../../modules/service"
  
  # ... existing configuration ...
  
  # E2E Testing Configuration
  enable_e2e_tests       = true
  e2e_test_repository_id = "your-org/qa-tests"  # Bitbucket repo with E2E tests
  e2e_test_branch        = "main"               # Branch to use for tests
  
  e2e_test_environment_variables = {
    API_URL = "https://your-service-url.com"  # Service endpoint
    # Note: ENVIRONMENT and SERVICE_NAME are automatically provided
    # Add any other custom env vars your tests need
  }
  
  e2e_test_timeout_minutes = 30  # Adjust based on test duration
}
```

### 2. Create Your QA Test Repository

Your E2E test repository should contain:

**For Node.js tests:**
```
qa-tests/
├── package.json
├── tests/
│   └── service-1.test.js
└── buildspec.yml (optional)
```

**For Python tests:**
```
qa-tests/
├── requirements.txt
├── pytest.ini
├── tests/
│   └── test_service_1.py
└── buildspec.yml (optional)
```

### 3. Default Buildspec

If you don't provide a custom buildspec, the pipeline uses this default:

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 18
    commands:
      - |
        if [ -f "package.json" ]; then
          npm ci
        elif [ -f "requirements.txt" ]; then
          pip install -r requirements.txt
        fi

  build:
    commands:
      - |
        if [ -f "package.json" ]; then
          npm test
        elif [ -f "pytest.ini" ]; then
          pytest
        fi
```

### 4. Custom Buildspec (Optional)

For more control, provide a custom buildspec:

```hcl
e2e_test_buildspec = <<-BUILDSPEC
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 18
    commands:
      - npm ci
      - npm install -g newman  # For Postman collections

  build:
    commands:
      - echo "Running E2E tests against $API_URL"
      - npm run test:e2e
      - newman run postman-collection.json --env-var "baseUrl=$API_URL"

artifacts:
  files:
    - test-results/**/*
BUILDSPEC
```

## Environment Variables

The E2E test stage **automatically receives** these variables (do NOT add them to `e2e_test_environment_variables`):
- `ENVIRONMENT` - The deployment environment (develop/test/qa/prod)
- `SERVICE_NAME` - The service being tested

You can add **additional** custom variables via `e2e_test_environment_variables`:
- `API_URL` - Service endpoint to test
- `API_KEY` - Authentication credentials
- `TIMEOUT` - Test timeout values
- Any other test-specific configuration

## Example: Service-1 Configuration

```hcl
module "service_1" {
  source = "../../modules/service"
  
  service_name = "service-1"
  # ... other config ...
  
  # E2E Testing
  enable_e2e_tests       = true
  e2e_test_repository_id = "connor-cicd/qa-tests"
  e2e_test_branch        = "main"
  
  e2e_test_environment_variables = {
    API_URL = "https://develop-alb.example.com"
    # ENVIRONMENT and SERVICE_NAME are automatically set
  }
}
```

## Testing Different Environments

You can conditionally enable E2E tests per environment:

```hcl
# Only run E2E tests in test/qa environments
enable_e2e_tests = contains(["test", "qa"], local.environment)

# Use environment-specific test branches
e2e_test_branch = local.environment == "prod" ? "main" : "develop"

# Environment-specific API URLs
e2e_test_environment_variables = {
  API_URL = local.environment == "prod" ? 
    "https://api.production.com" : 
    "https://api-${local.environment}.staging.com"
  # ENVIRONMENT and SERVICE_NAME are automatically provided
}
```

## Deployment

After updating your service configuration:

```bash
cd terraform/services/service-1
terraform init
terraform plan
terraform apply
```

The pipeline will now include an E2E test stage after deployment.

## Monitoring

- **CloudWatch Logs**: `/aws/codebuild/your-service-e2e-tests`
- **Pipeline Console**: View E2E test stage in CodePipeline
- **Test Results**: Stored as artifacts in S3

## Troubleshooting

### Tests Not Running
- Verify `enable_e2e_tests = true`
- Check `e2e_test_repository_id` is correct
- Ensure CodeConnections has access to QA repo

### Tests Failing
- Check CloudWatch logs for the E2E test CodeBuild project
- Verify environment variables are correct
- Test API endpoint is accessible from CodeBuild

### Timeout Issues
- Increase `e2e_test_timeout_minutes`
- Optimize test execution time
- Consider parallel test execution

## Best Practices

1. **Separate Repository**: Keep E2E tests in a separate repo from service code
2. **Environment Parity**: Use same test suite across all environments
3. **Fast Tests**: Keep E2E tests under 10 minutes when possible
4. **Idempotent**: Tests should be repeatable without side effects
5. **Clear Failures**: Provide detailed error messages for debugging
6. **Conditional Execution**: Consider skipping E2E tests for hotfixes in production

## Next Steps

1. Create your QA test repository in Bitbucket
2. Add E2E test configuration to your services
3. Write your first E2E test
4. Deploy and verify the pipeline includes the E2E stage
5. Monitor test results and iterate
