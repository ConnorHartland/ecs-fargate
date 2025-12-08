# Terraform Templates

This directory contains template files used by the Terraform modules for CI/CD configuration.

## buildspec.yml

The `buildspec.yml` file is a CodeBuild buildspec template that defines the build, test, and deployment process for Docker images.

### Features

- **ECR Authentication**: Automatic login to Amazon ECR
- **Multi-tag Image Pushing**: Images are tagged with:
  - `latest` - Rolling latest tag
  - `<commit-sha>` - Immutable commit reference (7 characters)
  - `<environment>-<commit-sha>` - Environment-specific commit reference
  - `<environment>-latest` - Environment-specific rolling tag
- **Security Scanning**: Trivy vulnerability scanning with configurable severity levels
- **Test Execution**: Automatic detection and execution of tests (Node.js/Python)
- **ECS Deployment Artifact**: Generates `imagedefinitions.json` for ECS deployments

### Required Environment Variables

These variables are automatically set by the CodeBuild project:

| Variable | Description |
|----------|-------------|
| `AWS_ACCOUNT_ID` | AWS account ID |
| `AWS_DEFAULT_REGION` | AWS region |
| `ECR_REPOSITORY_URL` | Full ECR repository URL |
| `ENVIRONMENT` | Deployment environment (develop, test, qa, prod) |
| `CONTAINER_NAME` | Name of the container for ECS task definition |

### Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE_TAG` | Commit SHA | Override for image tag |
| `TRIVY_SEVERITY` | `HIGH,CRITICAL` | Severity levels to scan |
| `SKIP_TESTS` | `false` | Set to `true` to skip test execution |
| `SKIP_SECURITY_SCAN` | `false` | Set to `true` to skip security scanning |

### Build Phases

1. **Install**: Installs Trivy security scanner
2. **Pre-Build**: ECR login and tag preparation
3. **Build**: Docker build, tagging, security scan, and tests
4. **Post-Build**: Push images to ECR and create deployment artifacts

### Artifacts

The build produces the following artifacts:

- `imagedefinitions.json` - ECS deployment configuration
- `build-metadata.json` - Build information and tags
- `trivy-report.json` - Security scan results (JSON format)

### Usage

#### Option 1: Use Default Buildspec (Embedded)

The CI/CD module includes a default buildspec. No additional configuration needed:

```hcl
module "cicd" {
  source = "./modules/cicd"
  # ... other variables
  # buildspec_path is empty by default, uses embedded buildspec
}
```

#### Option 2: Use Custom Buildspec Template

Reference this template file in your module configuration:

```hcl
module "cicd" {
  source = "./modules/cicd"
  # ... other variables
  buildspec_path = "${path.root}/templates/buildspec.yml"
}
```

#### Option 3: Service-Specific Buildspec

Copy this template to your service repository and customize as needed:

```bash
cp terraform/templates/buildspec.yml my-service/buildspec.yml
```

### Security Considerations

- **Production Builds**: Critical vulnerabilities will fail the build in production environment
- **Non-Production Builds**: Vulnerabilities are reported but don't fail the build
- **Secrets**: Never hardcode secrets in the buildspec; use environment variables from Secrets Manager

### Customization

To customize the buildspec for specific services:

1. Copy this template to your service repository
2. Modify the test commands for your runtime
3. Add any service-specific build steps
4. Update the CI/CD module to reference your custom buildspec

### Troubleshooting

**ECR Login Fails**
- Verify the CodeBuild service role has `ecr:GetAuthorizationToken` permission
- Check that the ECR repository exists

**Security Scan Fails**
- Review the Trivy report for vulnerability details
- Update dependencies to fix vulnerabilities
- For non-critical issues, consider adjusting `TRIVY_SEVERITY`

**Tests Fail**
- Check CloudWatch logs for detailed test output
- Ensure test dependencies are included in the Docker image
- Set `SKIP_TESTS=true` temporarily to debug build issues
