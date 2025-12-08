# Service Configuration Examples

This directory contains example service configurations demonstrating how to deploy microservices using the reusable service module. Each example shows a different combination of runtime (Node.js or Python) and service type (public or internal).

## Overview

The infrastructure supports two types of services:

1. **Public Services**: Exposed via Application Load Balancer for HTTP/HTTPS traffic
2. **Internal Services**: Communicate via Kafka message broker without ALB exposure

Both service types can connect to Kafka for event-driven communication.

## Example Configurations

### 1. Node.js Public Service (`example-nodejs-public/`)

**Use Case**: API Gateway or web service that needs to be accessible from the internet

**Key Features**:
- Exposed via ALB with path-based routing (`/api/*`, `/v1/*`)
- Connects to Kafka for event processing
- Auto-scales based on CPU/memory (2-10 tasks)
- Health checks via ALB
- TLS termination at ALB

**Configuration Highlights**:
```hcl
service_type   = "public"
runtime        = "nodejs"
container_port = 3000
path_patterns  = ["/api/*", "/v1/*"]
```

### 2. Node.js Internal Service (`example-nodejs-internal/`)

**Use Case**: Background worker or event processor that only communicates via Kafka

**Key Features**:
- No ALB exposure (internal only)
- Primary communication via Kafka
- Service discovery via AWS Cloud Map
- Auto-scales based on CPU/memory (1-5 tasks)
- Container-level health checks only

**Configuration Highlights**:
```hcl
service_type   = "internal"
runtime        = "nodejs"
enable_service_discovery = true
# No ALB configuration
```

### 3. Python Public Service (`example-python-public/`)

**Use Case**: Analytics API or data service accessible via HTTP/HTTPS

**Key Features**:
- Exposed via ALB with path-based routing (`/analytics/*`, `/reports/*`)
- Higher resource allocation (1 vCPU, 2 GB memory)
- Connects to Kafka for event processing
- Auto-scales based on CPU/memory (1-8 tasks)
- Longer deregistration delay (60s) for graceful shutdown

**Configuration Highlights**:
```hcl
service_type   = "public"
runtime        = "python"
container_port = 8000
cpu            = 1024
memory         = 2048
```

### 4. Python Internal Service (`example-python-internal/`)

**Use Case**: Data processor or ETL pipeline that consumes from Kafka

**Key Features**:
- No ALB exposure (internal only)
- Primary communication via Kafka
- Service discovery via AWS Cloud Map
- Batch processing configuration
- Auto-scales based on CPU/memory (1-6 tasks)

**Configuration Highlights**:
```hcl
service_type   = "internal"
runtime        = "python"
enable_service_discovery = true
# Kafka consumer configuration
```

## Kafka Broker Configuration

All services (both public and internal) can connect to Kafka for event-driven communication. The Kafka cluster is managed externally and accessed via the following configuration.

### Kafka Connection Parameters

#### Required Variables

```hcl
variable "kafka_brokers" {
  type        = list(string)
  description = "List of Kafka broker endpoints"
  # Example: ["broker1.kafka.example.com:9092", "broker2.kafka.example.com:9092", "broker3.kafka.example.com:9092"]
}

variable "kafka_security_group_id" {
  type        = string
  description = "Security group ID for Kafka cluster access"
  # This security group should allow inbound traffic from ECS tasks
}
```

#### Environment Variables Passed to Containers

The following Kafka-related environment variables are automatically configured:

**Connection Settings**:
- `KAFKA_BROKERS`: Comma-separated list of broker endpoints
- `KAFKA_CLIENT_ID`: Unique identifier for this service instance
- `KAFKA_GROUP_ID`: Consumer group ID for this service

**Topic Configuration**:
- `KAFKA_TOPIC_INPUT`: Topic to consume messages from
- `KAFKA_TOPIC_OUTPUT`: Topic to produce messages to
- `KAFKA_TOPIC_DLQ`: Dead letter queue topic for failed messages

**Consumer Settings** (Internal Services):
- `KAFKA_AUTO_OFFSET_RESET`: "earliest" or "latest"
- `KAFKA_MAX_POLL_RECORDS`: Maximum records per poll
- `KAFKA_SESSION_TIMEOUT`: Session timeout in milliseconds
- `KAFKA_HEARTBEAT_INTERVAL`: Heartbeat interval in milliseconds
- `KAFKA_ENABLE_AUTO_COMMIT`: Enable/disable auto-commit

