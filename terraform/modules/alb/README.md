# ALB Module

Creates an Application Load Balancer for public-facing services with security best practices, including target groups and listener rules for path-based routing.

## Features

- Internet-facing ALB in public subnets
- HTTPS listener with ACM certificate (TLS 1.2+ enforced)
- HTTP listener with automatic redirect to HTTPS
- Target groups for each public service with configurable health checks
- Listener rules with path-based and host-based routing
- Access logs to encrypted S3 bucket with lifecycle policies
- Security group allowing inbound 80/443
- Deletion protection enabled by default for production
- Cross-zone load balancing enabled
- Invalid header field dropping enabled
- Configurable deregistration delay for graceful shutdown

## Resources Created

- `aws_lb` - Application Load Balancer
- `aws_lb_listener` (HTTPS) - Port 443 listener with ACM certificate
- `aws_lb_listener` (HTTP) - Port 80 listener with redirect to HTTPS
- `aws_lb_target_group` - Target groups for each public service
- `aws_lb_listener_rule` - Listener rules for path-based routing
- `aws_security_group` - ALB security group
- `aws_s3_bucket` - Access logs bucket (optional)
- S3 bucket policies, versioning, encryption, and lifecycle rules

## Usage

### Basic Usage

```hcl
module "alb" {
  source = "./modules/alb"

  project_name      = "myproject"
  environment       = "prod"
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  certificate_arn   = var.acm_certificate_arn

  # Optional: Use existing KMS key for S3 encryption
  kms_key_s3_arn = module.security.kms_key_s3_arn

  tags = {
    Owner      = "platform-team"
    CostCenter = "infrastructure"
  }
}
```

### With Target Groups and Listener Rules

