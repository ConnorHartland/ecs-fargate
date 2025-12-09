# Service 1

Public-facing Node.js service exposed via ALB.

## Configuration

This service uses `terraform_remote_state` to pull infrastructure values from the root module.

### Before Deploying

1. **Update `provider.tf`**:
   - Set your AWS region
   - Set your S3 backend bucket name
   - Add your CodeConnections ARN
   - Add Kafka brokers if needed

2. **Update `main.tf`**:
   - Change `repository_url` to your Bitbucket repo

3. **Create secrets in AWS Secrets Manager**:
   ```bash
   aws secretsmanager create-secret \
     --name develop/service-1/database-url \
     --secret-string "postgresql://user:pass@host:5432/db"
   
   aws secretsmanager create-secret \
     --name develop/service-1/api-key \
     --secret-string "your-api-key"
   ```

## Deploy

```bash
# Initialize (first time or after backend changes)
terraform init -backend-config=backend-develop.hcl -reconfigure

# Plan and apply
terraform plan
terraform apply
```

## Access

- **Path**: `/service1/*`
- **Health Check**: `/health`
- **Port**: 3000
