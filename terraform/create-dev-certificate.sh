#!/bin/bash
# Create a self-signed certificate in ACM for development
# This is NOT for production use

set -e

DOMAIN=${1:-"dev.example.com"}
REGION=${2:-"us-east-1"}

echo "=========================================="
echo "Creating self-signed certificate for: $DOMAIN"
echo "Region: $REGION"
echo "=========================================="

# Create private key
openssl genrsa 2048 > private-key.pem

# Create certificate signing request
openssl req -new -key private-key.pem -out csr.pem -subj "/CN=$DOMAIN"

# Create self-signed certificate
openssl x509 -req -days 365 -in csr.pem -signkey private-key.pem -out certificate.pem

# Import to ACM
CERT_ARN=$(aws acm import-certificate \
  --certificate fileb://certificate.pem \
  --private-key fileb://private-key.pem \
  --region $REGION \
  --query 'CertificateArn' \
  --output text)

echo ""
echo "✓ Certificate created successfully!"
echo ""
echo "Certificate ARN: $CERT_ARN"
echo ""
echo "Add this to your terraform.tfvars:"
echo "certificate_arn = \"$CERT_ARN\""
echo ""

# Cleanup
rm -f private-key.pem csr.pem certificate.pem

echo "Temporary files cleaned up."
