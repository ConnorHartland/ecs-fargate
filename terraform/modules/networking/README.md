# Networking Module

Creates VPC infrastructure with public and private subnets for ECS Fargate deployment.

## Resources Created

- VPC with DNS support enabled
- Public subnets across availability zones (for ALB)
- Private subnets across availability zones (for ECS tasks)
- Internet Gateway for public subnets
- NAT Gateways in each public subnet (configurable)
- Route tables for public and private subnets
- VPC Flow Logs to CloudWatch
- Network ACLs for additional security layer
- Security groups for ECS services:
  - Public services security group (allows traffic from ALB)
  - Internal services security group (allows traffic from other services and Kafka)
  - Kafka client security group (allows outbound to Kafka brokers)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                    VPC                                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                         Public Subnets                                  ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                     ││
│  │  │   AZ-1a     │  │   AZ-1b     │  │   AZ-1c     │                     ││
│  │  │  NAT GW     │  │  NAT GW     │  │  NAT GW     │                     ││
│  │  │  ALB        │  │  ALB        │  │  ALB        │                     ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘                     ││
│  │         │                │                │                             ││
│  │         └────────────────┼────────────────┘                             ││
│  │                          │                                              ││
│  │                    Internet Gateway                                     ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        Private Subnets                                  ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                     ││
│  │  │   AZ-1a     │  │   AZ-1b     │  │   AZ-1c     │                     ││
│  │  │  ECS Tasks  │  │  ECS Tasks  │  │  ECS Tasks  │                     ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘                     ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  environment        = "prod"
  project_name       = "ecs-fargate"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # Optional: Cost optimization for non-production
  single_nat_gateway = false  # Set to true for single NAT Gateway

  # VPC Flow Logs
  enable_vpc_flow_logs     = true
  flow_logs_retention_days = 30

  # Service Security Groups
  create_service_security_groups = true
  alb_security_group_id          = module.alb.security_group_id  # Required for public services
  kafka_security_group_id        = "sg-kafka123"                  # Optional: Kafka cluster SG
  kafka_broker_endpoints         = ["broker1:9092", "broker2:9092"]

  tags = {
    Team = "platform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Deployment environment (develop, test, qa, prod) | `string` | n/a | yes |
| project_name | Project name used for resource naming | `string` | n/a | yes |
| vpc_cidr | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | no |
| availability_zones | List of availability zones for multi-AZ deployment | `list(string)` | n/a | yes |
| enable_nat_gateway | Enable NAT Gateway for private subnet internet access | `bool` | `true` | no |
| single_nat_gateway | Use a single NAT Gateway instead of one per AZ | `bool` | `false` | no |
| enable_vpc_flow_logs | Enable VPC Flow Logs for network traffic analysis | `bool` | `true` | no |
| flow_logs_retention_days | CloudWatch log retention in days for VPC Flow Logs | `number` | `30` | no |
| create_service_security_groups | Whether to create security groups for ECS services | `bool` | `true` | no |
| alb_security_group_id | Security group ID of the ALB (required for public service SG) | `string` | `""` | no |
| kafka_security_group_id | Security group ID of the Kafka cluster | `string` | `""` | no |
| kafka_broker_endpoints | List of Kafka broker endpoints (host:port format) | `list(string)` | `[]` | no |
| additional_internal_cidr_blocks | Additional CIDR blocks allowed to access internal services | `list(string)` | `[]` | no |
| tags | Additional tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| vpc_cidr_block | CIDR block of the VPC |
| vpc_arn | ARN of the VPC |
| public_subnet_ids | List of public subnet IDs |
| public_subnet_cidrs | List of public subnet CIDR blocks |
| private_subnet_ids | List of private subnet IDs |
| private_subnet_cidrs | List of private subnet CIDR blocks |
| availability_zones | List of availability zones used |
| internet_gateway_id | ID of the Internet Gateway |
| nat_gateway_ids | List of NAT Gateway IDs |
| nat_gateway_public_ips | List of NAT Gateway public IP addresses |
| public_route_table_id | ID of the public route table |
| private_route_table_ids | List of private route table IDs |
| flow_log_id | ID of the VPC Flow Log |
| flow_log_cloudwatch_log_group_arn | ARN of the CloudWatch Log Group for VPC Flow Logs |
| public_services_security_group_id | ID of the security group for public-facing ECS services |
| public_services_security_group_arn | ARN of the security group for public-facing ECS services |
| internal_services_security_group_id | ID of the security group for internal ECS services |
| internal_services_security_group_arn | ARN of the security group for internal ECS services |
| kafka_client_security_group_id | ID of the security group for Kafka client access |
| kafka_client_security_group_arn | ARN of the security group for Kafka client access |

## Network Segmentation

- **Public Subnets**: Used for ALB and NAT Gateways. Have routes to Internet Gateway.
- **Private Subnets**: Used for ECS tasks. Have routes to NAT Gateway (no direct internet access).

## Security Considerations

- ECS tasks are placed in private subnets with no direct internet access
- NAT Gateways provide outbound internet access for private subnets
- VPC Flow Logs capture all network traffic for security auditing
- Network ACLs provide an additional layer of security

## Service Security Groups

The module creates three security groups for ECS services following the principle of least privilege:

### Public Services Security Group
- **Purpose**: For public-facing ECS services that receive traffic from the ALB
- **Ingress**: Allows all TCP traffic from the ALB security group only
- **Egress**: Allows all outbound traffic (for NAT Gateway access)
- **Kafka Access**: Allows outbound to Kafka brokers on ports 9092-9096

### Internal Services Security Group
- **Purpose**: For internal ECS services that communicate via Kafka or service-to-service calls
- **Ingress**: 
  - Allows traffic from public services security group
  - Allows traffic from other internal services (self-reference)
  - Allows traffic from Kafka security group (if provided)
  - Allows traffic from additional CIDR blocks (if configured)
- **Egress**: Allows all outbound traffic
- **Kafka Access**: Allows outbound to Kafka brokers on ports 9092-9096

### Kafka Client Security Group
- **Purpose**: Dedicated security group for Kafka client access
- **Egress**: 
  - Allows Kafka protocol traffic (ports 9092-9096) to Kafka cluster
  - Allows HTTPS (port 443) for schema registry and Kafka management

### Security Group Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Internet                                        │
│                                  │                                           │
│                                  ▼                                           │
│                        ┌─────────────────┐                                   │
│                        │   ALB SG        │                                   │
│                        │ (80/443 inbound)│                                   │
│                        └────────┬────────┘                                   │
│                                 │                                            │
│                                 ▼                                            │
│                   ┌─────────────────────────┐                                │
│                   │  Public Services SG     │                                │
│                   │  (from ALB only)        │──────────┐                     │
│                   └─────────────┬───────────┘          │                     │
│                                 │                      │                     │
│                                 ▼                      ▼                     │
│                   ┌─────────────────────────┐  ┌──────────────┐              │
│                   │  Internal Services SG   │  │  Kafka       │              │
│                   │  (from public/internal) │◄─│  Cluster     │              │
│                   └─────────────────────────┘  └──────────────┘              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Cost Optimization

For non-production environments, set `single_nat_gateway = true` to use a single NAT Gateway instead of one per AZ. This reduces costs but also reduces availability.