**Producer Settings**:
- `KAFKA_ACKS`: Acknowledgment level ("all", "1", "0")
- `KAFKA_COMPRESSION_TYPE`: Compression algorithm ("gzip", "snappy", "lz4", "zstd")
- `KAFKA_MAX_IN_FLIGHT`: Maximum in-flight requests
- `KAFKA_LINGER_MS`: Linger time for batching
- `KAFKA_BATCH_SIZE`: Batch size in bytes

#### Secrets Configuration

Kafka credentials are stored in AWS Secrets Manager and injected as environment variables:

```hcl
secrets_arns = [
  {
    name       = "KAFKA_USERNAME"
    value_from = "${var.secrets_arn_prefix}/kafka/username"
  },
  {
    name       = "KAFKA_PASSWORD"
    value_from = "${var.secrets_arn_prefix}/kafka/password"
  },
  {
    name       = "KAFKA_SSL_CA_CERT"
    value_from = "${var.secrets_arn_prefix}/kafka/ssl-ca-cert"
  }
]
```

### Kafka Security Configuration

#### Network Security

1. **Security Groups**: ECS tasks have security group rules allowing outbound traffic to Kafka brokers
2. **Private Subnets**: All ECS tasks run in private subnets with NAT gateway for outbound connectivity
3. **Kafka Security Group**: Must allow inbound traffic from ECS task security groups

#### Authentication

Kafka authentication is configured using SASL/SCRAM or mTLS:

**SASL/SCRAM** (Username/Password):
```bash
# Store in Secrets Manager
aws secretsmanager create-secret \
  --name /ecs-fargate/kafka/username \
  --secret-string "kafka-user"

aws secretsmanager create-secret \
  --name /ecs-fargate/kafka/password \
  --secret-string "secure-password"
```

**mTLS** (Certificate-based):
```bash
# Store certificates in Secrets Manager
aws secretsmanager create-secret \
  --name /ecs-fargate/kafka/ssl-ca-cert \
  --secret-string file://ca-cert.pem

aws secretsmanager create-secret \
  --name /ecs-fargate/kafka/ssl-cert \
  --secret-string file://client-cert.pem

aws secretsmanager create-secret \
  --name /ecs-fargate/kafka/ssl-key \
  --secret-string file://client-key.pem
```

### Kafka Broker Setup Examples

#### AWS MSK (Managed Streaming for Kafka)

```hcl
# Example MSK configuration
kafka_brokers = [
  "b-1.mycluster.abc123.kafka.us-east-1.amazonaws.com:9092",
  "b-2.mycluster.abc123.kafka.us-east-1.amazonaws.com:9092",
  "b-3.mycluster.abc123.kafka.us-east-1.amazonaws.com:9092"
]

kafka_security_group_id = "sg-0123456789abcdef0"
```

#### Confluent Cloud

```hcl
# Example Confluent Cloud configuration
kafka_brokers = [
  "pkc-abc123.us-east-1.aws.confluent.cloud:9092"
]

# Note: Confluent Cloud uses SASL_SSL, configure credentials in Secrets Manager
```

#### Self-Managed Kafka

```hcl
# Example self-managed Kafka configuration
kafka_brokers = [
  "kafka-broker-1.internal.example.com:9092",
  "kafka-broker-2.internal.example.com:9092",
  "kafka-broker-3.internal.example.com:9092"
]

kafka_security_group_id = "sg-kafka-cluster"
```

## How to Use These Examples

### Step 1: Copy Example Configuration

```bash
# Copy the appropriate example for your service
cp -r example-nodejs-public my-service-name
cd my-service-name
```

### Step 2: Customize Configuration

Edit `main.tf` to customize:

1. **Service Identity**:
   ```hcl
   service_name   = "my-service"
   repository_url = "myorg/my-repo"
   ```

2. **Resource Allocation**:
   ```hcl
   cpu            = 512
   memory         = 1024
   desired_count  = 2
   ```

3. **Environment Variables**:
   ```hcl
   environment_variables = {
     # Add your service-specific variables
   }
   ```

4. **Secrets**:
   ```hcl
   secrets_arns = [
     # Add your service-specific secrets
   ]
   ```

5. **Kafka Topics** (if applicable):
   ```hcl
   KAFKA_TOPIC_INPUT  = "my-input-topic"
   KAFKA_TOPIC_OUTPUT = "my-output-topic"
   ```

### Step 3: Create Secrets in AWS Secrets Manager

