# Networking Module - Main Resources
# Creates VPC infrastructure with public and private subnets for ECS Fargate deployment

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  az_count    = length(var.availability_zones)

  # Calculate subnet CIDR blocks
  # Public subnets use the first half of available /20 blocks
  # Private subnets use the second half
  public_subnet_cidrs = [
    for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i)
  ]
  private_subnet_cidrs = [
    for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i + local.az_count)
  ]

  common_tags = merge(var.tags, {
    Module = "networking"
  })
}

# =============================================================================
# VPC
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# =============================================================================
# Internet Gateway
# =============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# =============================================================================
# Public Subnets
# =============================================================================

resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Type = "public"
  })
}


# =============================================================================
# Private Subnets
# =============================================================================

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    Type = "private"
  })
}

# =============================================================================
# Elastic IPs for NAT Gateways
# =============================================================================

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = var.single_nat_gateway ? "${local.name_prefix}-nat-eip" : "${local.name_prefix}-nat-eip-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# NAT Gateways
# =============================================================================

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = var.single_nat_gateway ? "${local.name_prefix}-nat" : "${local.name_prefix}-nat-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# Public Route Table
# =============================================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
    Type = "public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = local.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# Private Route Tables
# =============================================================================

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 1

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = var.single_nat_gateway || !var.enable_nat_gateway ? "${local.name_prefix}-private-rt" : "${local.name_prefix}-private-rt-${var.availability_zones[count.index]}"
    Type = "private"
  })
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count = local.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.single_nat_gateway || !var.enable_nat_gateway ? 0 : count.index].id
}


# =============================================================================
# VPC Flow Logs
# =============================================================================

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name              = "/aws/vpc/${local.name_prefix}-flow-logs"
  retention_in_days = var.flow_logs_retention_days

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-flow-logs"
  })
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name = "${local.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name = "${local.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  max_aggregation_interval = 60

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-flow-log"
  })
}

# =============================================================================
# Network ACLs (Default - allows all traffic, security groups provide fine-grained control)
# =============================================================================

resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Allow all inbound traffic
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow all outbound traffic
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-nacl"
    Type = "public"
  })
}

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Allow all inbound traffic from VPC
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow return traffic from internet (ephemeral ports)
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound traffic
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-nacl"
    Type = "private"
  })
}


# =============================================================================
# Service Security Groups
# =============================================================================

