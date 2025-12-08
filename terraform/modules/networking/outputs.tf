# Networking Module Outputs
# Exposes VPC and subnet information for use by other modules

# =============================================================================
# VPC Outputs
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

# =============================================================================
# Subnet Outputs
# =============================================================================

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

# =============================================================================
# Gateway Outputs
# =============================================================================

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IP addresses"
  value       = aws_eip.nat[*].public_ip
}

# =============================================================================
# Route Table Outputs
# =============================================================================

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

# =============================================================================
# VPC Flow Logs Outputs
# =============================================================================

output "flow_log_id" {
  description = "ID of the VPC Flow Log"
  value       = var.enable_vpc_flow_logs ? aws_flow_log.main[0].id : null
}

output "flow_log_cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for VPC Flow Logs"
  value       = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].arn : null
}

output "flow_log_iam_role_arn" {
  description = "ARN of the IAM role for VPC Flow Logs"
  value       = var.enable_vpc_flow_logs ? aws_iam_role.flow_logs[0].arn : null
}

# =============================================================================
# Network ACL Outputs
# =============================================================================

output "public_network_acl_id" {
  description = "ID of the public Network ACL"
  value       = aws_network_acl.public.id
}

output "private_network_acl_id" {
  description = "ID of the private Network ACL"
  value       = aws_network_acl.private.id
}


# =============================================================================
# Service Security Group Outputs
# =============================================================================

output "public_services_security_group_id" {
  description = "ID of the security group for public-facing ECS services"
  value       = var.create_service_security_groups ? aws_security_group.public_services[0].id : null
}

output "public_services_security_group_arn" {
  description = "ARN of the security group for public-facing ECS services"
  value       = var.create_service_security_groups ? aws_security_group.public_services[0].arn : null
}

output "public_services_security_group_name" {
  description = "Name of the security group for public-facing ECS services"
  value       = var.create_service_security_groups ? aws_security_group.public_services[0].name : null
}

output "internal_services_security_group_id" {
  description = "ID of the security group for internal ECS services"
  value       = var.create_service_security_groups ? aws_security_group.internal_services[0].id : null
}

output "internal_services_security_group_arn" {
  description = "ARN of the security group for internal ECS services"
  value       = var.create_service_security_groups ? aws_security_group.internal_services[0].arn : null
}

output "internal_services_security_group_name" {
  description = "Name of the security group for internal ECS services"
  value       = var.create_service_security_groups ? aws_security_group.internal_services[0].name : null
}

output "kafka_client_security_group_id" {
  description = "ID of the security group for Kafka client access"
  value       = var.create_service_security_groups ? aws_security_group.kafka_client[0].id : null
}

output "kafka_client_security_group_arn" {
  description = "ARN of the security group for Kafka client access"
  value       = var.create_service_security_groups ? aws_security_group.kafka_client[0].arn : null
}

output "kafka_client_security_group_name" {
  description = "Name of the security group for Kafka client access"
  value       = var.create_service_security_groups ? aws_security_group.kafka_client[0].name : null
}


# =============================================================================
# VPC Peering Outputs
# =============================================================================

output "vpc_peering_connection_ids" {
  description = "List of VPC peering connection IDs"
  value       = var.enable_vpc_peering ? aws_vpc_peering_connection.peer[*].id : []
}

output "vpc_peering_connection_statuses" {
  description = "Map of VPC peering connection names to their status"
  value = var.enable_vpc_peering ? {
    for idx, conn in var.vpc_peering_connections :
    conn.name => aws_vpc_peering_connection.peer[idx].accept_status
  } : {}
}

# =============================================================================
# VPC Isolation Outputs
# =============================================================================

output "is_production_vpc" {
  description = "Whether this VPC is configured as a production VPC"
  value       = var.is_production
}

output "vpc_isolation_validated" {
  description = "Whether VPC isolation validation passed"
  value       = var.is_production ? startswith(var.vpc_cidr, var.production_vpc_cidr_prefix) : !startswith(var.vpc_cidr, var.production_vpc_cidr_prefix)
}
