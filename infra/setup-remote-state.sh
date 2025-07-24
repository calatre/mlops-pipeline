#!/bin/bash

# Script to set up Terraform remote state backend
# This script creates the S3 bucket and DynamoDB table needed for remote state management

set -e

echo "🚀 Setting up Terraform remote state backend..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "❌ Error: AWS CLI is not configured or credentials are invalid"
    echo "Please run 'aws configure' first"
    exit 1
fi

echo "✅ AWS credentials verified"

# Navigate to bootstrap directory
cd bootstrap

echo "📦 Initializing bootstrap Terraform configuration..."
terraform init

echo "📋 Planning bootstrap deployment..."
terraform plan

echo "🏗️  Deploying S3 bucket and DynamoDB table for remote state..."
terraform apply -auto-approve

echo "✅ Bootstrap resources created successfully!"

# Navigate back to main infra directory
cd ..

echo "🔄 Migrating existing state to remote backend..."

# Initialize with the new backend configuration
terraform init -migrate-state

echo "✅ State migration completed!"

echo "🧹 Cleaning up local state files..."
# Remove local state files (they're now in S3)
rm -f terraform.tfstate terraform.tfstate.backup

echo "✅ Remote state backend setup completed successfully!"
echo ""
echo "📝 Summary:"
echo "  - S3 Bucket: mlops-taxi-prediction-terraform-state"
echo "  - DynamoDB Table: terraform-state-lock"
echo "  - Region: eu-north-1"
echo ""
echo "🎉 You can now run 'terraform plan' and 'terraform apply' with remote state!"
