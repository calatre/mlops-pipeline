terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "mlops-taxi-prediction-terraform-state"
    key            = "perennial/ecr.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

# Minimal long-lived ECR repository for Lambda container images
resource "aws_ecr_repository" "lambda_function" {
  name                 = "${var.project_name}-lambda-app-${var.environment}"
  image_tag_mutability = "MUTABLE"

  # Safety: protect against accidental destroy; you can remove to retire the repo
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-lambda-app-${var.environment}"
  })
}

# Keep a bounded number of images to preserve build cache without growing cost
resource "aws_ecr_lifecycle_policy" "lambda_function" {
  repository = aws_ecr_repository.lambda_function.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last ${var.max_image_count} images",
        selection = {
          tagStatus   = "any",
          countType   = "imageCountMoreThan",
          countNumber = var.max_image_count
        },
        action = { type = "expire" }
      }
    ]
  })
}

output "lambda_repository_url" {
  description = "URL of the Lambda ECR repository"
  value       = aws_ecr_repository.lambda_function.repository_url
}

output "lambda_repository_name" {
  description = "Name of the Lambda ECR repository"
  value       = aws_ecr_repository.lambda_function.name
}

output "lambda_repository_arn" {
  description = "ARN of the Lambda ECR repository"
  value       = aws_ecr_repository.lambda_function.arn
}

output "all_repository_urls" {
  description = "Map of all ECR repository URLs"
  value = {
    lambda = aws_ecr_repository.lambda_function.repository_url
  }
}

output "all_repository_names" {
  description = "Map of all ECR repository names"
  value = {
    lambda = aws_ecr_repository.lambda_function.name
  }
}

