# ECR Module - Container Registries for MLOps Pipeline
# Creates ECR repositories for Airflow, MLflow, and Lambda function images


# Lambda Function Repository
resource "aws_ecr_repository" "lambda_function" {
  name                 = "${var.project_name}-lambda-app-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = var.enable_image_scanning
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-lambda-app-${var.environment}"
    Service   = "lambda"
    Component = "ml-inference"
  })
}


# Lifecycle Policy for Lambda Repository
resource "aws_ecr_lifecycle_policy" "lambda_function" {
  repository = aws_ecr_repository.lambda_function.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.max_image_count} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than ${var.untagged_expiry_days} day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_expiry_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}


resource "aws_ecr_repository_policy" "lambda_function" {
  count      = var.enable_cross_account_access ? 1 : 0
  repository = aws_ecr_repository.lambda_function.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.cross_account_arns
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
