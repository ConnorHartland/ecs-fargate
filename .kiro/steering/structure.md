# Project Structure

## Root Directory

```
.
├── terraform/           # All infrastructure code
├── tests/              # Go-based infrastructure tests
├── DEPLOYMENT.md       # Comprehensive deployment guide
└── README.md           # Project overview
```

## Terraform Directory Structure

```
terraform/
├── main.tf                    # Root module - orchestrates all infrastructure
├── variables.tf               # Root-level input variables
├── outputs.tf                 # Root-level outputs
├── versions.tf                # Terraform and provider version constraints
├── backend.tf                 # S3 backend configuration
├── environment-config.tf      # Environment-specific logic and locals
├── modules/                   # Reusable Terraform modules
│   ├── networking/           # VPC, subnets, security groups, NAT
│   ├── security/             # KMS keys, IAM roles
│   ├── secrets/              # Secrets Manager configuration
│   ├── ecs-cluster/          # ECS cluster with capacity providers
│   ├── ecs-service/          # ECS service with auto-scaling
│   ├── ecs-task-definition/  # Task definition with runtime configs
│   ├── ecr/                  # Container registry
│   ├── alb/                  # Application Load Balancer
│   ├── cicd/                 # CodePipeline + CodeBuild
│   ├── monitoring/           # CloudWatch logs, alarms, dashboards
│   ├── cloudtrail/           # Audit logging
│   ├── config/               # AWS Config for compliance
│   └── service/              # **Main module** - combines all components for a microservice
├── services/                  # Service-specific configurations
│   ├── example-nodejs-public/
│   ├── example-nodejs-internal/
│   ├── example-python-public/
│   └── example-python-internal/
├── environments/              # Environment-specific configurations
│   ├── develop/
│   ├── test/
│   ├── qa/
│   └── prod/
├── templates/                 # CodeBuild buildspec templates
└── scripts/                   # Helper scripts for setup
```

## Module Organization Pattern

Each module follows this structure:
```
module-name/
├── main.tf          # Primary resource definitions
├── variables.tf     # Input variables with validation
├── outputs.tf       # Output values
├── versions.tf      # Provider version constraints
└── README.md        # Module documentation
```

## Service Module (Most Important)

The `modules/service/` module is the primary interface for deploying microservices. It internally uses:
- `modules/ecr` - Container registry
- `modules/ecs-task-definition` - Task configuration
- `modules/ecs-service` - Service and auto-scaling
- `modules/cicd` - Build and deployment pipeline
- Security groups and IAM roles

**Usage**: Copy an example from `services/example-*` and customize.

## Environment Configuration

Each environment has:
- `backend.hcl` - Backend configuration for state storage
- `terraform.tfvars` - Environment-specific variable values

Environment-specific defaults are defined in `environment-config.tf` using locals:
- Log retention: prod=90 days, non-prod=30 days
- Resource protection: prod=enabled, non-prod=disabled
- Fargate Spot: prod=0%, non-prod=70%
- Auto-scaling: prod=higher minimums, non-prod=lower minimums

## Testing Structure

```
tests/
├── go.mod                    # Go module dependencies
├── properties/               # Property-based tests
│   ├── networking_properties_test.go
│   └── ecs_service_properties_test.go
└── helpers/                  # Test utilities
    ├── generators.go         # Generate test data
    └── parsers.go           # Parse Terraform outputs
```

## Key Files to Know

- **terraform/main.tf**: Entry point - instantiates all core modules
- **terraform/environment-config.tf**: Environment-specific logic (locals)
- **terraform/modules/service/main.tf**: Service deployment orchestration
- **DEPLOYMENT.md**: Step-by-step deployment procedures
- **terraform/services/README.md**: Service configuration guide with Kafka setup

## Naming Conventions

### Resources
- Format: `${environment}-${project_name}-${resource_type}`
- Example: `prod-ecs-fargate-cluster`

### Services
- Format: `${service_name}-${environment}`
- Example: `api-gateway-prod`

### Tags
All resources must have:
- `Environment` - develop/test/qa/prod
- `Owner` - Team or individual responsible
- `CostCenter` - For billing allocation
- `Compliance` - NIST-SOC2
- `ManagedBy` - Terraform

## Working with Services

### To add a new service:
1. Copy example from `terraform/services/example-*`
2. Customize `main.tf` with service-specific values
3. Create secrets in AWS Secrets Manager
4. Run `terraform init` and `terraform apply`
5. Push initial Docker image to ECR
6. Pipeline handles subsequent deployments

### Service types:
- **public**: Exposed via ALB, has target group and listener rules
- **internal**: No ALB, uses Kafka and/or service discovery

### Runtimes:
- **nodejs**: Sets NODE_ENV, uses npm/curl
- **python**: Sets PYTHON_ENV, uses pytest/urllib

## Important Patterns

### Module Composition
Root module (`main.tf`) composes infrastructure modules. Service module composes service-specific resources.

### Environment Isolation
Production VPC is isolated (10.100.x.x). Non-production environments share CIDR space (10.0.x.x, 10.1.x.x, 10.2.x.x).

### Security Layers
1. Network: Private subnets, security groups
2. Encryption: KMS for all data at rest
3. Secrets: Secrets Manager for credentials
4. Audit: CloudTrail + AWS Config
5. Access: IAM roles with least privilege

### CI/CD Flow
- develop: feature/* branches, manual trigger
- test/qa: release/*.*.* branches, automatic
- prod: prod/* branches, manual approval required