```bash
# Create secrets for your service
aws secretsmanager create-secret \
  --name /ecs-fargate/my-service/database-url \
  --secret-string "postgresql://user:pass@host:5432/db"

aws secretsmanager create-secret \
  --name /ecs-fargate/my-service/api-key \
  --secret-string "your-api-key"
```

### Step 4: Deploy the Service

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var-file="../environments/${ENVIRONMENT}.tfvars"

# Apply the configuration
terraform apply -var-file="../environments/${ENVIRONMENT}.tfvars"
```

## Environment-Specific Configuration

Each service should be deployed to multiple environments with environment-specific settings:

### Development Environment
- Lower resource limits (256 CPU, 512 MB memory)
- Manual pipeline triggers
- Relaxed security settings
- Debug logging enabled

### Test/QA Environments
- Production-like resources
- Automatic pipeline triggers on release branches
- Standard security settings
- Info logging

### Production Environment
- Higher resource limits (512+ CPU, 1024+ MB memory)
- Manual approval required for deployments
- Strict security settings (MFA, encryption)
- Info/Warning logging only
- 90-day log retention

## Service Communication Patterns

### Public Service → Kafka
```
Internet → ALB → Public Service → Kafka
```

### Internal Service → Kafka
```
Kafka → Internal Service → Kafka
```

### Public Service → Internal Service (via Kafka)
```
Internet → ALB → Public Service → Kafka → Internal Service
```

### Internal Service → Internal Service (via Service Discovery)
```
Internal Service A → Cloud Map → Internal Service B
```

## Best Practices

### Resource Sizing

**Node.js Services**:
- Small: 256 CPU, 512 MB memory
- Medium: 512 CPU, 1024 MB memory
- Large: 1024 CPU, 2048 MB memory

**Python Services**:
- Small: 512 CPU, 1024 MB memory
- Medium: 1024 CPU, 2048 MB memory
- Large: 2048 CPU, 4096 MB memory

### Scaling Configuration

**Public Services** (request-driven):
- Higher desired count (2-3)
- Wider scaling range (2-10)
- Faster scaling response

**Internal Services** (event-driven):
- Lower desired count (1-2)
- Narrower scaling range (1-5)
- Slower scaling response

### Health Checks

**Public Services**:
- ALB health checks every 30 seconds
- 2 consecutive successes = healthy
- 3 consecutive failures = unhealthy

**Internal Services**:
- Container health checks every 30 seconds
- No ALB health checks
- ECS replaces failed tasks automatically

### Kafka Consumer Configuration

**High Throughput**:
```hcl
KAFKA_MAX_POLL_RECORDS = "500"
KAFKA_BATCH_SIZE       = "32768"
KAFKA_LINGER_MS        = "10"
```

**Low Latency**:
```hcl
KAFKA_MAX_POLL_RECORDS = "50"
KAFKA_BATCH_SIZE       = "16384"
KAFKA_LINGER_MS        = "0"
```

**Reliable Processing**:
```hcl
KAFKA_ACKS                = "all"
KAFKA_ENABLE_AUTO_COMMIT  = "false"
KAFKA_MAX_IN_FLIGHT       = "1"
```

## Troubleshooting

### Service Won't Start

1. Check CloudWatch Logs: `/ecs/{service-name}`
2. Verify secrets exist in Secrets Manager
3. Check security group rules allow Kafka access
4. Verify Kafka brokers are reachable

### Kafka Connection Issues

1. Verify `kafka_brokers` endpoints are correct
2. Check security group allows outbound to Kafka ports
3. Verify Kafka credentials in Secrets Manager
4. Check Kafka broker security group allows inbound from ECS

### ALB Health Check Failures (Public Services)

1. Verify health check path returns 200 OK
2. Check container port matches ALB target group port
3. Verify security group allows ALB → ECS traffic
4. Check application logs for errors

### High Memory Usage (Python Services)

1. Increase memory allocation
2. Reduce worker count
3. Implement connection pooling
4. Enable garbage collection tuning

## Additional Resources

- [ECS Fargate Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [AWS MSK Documentation](https://docs.aws.amazon.com/msk/latest/developerguide/what-is-msk.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Support

For questions or issues:
1. Check CloudWatch Logs for error messages
2. Review the design document in `.kiro/specs/ecs-fargate-cicd-infrastructure/design.md`
3. Consult the requirements document in `.kiro/specs/ecs-fargate-cicd-infrastructure/requirements.md`
