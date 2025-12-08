# Terraform variables for test environment
# Production-like configuration for validation

environment  = "test"
aws_region   = "us-east-1"
project_name = "ecs-fargate"

# Network Configuration
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Kafka Configuration (update with actual broker endpoints)
kafka_brokers           = []
kafka_security_group_id = ""

# Security Configuration
allowed_cidr_blocks        = ["0.0.0.0/0"]
enable_deletion_protection = false

# Compliance Tags
mandatory_tags = {
  Owner      = "DevOps Team"
  CostCenter = "Testing"
  Compliance = "SOC-2"
}
