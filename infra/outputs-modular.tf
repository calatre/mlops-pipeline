# Outputs for Modular MLOps Taxi Prediction Infrastructure

# S3 Bucket Outputs
output "mlflow_artifacts_bucket" {
  description = "Name of the S3 bucket for MLflow artifacts"
  value       = aws_s3_bucket.mlflow_artifacts.bucket
}

output "data_storage_bucket" {
  description = "Name of the S3 bucket for data storage"
  value       = aws_s3_bucket.data_storage.bucket
}

output "monitoring_reports_bucket" {
  description = "Name of the S3 bucket for monitoring reports"
  value       = aws_s3_bucket.monitoring_reports.bucket
}

# Kinesis Outputs
output "kinesis_stream_name" {
  description = "Name of the Kinesis stream"
  value       = aws_kinesis_stream.taxi_predictions.name
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis stream"
  value       = aws_kinesis_stream.taxi_predictions.arn
}

# Lambda Outputs
output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.taxi_prediction.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.taxi_prediction.arn
}

output "lambda_image_uri" {
  description = "Container image URI used by the Lambda function"
  value       = aws_lambda_function.taxi_prediction.image_uri
}

# VPC Module Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

# Security Group Outputs
output "main_security_group_id" {
  description = "ID of the main security group"
  value       = aws_security_group.main.id
}

output "main_security_group_name" {
  description = "Name of the main security group"
  value       = aws_security_group.main.name
}

# MLOps Orchestration EC2 Instance Outputs
output "mlops_orchestration_instance_id" {
  description = "ID of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.id
}

output "mlops_orchestration_public_ip" {
  description = "Public IP of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.public_ip
}

output "mlops_orchestration_public_dns" {
  description = "Public DNS of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.public_dns
}

output "mlops_orchestration_private_ip" {
  description = "Private IP of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.private_ip
}

output "mlops_orchestration_private_dns" {
  description = "Private DNS of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.private_dns
}

output "mlops_orchestration_arn" {
  description = "ARN of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.arn
}

output "mlops_orchestration_instance_type" {
  description = "Instance type of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.instance_type
}

output "mlops_orchestration_availability_zone" {
  description = "Availability zone of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.availability_zone
}

output "mlops_orchestration_subnet_id" {
  description = "Subnet ID of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.subnet_id
}

output "mlops_orchestration_vpc_security_group_ids" {
  description = "Security group IDs of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.vpc_security_group_ids
}

output "mlops_orchestration_iam_instance_profile" {
  description = "IAM instance profile of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.iam_instance_profile
}

output "mlops_orchestration_key_name" {
  description = "Key pair name of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.key_name
}

output "mlops_orchestration_root_block_device" {
  description = "Root block device configuration of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.root_block_device
}

output "mlops_orchestration_tags" {
  description = "Tags of the MLOps Orchestration EC2 instance"
  value       = aws_instance.mlops_orchestration.tags
}

output "mlops_orchestration_summary" {
  description = "Summary of the MLOps Orchestration EC2 instance"
  value = {
    instance_id       = aws_instance.mlops_orchestration.id
    instance_type     = aws_instance.mlops_orchestration.instance_type
    public_ip         = aws_instance.mlops_orchestration.public_ip
    public_dns        = aws_instance.mlops_orchestration.public_dns
    private_ip        = aws_instance.mlops_orchestration.private_ip
    private_dns       = aws_instance.mlops_orchestration.private_dns
    availability_zone = aws_instance.mlops_orchestration.availability_zone
    subnet_id         = aws_instance.mlops_orchestration.subnet_id
    security_group    = aws_instance.mlops_orchestration.vpc_security_group_ids
    iam_profile       = aws_instance.mlops_orchestration.iam_instance_profile
    key_name          = aws_instance.mlops_orchestration.key_name
    state             = aws_instance.mlops_orchestration.instance_state
  }
}

output "mlops_orchestration_airflow_url" {
  description = "URL to access Airflow on the orchestration instance"
  value       = "http://${aws_instance.mlops_orchestration.public_ip}:8080"
}

output "mlops_orchestration_mlflow_url" {
  description = "URL to access MLflow on the orchestration instance"
  value       = "http://${aws_instance.mlops_orchestration.public_ip}:5000"
}

output "mlops_orchestration_status_url" {
  description = "URL to access the status page on the orchestration instance"
  value       = "http://${aws_instance.mlops_orchestration.public_ip}:8081"
}


# ECR Repository Outputs for CI/CD

output "ecr_lambda_repository_url" {
  description = "URL of the Lambda ECR repository"
  value       = data.terraform_remote_state.ecr.outputs.lambda_repository_url
}

output "ecr_repository_names" {
  description = "Map of all ECR repository names"
  value       = data.terraform_remote_state.ecr.outputs.all_repository_names
}

output "ecr_repository_urls" {
  description = "Map of all ECR repository URLs"
  value       = data.terraform_remote_state.ecr.outputs.all_repository_urls
}

# Infrastructure Summary
output "infrastructure_summary" {
  description = "High-level summary of the deployed infrastructure"
  value = {
    project_name                       = var.project_name
    environment                        = var.environment
    region                             = var.aws_region
    vpc_enabled                        = true
    nat_gateways                       = 0
    public_subnets                     = length(module.vpc.public_subnet_ids)
    private_subnets                    = 0
    security_groups                    = 1
    mlops_orchestration_instance_type  = aws_instance.mlops_orchestration.instance_type
    mlops_orchestration_instance_state = aws_instance.mlops_orchestration.instance_state
    lambda_function_created            = true
    lambda_package_type                = "Image"
    lambda_runtime                     = "Container"
    s3_buckets                         = 3
    kinesis_shards                     = var.kinesis_shard_count
    ecr_repositories                   = 1
    architecture                       = "simplified-ec2-docker-compose-lambda"
  }
}
