# Makefile for mlops-pipeline
# Simple helpers for perennial ECR and Docker login

AWS_REGION ?= eu-north-1
ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2\u003e/dev/null)
ECR_STATE_DIR := infra-perennial/ecr

.PHONY: ecr-init ecr-apply ecr-destroy ecr-login ecr-outputs lambda-build lambda-build-no-push

# Initialize Terraform in the perennial ECR stack
ecr-init:
	terraform -chdir=$(ECR_STATE_DIR) init

# Apply the perennial ECR stack (creates/updates repo)
ecr-apply:
	terraform -chdir=$(ECR_STATE_DIR) apply -auto-approve

# Destroy the perennial ECR stack (requires removing prevent_destroy first)
ecr-destroy:
	terraform -chdir=$(ECR_STATE_DIR) destroy -auto-approve

# Login Docker to ECR for the configured region
# Requires AWS CLI to be authenticated (e.g., via env vars or a profile)
ecr-login:
	@if [ -z "$(ACCOUNT_ID)" ]; then echo "ERROR: ACCOUNT_ID not resolved. Run: aws configure (or export AWS creds)"; exit 1; fi
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

# Show ECR outputs from perennial state (useful for CI wiring)
ecr-outputs:
	terraform -chdir=$(ECR_STATE_DIR) output -json

# Build and push Lambda image using existing script (respects AWS_REGION and ENVIRONMENT)
lambda-build: ecr-login
	AWS_REGION=$(AWS_REGION) ENVIRONMENT=$(ENVIRONMENT) bash scripts/build_lambda.sh

# Build only, do not push to ECR
lambda-build-no-push:
	AWS_REGION=$(AWS_REGION) ENVIRONMENT=$(ENVIRONMENT) bash scripts/build_lambda.sh --no-push

