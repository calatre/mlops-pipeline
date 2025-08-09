# Perennial ECR Stack

This directory contains a small, standalone Terraform stack that creates and manages the long-lived ECR repository used by the mlops-pipeline. It is intentionally separated from the ephemeral ./infra stack so frequent deploy/destroy cycles do not delete ECR or its cached images.

What this protects and what it does not
- Protected: ECR repository and images (lifecycle policy applies for pruning)
- Not applicable: VPC or security groups — ECR is a regional AWS service with no VPC attachment, so your VPC/SGs in ./infra can still be destroyed independently.

Backend/state
- Uses the same S3/DynamoDB backend with a different key: perennial/ecr.tfstate

Usage
1) One-time setup
   terraform -chdir=infra-perennial/ecr init
   terraform -chdir=infra-perennial/ecr apply -auto-approve

2) Regular ./infra deployments now read the ECR outputs via terraform_remote_state and use the repository URL for Lambda image deployments. You can destroy ./infra freely without affecting ECR.

3) If you ever need to retire the repository:
   - Optional: temporarily remove prevent_destroy and set force_delete as needed
   - terraform -chdir=infra-perennial/ecr destroy

Outputs exposed
- lambda_repository_url
- all_repository_urls
- all_repository_names

CI behavior and importing into Terraform state
- The GitHub Actions pipeline will auto-create the ECR repository if it does not exist yet to ensure first runs succeed for new contributors.
- If CI created the repository and you want Terraform to take ownership, run:
  1) Initialize this stack: make ecr-init
  2) Import the repo into state (replace <env> if not dev):
     terraform -chdir=infra-perennial/ecr import aws_ecr_repository.lambda_function mlops-taxi-prediction-lambda-app-dev
  3) Apply to reconcile any drift: make ecr-apply
- After import, future CI runs will find the repository already present and managed by Terraform.

