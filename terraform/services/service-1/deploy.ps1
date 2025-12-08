# PowerShell script to deploy service-1
# Run this from the service-1 directory

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deploying service-1 to develop environment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Initialize Terraform
Write-Host "Step 1: Initializing Terraform..." -ForegroundColor Yellow
terraform init -backend-config=backend-develop.hcl -reconfigure

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform init failed!" -ForegroundColor Red
    exit 1
}

# Step 2: Plan the deployment
Write-Host ""
Write-Host "Step 2: Planning deployment..." -ForegroundColor Yellow
terraform plan -out=tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform plan failed!" -ForegroundColor Red
    exit 1
}

# Step 3: Apply to create ECR repository and all resources
Write-Host ""
Write-Host "Step 3: Applying configuration..." -ForegroundColor Yellow
terraform apply tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Terraform apply failed!" -ForegroundColor Red
    exit 1
}

# Step 4: Get ECR repository URL
Write-Host ""
Write-Host "Step 4: Getting ECR repository details..." -ForegroundColor Yellow
$ECR_REPO = terraform output -raw ecr_repository_url 2>$null

if ($ECR_REPO) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "✓ Deployment successful!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "ECR Repository: $ECR_REPO" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Build and push your Docker image:" -ForegroundColor White
    Write-Host "   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPO" -ForegroundColor Gray
    Write-Host "   docker build -t service-1 ." -ForegroundColor Gray
    Write-Host "   docker tag service-1:latest ${ECR_REPO}:latest" -ForegroundColor Gray
    Write-Host "   docker push ${ECR_REPO}:latest" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Trigger the pipeline:" -ForegroundColor White
    Write-Host "   aws codepipeline start-pipeline-execution --name service-1-develop" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "⚠ Warning: Could not retrieve ECR repository URL" -ForegroundColor Yellow
    Write-Host "Check terraform outputs manually with: terraform output" -ForegroundColor Yellow
}
