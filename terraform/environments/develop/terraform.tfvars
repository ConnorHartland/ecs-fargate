# Terraform variables for develop environment
# Lower resource limits, relaxed security for development

environment  = "develop"
aws_region   = "us-east-1"
project_name = "ecs-fargate"

# Network Configuration
vpc_cidr           = "10.0.0.0/16"
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
  CostCenter = "Development"
  Compliance = "Internal"
}
