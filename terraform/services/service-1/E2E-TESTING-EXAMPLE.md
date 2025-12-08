# E2E Testing Integration

This document explains how to enable E2E testing for service-1 after deployment.

## Overview

When enabled, the pipeline will have 4 stages:
1. **Source** - Clone service code from Bitbucket
2. **Build** - Build and push Docker image
3. **Deploy** - Deploy to ECS
4. **E2E-Tests** - Clone QA test repo and run tests against deployed service

## Configuration

Add these parameters to your service module in `main.tf`:

```hcl
module "service_1" {
  source = "../../modules/service"
  
  # ... existing configuration ...
  
  # E2E Testing Configuration
  enable_e2e_tests       = true
  e2e_test_repository_id = "connor-cicd/qa-tests"  # Your QA test repo
  e2e_test_branch        = "main"                   # Branch with tests
  
  # Pass environment-specific variables to tests
  e2e_test_environment_variables = {
    API_URL     = "https://${local.alb_dns_name}"  # Your service URL
    ENVIRONMENT = local.environment
    SERVICE_NAME = "service-1"
  }
  
  e2e_test_timeout_minutes = 30  # Test timeout
}
```

## QA Test Repository Structure

Your QA test repository should have a structure like:

```
qa-tests/
├── package.json          # For Node.js tests
├── tests/
│   ├── api.test.js
│   ├── integration.test.js
│   └── e2e.test.js
└── buildspec.yml         # Optional custom buildspec
```

### Example package.json

```json
{
  "name": "service-1-e2e-tests",
  "scripts": {
    "test": "jest --coverage"
  },
  "devDependencies": {
    "jest": "^29.0.0",
    "axios": "^1.0.0"
  }
}
```

### Example Test (tests/api.test.js)

```javascript
const axios = require('axios');

const API_URL = process.env.API_URL || 'http://localhost:3000';

describe('Service-1 API Tests', () => {
  test('Health check endpoint returns 200', async () => {
    const response = await axios.get(`${API_URL}/health`);
    expect(response.status).toBe(200);
  });

  test('API returns expected data structure', async () => {
    const response = await axios.get(`${API_URL}/api/data`);
    expect(response.data).toHaveProperty('status');
    expect(response.data).toHaveProperty('data');
  });
});
```

## Custom Buildspec

If you need more control, provide a custom buildspec:

```hcl
e2e_test_buildspec = <<-BUILDSPEC
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 18
    commands:
      - npm ci

  build:
    commands:
      - echo "Running E2E tests against $API_URL"
      - npm test

artifacts:
  files:
    - coverage/**/*
    - test-results/**/*
BUILDSPEC
```

## Workflow

1. Developer pushes to `develop` branch
2. Bitbucket webhook triggers pipeline
3. Pipeline builds and deploys service
4. **After successful deployment**, pipeline automatically:
   - Clones your QA test repository
   - Runs tests with environment variables
   - Fails pipeline if tests fail
5. You get notified via SNS of success/failure

## Benefits

- **Automated quality gates**: Tests run automatically after every deployment
- **Fast feedback**: Know immediately if deployment broke something
- **Separate test repo**: QA team can manage tests independently
- **Environment-specific**: Different tests for develop/test/prod
- **Fail fast**: Pipeline fails if tests fail, preventing bad deployments

## Troubleshooting

### View test logs
```bash
aws logs tail /aws/codebuild/ecs-fargate-develop-service-1-e2e-tests --follow
```

### Check pipeline status
```bash
aws codepipeline get-pipeline-state --name ecs-fargate-develop-service-1-pipeline
```

### Manually trigger tests
```bash
aws codepipeline start-pipeline-execution --name ecs-fargate-develop-service-1-pipeline
```
