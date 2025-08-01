# ECR Module Outputs

# Airflow Repository Outputs
#output "airflow_repository_url" {
#  description = "URL of the Airflow ECR repository"
#  value       = aws_ecr_repository.airflow_app.repository_url
#}
#
#output "airflow_repository_arn" {
#  description = "ARN of the Airflow ECR repository"
#  value       = aws_ecr_repository.airflow_app.arn
#}
#
#output "airflow_repository_name" {
#  description = "Name of the Airflow ECR repository"
#  value       = aws_ecr_repository.airflow_app.name
#}
#
## MLflow Repository Outputs
#output "mlflow_repository_url" {
#  description = "URL of the MLflow ECR repository"
#  value       = aws_ecr_repository.mlflow_app.repository_url
#}
#
#output "mlflow_repository_arn" {
#  description = "ARN of the MLflow ECR repository"
#  value       = aws_ecr_repository.mlflow_app.arn
#}
#
#output "mlflow_repository_name" {
#  description = "Name of the MLflow ECR repository"
#  value       = aws_ecr_repository.mlflow_app.name
#}

# Lambda Repository Outputs
output "lambda_repository_url" {
  description = "URL of the Lambda ECR repository"
  value       = aws_ecr_repository.lambda_function.repository_url
}

output "lambda_repository_arn" {
  description = "ARN of the Lambda ECR repository"
  value       = aws_ecr_repository.lambda_function.arn
}

output "lambda_repository_name" {
  description = "Name of the Lambda ECR repository"
  value       = aws_ecr_repository.lambda_function.name
}

# Registry Information
#output "registry_id" {
#  description = "AWS account ID (registry ID)"
#  value       = aws_ecr_repository.airflow_app.registry_id
#}

# All Repository URLs for CI/CD
output "all_repository_urls" {
  description = "Map of all ECR repository URLs"
  value = {
    #airflow = aws_ecr_repository.airflow_app.repository_url
    #mlflow  = aws_ecr_repository.mlflow_app.repository_url
    lambda = aws_ecr_repository.lambda_function.repository_url
  }
}

# All Repository Names for CI/CD
output "all_repository_names" {
  description = "Map of all ECR repository names"
  value = {
    #airflow = aws_ecr_repository.airflow_app.name
    #mlflow  = aws_ecr_repository.mlflow_app.name
    lambda = aws_ecr_repository.lambda_function.name
  }
}
