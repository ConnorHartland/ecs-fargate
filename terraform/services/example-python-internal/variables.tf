# Variables for Python Internal Service Example

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "project_name" {
  type        = string
  description = "Project name"
}

variable "aws_account_id" {
  type        = string
  description = "AWS account ID"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "cluster_arn" {
  type        = string
  description = "ECS cluster ARN"
}

variable "cluster_name" {
  type        = string
  description = "ECS cluster name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs"
}

variable "service_discovery_namespace_id" {
  type        = string
  description = "AWS Cloud Map namespace ID for service discovery"
}

variable "task_execution_role_arn" {
  type        = string
  description = "Task execution role ARN"
}

variable "codebuild_role_arn" {
  type        = string
  description = "CodeBuild role ARN"
}

variable "codepipeline_role_arn" {
  type        = string
  description = "CodePipeline role ARN"
}

variable "kms_key_arn" {
  type        = string
  description = "General KMS key ARN"
}

variable "kms_key_ecr_arn" {
  type        = string
  description = "ECR KMS key ARN"
}

variable "kms_key_cloudwatch_arn" {
  type        = string
  description = "CloudWatch KMS key ARN"
}

variable "kms_key_secrets_arn" {
  type        = string
  description = "Secrets Manager KMS key ARN"
}

variable "kms_key_s3_arn" {
  type        = string
  description = "S3 KMS key ARN"
}

variable "codeconnections_arn" {
  type        = string
  description = "CodeConnections ARN for Bitbucket"
}

variable "notification_sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for notifications"
}

variable "approval_sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for approvals"
}

variable "secrets_arn_prefix" {
  type        = string
  description = "Prefix for Secrets Manager ARNs"
}

variable "kafka_brokers" {
  type        = list(string)
  description = "Kafka broker endpoints"
}

variable "kafka_security_group_id" {
  type        = string
  description = "Kafka security group ID"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags"
  default     = {}
}
