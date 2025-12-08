# Variables for service-2
# These are passed from the root module or environment-specific tfvars

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
  description = "AWS Account ID"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "cluster_arn" {
  type        = string
  description = "ECS Cluster ARN"
}

variable "cluster_name" {
  type        = string
  description = "ECS Cluster Name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs"
}

variable "alb_listener_arn" {
  type        = string
  description = "ALB HTTPS Listener ARN"
}

variable "alb_security_group_id" {
  type        = string
  description = "ALB Security Group ID"
}

variable "task_execution_role_arn" {
  type        = string
  description = "ECS Task Execution Role ARN"
}

variable "codebuild_role_arn" {
  type        = string
  description = "CodeBuild Role ARN"
}

variable "codepipeline_role_arn" {
  type        = string
  description = "CodePipeline Role ARN"
}

variable "kms_key_arn" {
  type        = string
  description = "KMS Key ARN for general encryption"
}

variable "kms_key_ecr_arn" {
  type        = string
  description = "KMS Key ARN for ECR"
}

variable "kms_key_cloudwatch_arn" {
  type        = string
  description = "KMS Key ARN for CloudWatch"
}

variable "kms_key_secrets_arn" {
  type        = string
  description = "KMS Key ARN for Secrets Manager"
}

variable "kms_key_s3_arn" {
  type        = string
  description = "KMS Key ARN for S3"
}

variable "codeconnections_arn" {
  type        = string
  description = "CodeConnections ARN for Bitbucket"
}

variable "notification_sns_topic_arn" {
  type        = string
  description = "SNS Topic ARN for notifications"
}

variable "approval_sns_topic_arn" {
  type        = string
  description = "SNS Topic ARN for approvals"
}

variable "kafka_brokers" {
  type        = list(string)
  description = "Kafka broker endpoints"
  default     = []
}

variable "kafka_security_group_id" {
  type        = string
  description = "Kafka security group ID"
  default     = ""
}

variable "secrets_arn_prefix" {
  type        = string
  description = "Prefix for Secrets Manager ARNs"
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default     = {}
}