# Security group for public-facing ECS services (allows traffic from ALB only)
resource "aws_security_group" "public_services" {
  count = var.create_service_security_groups ? 1 : 0

  name        = "${local.name_prefix}-public-services-sg"
  description = "Security group for public-facing ECS services - allows traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-public-services-sg"
    ServiceType = "public"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress rule for public services - allow from ALB security group
resource "aws_security_group_rule" "public_services_from_alb" {
  count = var.create_service_security_groups && var.alb_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  security_group_id        = aws_security_group.public_services[0].id
  description              = "Allow all TCP traffic from ALB"
}

# Egress rule for public services - allow all outbound
resource "aws_security_group_rule" "public_services_egress" {
  count = var.create_service_security_groups ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_services[0].id
  description       = "Allow all outbound traffic"
}

# Security group for internal ECS services (allows traffic from other services and Kafka)
resource "aws_security_group" "internal_services" {
  count = var.create_service_security_groups ? 1 : 0

  name        = "${local.name_prefix}-internal-services-sg"
  description = "Security group for internal ECS services - allows traffic from other services and Kafka"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name        = "${local.name_prefix}-internal-services-sg"
    ServiceType = "internal"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress rule for internal services - allow from public services security group
resource "aws_security_group_rule" "internal_services_from_public" {
  count = var.create_service_security_groups ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.public_services[0].id
  security_group_id        = aws_security_group.internal_services[0].id
  description              = "Allow all TCP traffic from public services"
}

# Ingress rule for internal services - allow from other internal services (self-reference)
resource "aws_security_group_rule" "internal_services_from_internal" {
  count = var.create_service_security_groups ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.internal_services[0].id
  security_group_id        = aws_security_group.internal_services[0].id
  description              = "Allow all TCP traffic from other internal services"
}

# Ingress rule for internal services - allow from Kafka security group (if provided)
resource "aws_security_group_rule" "internal_services_from_kafka" {
  count = var.create_service_security_groups && var.kafka_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = var.kafka_security_group_id
  security_group_id        = aws_security_group.internal_services[0].id
  description              = "Allow all TCP traffic from Kafka cluster"
}

# Ingress rule for internal services - allow from additional CIDR blocks
resource "aws_security_group_rule" "internal_services_from_additional_cidrs" {
  count = var.create_service_security_groups && length(var.additional_internal_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = var.additional_internal_cidr_blocks
  security_group_id = aws_security_group.internal_services[0].id
  description       = "Allow TCP traffic from additional CIDR blocks"
}

# Egress rule for internal services - allow all outbound
resource "aws_security_group_rule" "internal_services_egress" {
  count = var.create_service_security_groups ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.internal_services[0].id
  description       = "Allow all outbound traffic"
}

# =============================================================================
# Kafka Client Security Group
# =============================================================================

# Security group for Kafka client access (allows outbound to Kafka brokers)
resource "aws_security_group" "kafka_client" {
  count = var.create_service_security_groups ? 1 : 0

  name        = "${local.name_prefix}-kafka-client-sg"
  description = "Security group for Kafka client access - allows outbound to Kafka brokers"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name    = "${local.name_prefix}-kafka-client-sg"
    Purpose = "KafkaClient"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Egress rule for Kafka client - allow to Kafka security group (if provided)
resource "aws_security_group_rule" "kafka_client_to_kafka_sg" {
  count = var.create_service_security_groups && var.kafka_security_group_id != "" ? 1 : 0

  type                     = "egress"
  from_port                = 9092
  to_port                  = 9096
  protocol                 = "tcp"
  source_security_group_id = var.kafka_security_group_id
  security_group_id        = aws_security_group.kafka_client[0].id
  description              = "Allow Kafka protocol traffic to Kafka cluster (ports 9092-9096)"
}

# Egress rule for Kafka client - allow to Kafka broker CIDR blocks (parsed from endpoints)
resource "aws_security_group_rule" "kafka_client_to_kafka_cidrs" {
  count = var.create_service_security_groups && length(var.kafka_broker_endpoints) > 0 && var.kafka_security_group_id == "" ? 1 : 0

  type              = "egress"
  from_port         = 9092
  to_port           = 9096
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Will be restricted by NACL or external firewall
  security_group_id = aws_security_group.kafka_client[0].id
  description       = "Allow Kafka protocol traffic to Kafka brokers (ports 9092-9096)"
}

# Egress rule for Kafka client - allow HTTPS for schema registry and other Kafka services
resource "aws_security_group_rule" "kafka_client_https" {
  count = var.create_service_security_groups ? 1 : 0

  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.kafka_client[0].id
  description       = "Allow HTTPS traffic for schema registry and Kafka management"
}

# =============================================================================
# Cross-reference rules for public services to access Kafka
# =============================================================================

# Allow public services to use Kafka client security group rules
resource "aws_security_group_rule" "public_services_to_kafka" {
  count = var.create_service_security_groups && var.kafka_security_group_id != "" ? 1 : 0

  type                     = "egress"
  from_port                = 9092
  to_port                  = 9096
  protocol                 = "tcp"
  source_security_group_id = var.kafka_security_group_id
  security_group_id        = aws_security_group.public_services[0].id
  description              = "Allow Kafka protocol traffic to Kafka cluster"
}

# Allow internal services to access Kafka
resource "aws_security_group_rule" "internal_services_to_kafka" {
  count = var.create_service_security_groups && var.kafka_security_group_id != "" ? 1 : 0

  type                     = "egress"
  from_port                = 9092
  to_port                  = 9096
  protocol                 = "tcp"
  source_security_group_id = var.kafka_security_group_id
  security_group_id        = aws_security_group.internal_services[0].id
  description              = "Allow Kafka protocol traffic to Kafka cluster"
}


# =============================================================================
# VPC Peering Connections (for cross-environment communication)
# Requirements: 10.4
# =============================================================================

# VPC Peering Connection Requester
resource "aws_vpc_peering_connection" "peer" {
  count = var.enable_vpc_peering ? length(var.vpc_peering_connections) : 0

  vpc_id        = aws_vpc.main.id
  peer_vpc_id   = var.vpc_peering_connections[count.index].peer_vpc_id
  peer_owner_id = var.vpc_peering_connections[count.index].peer_owner_id
  peer_region   = var.vpc_peering_connections[count.index].peer_region
  auto_accept   = var.vpc_peering_connections[count.index].peer_owner_id == null && var.vpc_peering_connections[count.index].peer_region == null

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-peering-${var.vpc_peering_connections[count.index].name}"
    Side = "Requester"
  })
}

# VPC Peering Connection Options (for same-account, same-region peering)
resource "aws_vpc_peering_connection_options" "peer" {
  count = var.enable_vpc_peering ? length([
    for conn in var.vpc_peering_connections : conn
    if conn.peer_owner_id == null && conn.peer_region == null
  ]) : 0

  vpc_peering_connection_id = aws_vpc_peering_connection.peer[count.index].id

  requester {
    allow_remote_vpc_dns_resolution = var.vpc_peering_connections[count.index].allow_remote_dns
  }

  accepter {
    allow_remote_vpc_dns_resolution = var.vpc_peering_connections[count.index].allow_remote_dns
  }

  depends_on = [aws_vpc_peering_connection.peer]
}

# Route to peer VPC from public subnets
resource "aws_route" "public_to_peer" {
  count = var.enable_vpc_peering ? length(var.vpc_peering_connections) : 0

  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = var.vpc_peering_connections[count.index].peer_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer[count.index].id
}

# Route to peer VPC from private subnets
resource "aws_route" "private_to_peer" {
  count = var.enable_vpc_peering ? length(var.vpc_peering_connections) * length(aws_route_table.private) : 0

  route_table_id            = aws_route_table.private[count.index % length(aws_route_table.private)].id
  destination_cidr_block    = var.vpc_peering_connections[floor(count.index / length(aws_route_table.private))].peer_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer[floor(count.index / length(aws_route_table.private))].id
}

# =============================================================================
# Production VPC Isolation Validation
# Requirements: 10.4
# =============================================================================

# This resource validates that production VPCs use the expected CIDR range
# and non-production VPCs use different CIDR ranges
resource "null_resource" "vpc_isolation_validation" {
  count = var.is_production ? 1 : 0

  # Trigger validation on VPC CIDR changes
  triggers = {
    vpc_cidr      = var.vpc_cidr
    is_production = var.is_production
  }

  # Validation is performed via Terraform's lifecycle
  lifecycle {
    precondition {
      condition     = startswith(var.vpc_cidr, var.production_vpc_cidr_prefix)
      error_message = "Production VPC CIDR must start with ${var.production_vpc_cidr_prefix} for proper isolation. Current CIDR: ${var.vpc_cidr}"
    }
  }
}

# Validation for non-production environments
resource "null_resource" "non_production_vpc_validation" {
  count = !var.is_production ? 1 : 0

  triggers = {
    vpc_cidr      = var.vpc_cidr
    is_production = var.is_production
  }

  lifecycle {
    precondition {
      condition     = !startswith(var.vpc_cidr, var.production_vpc_cidr_prefix)
      error_message = "Non-production VPC CIDR must NOT start with ${var.production_vpc_cidr_prefix} to maintain isolation from production. Current CIDR: ${var.vpc_cidr}"
    }
  }
}
