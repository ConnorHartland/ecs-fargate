# ECR Module Outputs
# Exposes repository information for use by other modules

output "repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.this.name
}

output "repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_registry_id" {
  description = "Registry ID where the repository was created"
  value       = aws_ecr_repository.this.registry_id
}

output "image_tag_mutability" {
  description = "Image tag mutability setting"
  value       = aws_ecr_repository.this.image_tag_mutability
}

output "scan_on_push" {
  description = "Whether image scanning on push is enabled"
  value       = aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push
}

output "encryption_type" {
  description = "Encryption type for the repository"
  value       = aws_ecr_repository.this.encryption_configuration[0].encryption_type
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = aws_ecr_repository.this.encryption_configuration[0].kms_key
}
