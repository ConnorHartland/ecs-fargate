# ALB Module - Outputs
# Exposes ALB resources for use by other modules

# =============================================================================
# ALB Outputs
# =============================================================================

output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer (for CloudWatch metrics)"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer (for Route53)"
  value       = aws_lb.main.zone_id
}

output "alb_name" {
  description = "Name of the Application Load Balancer"
  value       = aws_lb.main.name
}

# =============================================================================
# Listener Outputs
# =============================================================================

output "https_listener_arn" {
  description = "ARN of the HTTPS listener (null if certificate not provided)"
  value       = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : null
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

# =============================================================================
# Security Group Outputs
# =============================================================================

output "security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "security_group_arn" {
  description = "ARN of the ALB security group"
  value       = aws_security_group.alb.arn
}

output "security_group_name" {
  description = "Name of the ALB security group"
  value       = aws_security_group.alb.name
}

# =============================================================================
# Access Logs Bucket Outputs
# =============================================================================

output "access_logs_bucket_id" {
  description = "ID of the S3 bucket for ALB access logs"
  value       = var.enable_access_logs ? aws_s3_bucket.access_logs[0].id : null
}

output "access_logs_bucket_arn" {
  description = "ARN of the S3 bucket for ALB access logs"
  value       = var.enable_access_logs ? aws_s3_bucket.access_logs[0].arn : null
}

output "access_logs_bucket_domain_name" {
  description = "Domain name of the S3 bucket for ALB access logs"
  value       = var.enable_access_logs ? aws_s3_bucket.access_logs[0].bucket_domain_name : null
}

# =============================================================================
# Convenience Outputs
# =============================================================================

output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = var.certificate_arn != "" ? "https://${aws_lb.main.dns_name}" : "http://${aws_lb.main.dns_name}"
}

output "deletion_protection_enabled" {
  description = "Whether deletion protection is enabled"
  value       = aws_lb.main.enable_deletion_protection
}

output "ssl_policy" {
  description = "SSL policy used by the HTTPS listener (null if HTTPS not enabled)"
  value       = var.certificate_arn != "" ? aws_lb_listener.https[0].ssl_policy : null
}

# =============================================================================
# Target Group Outputs
# =============================================================================

output "target_group_arns" {
  description = "Map of target group ARNs by service name"
  value       = { for k, v in aws_lb_target_group.services : k => v.arn }
}

output "target_group_arn_suffixes" {
  description = "Map of target group ARN suffixes by service name (for CloudWatch metrics)"
  value       = { for k, v in aws_lb_target_group.services : k => v.arn_suffix }
}

output "target_group_names" {
  description = "Map of target group names by service name"
  value       = { for k, v in aws_lb_target_group.services : k => v.name }
}

output "target_group_ids" {
  description = "Map of target group IDs by service name"
  value       = { for k, v in aws_lb_target_group.services : k => v.id }
}

# =============================================================================
# Listener Rule Outputs
# =============================================================================

output "listener_rule_arns" {
  description = "Map of listener rule ARNs by service name"
  value       = { for k, v in aws_lb_listener_rule.services : k => v.arn }
}