```hcl
module "alb" {
  source = "./modules/alb"

  project_name      = "myproject"
  environment       = "prod"
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  certificate_arn   = var.acm_certificate_arn

  # Define target groups for public services
  target_groups = {
    "api-service" = {
      port                  = 3000
      health_check_path     = "/health"
      priority              = 100
      path_patterns         = ["/api/*"]
      deregistration_delay  = 30
      health_check_interval = 30
      health_check_timeout  = 5
      healthy_threshold     = 2
      unhealthy_threshold   = 3
    }
    "web-service" = {
      port                  = 8080
      health_check_path     = "/healthz"
      priority              = 200
      path_patterns         = ["/*"]
      deregistration_delay  = 60
      health_check_interval = 15
      health_check_timeout  = 5
      healthy_threshold     = 2
      unhealthy_threshold   = 2
    }
  }

  tags = {
    Owner      = "platform-team"
    CostCenter = "infrastructure"
  }
}

# Reference target group ARN in ECS service
module "api_service" {
  source = "./modules/ecs-service"
  
  target_group_arn = module.alb.target_group_arns["api-service"]
  # ... other configuration
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0.0 |
| aws | >= 5.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Name of the project, used for resource naming | `string` | n/a | yes |
| environment | Environment name (develop, test, qa, prod) | `string` | n/a | yes |
| vpc_id | ID of the VPC where the ALB will be created | `string` | n/a | yes |
| public_subnet_ids | List of public subnet IDs for the ALB (minimum 2) | `list(string)` | n/a | yes |
| certificate_arn | ARN of the ACM certificate for HTTPS listener | `string` | n/a | yes |
| enable_access_logs | Enable ALB access logs to S3 | `bool` | `true` | no |
| access_logs_bucket_name | Name of the S3 bucket for ALB access logs | `string` | `""` | no |
| access_logs_prefix | Prefix for ALB access logs in S3 bucket | `string` | `"alb-logs"` | no |
| kms_key_s3_arn | ARN of the KMS key for S3 bucket encryption | `string` | `""` | no |
| internal | Whether the ALB is internal or internet-facing | `bool` | `false` | no |
| idle_timeout | Connection idle timeout in seconds | `number` | `60` | no |
| enable_deletion_protection | Enable deletion protection (defaults to true for prod) | `bool` | `null` | no |
| drop_invalid_header_fields | Drop invalid header fields in HTTP requests | `bool` | `true` | no |
| enable_http2 | Enable HTTP/2 support | `bool` | `true` | no |
| enable_cross_zone_load_balancing | Enable cross-zone load balancing | `bool` | `true` | no |
| ssl_policy | SSL policy for HTTPS listener | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| allowed_cidr_blocks | CIDR blocks allowed to access the ALB | `list(string)` | `["0.0.0.0/0"]` | no |
| target_groups | Map of target group configurations for public services | `map(object)` | `{}` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

### Target Group Configuration

Each target group in the `target_groups` map supports the following attributes:

| Attribute | Description | Type | Default | Required |
|-----------|-------------|------|---------|:--------:|
| port | Port the target receives traffic on | `number` | n/a | yes |
| protocol | Protocol for routing traffic to targets | `string` | `"HTTP"` | no |
| deregistration_delay | Time to wait before deregistering target (seconds) | `number` | `30` | no |
| slow_start | Time to gradually increase traffic to new targets (seconds) | `number` | `0` | no |
| health_check_path | Path for health check requests | `string` | n/a | yes |
| health_check_port | Port for health check requests | `string` | `"traffic-port"` | no |
| health_check_protocol | Protocol for health check requests | `string` | `"HTTP"` | no |
| health_check_interval | Interval between health checks (seconds) | `number` | `30` | no |
| health_check_timeout | Timeout for health check response (seconds) | `number` | `5` | no |
| healthy_threshold | Consecutive successful checks to mark healthy | `number` | `2` | no |
| unhealthy_threshold | Consecutive failed checks to mark unhealthy | `number` | `3` | no |
| health_check_matcher | HTTP codes indicating successful health check | `string` | `"200-299"` | no |
| stickiness_enabled | Enable session stickiness | `bool` | `false` | no |
| stickiness_type | Type of stickiness (lb_cookie or app_cookie) | `string` | `"lb_cookie"` | no |
| stickiness_cookie_duration | Cookie duration for stickiness (seconds) | `number` | `86400` | no |
| priority | Priority for listener rule (1-50000) | `number` | n/a | yes |
| path_patterns | Path patterns for routing (e.g., ["/api/*"]) | `list(string)` | `[]` | no |
| host_headers | Host headers for routing (e.g., ["api.example.com"]) | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| alb_id | ID of the Application Load Balancer |
| alb_arn | ARN of the Application Load Balancer |
| alb_arn_suffix | ARN suffix for CloudWatch metrics |
| alb_dns_name | DNS name of the Application Load Balancer |
| alb_zone_id | Canonical hosted zone ID for Route53 |
| alb_name | Name of the Application Load Balancer |
| https_listener_arn | ARN of the HTTPS listener |
| http_listener_arn | ARN of the HTTP listener |
| security_group_id | ID of the ALB security group |
| security_group_arn | ARN of the ALB security group |
| security_group_name | Name of the ALB security group |
| access_logs_bucket_id | ID of the S3 bucket for access logs |
| access_logs_bucket_arn | ARN of the S3 bucket for access logs |
| alb_url | HTTPS URL of the Application Load Balancer |
| deletion_protection_enabled | Whether deletion protection is enabled |
| ssl_policy | SSL policy used by the HTTPS listener |
| target_group_arns | Map of target group ARNs by service name |
| target_group_arn_suffixes | Map of target group ARN suffixes by service name |
| target_group_names | Map of target group names by service name |
| target_group_ids | Map of target group IDs by service name |
| listener_rule_arns | Map of listener rule ARNs by service name |

## Security Considerations

- **TLS 1.2+**: The default SSL policy enforces TLS 1.2 or higher
- **Deletion Protection**: Automatically enabled for production environments
- **Access Logs**: Stored in encrypted S3 bucket with versioning
- **Security Group**: Only allows inbound traffic on ports 80 and 443
- **Invalid Headers**: Dropped by default to prevent HTTP request smuggling
- **Deregistration Delay**: Configurable to allow in-flight requests to complete

## Health Check Best Practices

- Set `health_check_path` to a dedicated health endpoint (e.g., `/health`, `/healthz`)
- Use `health_check_interval` of 15-30 seconds for responsive detection
- Set `health_check_timeout` lower than `health_check_interval`
- Use `healthy_threshold` of 2 for quick recovery
- Use `unhealthy_threshold` of 2-3 to avoid false positives

## Compliance

This module supports the following compliance requirements:

- **NIST SC-8**: TLS encryption in transit
- **NIST AU-2**: Access logging enabled
- **SOC-2 CC6.6**: Encryption of data in transit
- **SOC-2 CC7.2**: System monitoring via access logs
- **Requirements 6.5**: Health check configuration for target groups
- **Requirements 8.2**: Configurable health check intervals and thresholds
- **Requirements 8.4**: Path-based routing via listener rules
- **Requirements 8.6**: Deregistration delay for graceful shutdown
