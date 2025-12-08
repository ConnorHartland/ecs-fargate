# Terraform variables for production environment
# Full security controls, higher resource limits, stricter access controls

environment  = "prod"
aws_region   = "us-east-1"
project_name = "ecs-fargate"

# Network Configuration - Separate CIDR for production isolation
vpc_cidr           = "10.100.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Kafka Configuration (update with actual broker endpoints)
kafka_brokers           = []
kafka_security_group_id = ""

# Security Configuration
allowed_cidr_blocks        = ["0.0.0.0/0"]
enable_deletion_protection = true

# Compliance Tags
mandatory_tags = {
  Owner      = "Platform Team"
  CostCenter = "Production"
  Compliance = "NIST-SOC2"
}
