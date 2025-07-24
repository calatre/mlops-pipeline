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

# Lambda Outputs - commented out until Lambda function is available
# output "lambda_function_name" {
#   description = "Name of the Lambda function"
#   value       = aws_lambda_function.taxi_predictor.function_name
# }

# output "lambda_function_arn" {
#   description = "ARN of the Lambda function"
#   value       = aws_lambda_function.taxi_predictor.arn
# }

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

# output "cloudwatch_log_group" {
#   description = "CloudWatch Log Group name for Lambda"
#   value       = aws_cloudwatch_log_group.lambda_logs.name
# }

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

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = module.vpc.nat_gateway_ids
}

output "nat_gateway_ips" {
  description = "Public IPs of the NAT Gateways"
  value       = module.vpc.nat_gateway_ips
}

output "network_summary" {
  description = "Summary of network configuration"
  value       = module.vpc.network_summary
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security_groups.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.security_groups.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.security_groups.rds_security_group_id
}

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = module.security_groups.efs_security_group_id
}

output "security_groups_summary" {
  description = "Summary of all created security groups"
  value       = module.security_groups.security_groups_summary
}

# Load Balancer Outputs
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_target_group_airflow_arn" {
  description = "ARN of the Airflow target group"
  value       = aws_lb_target_group.airflow.arn
}

output "alb_target_group_mlflow_arn" {
  description = "ARN of the MLflow target group"
  value       = aws_lb_target_group.mlflow.arn
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

# ECS Task Definition Outputs
output "airflow_task_definition_arn" {
  description = "ARN of the Airflow ECS task definition"
  value       = aws_ecs_task_definition.airflow.arn
}

output "airflow_task_definition_family" {
  description = "Family name of the Airflow ECS task definition"
  value       = aws_ecs_task_definition.airflow.family
}

output "airflow_task_definition_revision" {
  description = "Revision of the Airflow ECS task definition"
  value       = aws_ecs_task_definition.airflow.revision
}

output "mlflow_task_definition_arn" {
  description = "ARN of the MLflow ECS task definition"
  value       = aws_ecs_task_definition.mlflow.arn
}

output "mlflow_task_definition_family" {
  description = "Family name of the MLflow ECS task definition"
  value       = aws_ecs_task_definition.mlflow.family
}

output "mlflow_task_definition_revision" {
  description = "Revision of the MLflow ECS task definition"
  value       = aws_ecs_task_definition.mlflow.revision
}

# EFS Access Points
output "efs_airflow_access_point_id" {
  description = "ID of the EFS access point for Airflow"
  value       = aws_efs_access_point.airflow.id
}

output "efs_mlflow_access_point_id" {
  description = "ID of the EFS access point for MLflow"
  value       = aws_efs_access_point.mlflow.id
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.airflow.endpoint
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.airflow.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.airflow.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.airflow.username
  sensitive   = true
}

# EFS Outputs
output "efs_file_system_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.main.id
}

output "efs_file_system_arn" {
  description = "ARN of the EFS file system"
  value       = aws_efs_file_system.main.arn
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.main.dns_name
}

# CloudWatch Log Groups
output "cloudwatch_log_group_ecs_cluster" {
  description = "CloudWatch log group for ECS cluster"
  value       = aws_cloudwatch_log_group.ecs_cluster.name
}

output "cloudwatch_log_group_airflow" {
  description = "CloudWatch log group for Airflow"
  value       = aws_cloudwatch_log_group.airflow.name
}

output "cloudwatch_log_group_mlflow" {
  description = "CloudWatch log group for MLflow"
  value       = aws_cloudwatch_log_group.mlflow.name
}

# ECR Repository Outputs for CI/CD
output "ecr_airflow_repository_url" {
  description = "URL of the Airflow ECR repository"
  value       = module.ecr.airflow_repository_url
}

output "ecr_mlflow_repository_url" {
  description = "URL of the MLflow ECR repository"
  value       = module.ecr.mlflow_repository_url
}

output "ecr_lambda_repository_url" {
  description = "URL of the Lambda ECR repository"
  value       = module.ecr.lambda_repository_url
}

output "ecr_repository_names" {
  description = "Map of all ECR repository names"
  value       = module.ecr.all_repository_names
}

output "ecr_repository_urls" {
  description = "Map of all ECR repository URLs"
  value       = module.ecr.all_repository_urls
}

output "ecr_registry_id" {
  description = "AWS ECR registry ID"
  value       = module.ecr.registry_id
}

# Infrastructure Summary
output "infrastructure_summary" {
  description = "High-level summary of the deployed infrastructure"
  value = {
    project_name          = var.project_name
    environment          = var.environment
    region               = var.aws_region
    vpc_enabled          = true
    nat_gateways         = length(module.vpc.nat_gateway_ids)
    single_nat_gateway   = var.single_nat_gateway
    vpc_flow_logs        = var.enable_vpc_flow_logs
    s3_endpoint          = var.enable_s3_endpoint
    availability_zones   = length(module.vpc.availability_zones)
    public_subnets       = length(module.vpc.public_subnet_ids)
    private_subnets      = length(module.vpc.private_subnet_ids)
    security_groups      = module.security_groups.security_groups_summary.total_security_groups
    rds_multi_az         = aws_db_instance.airflow.multi_az
    efs_encrypted        = aws_efs_file_system.main.encrypted
    s3_buckets           = 3
    kinesis_shards       = var.kinesis_shard_count
    ecr_repositories     = 3
    ecs_task_definitions = 2
    airflow_cpu          = var.airflow_cpu
    airflow_memory       = var.airflow_memory
    mlflow_cpu           = var.mlflow_cpu
    mlflow_memory        = var.mlflow_memory
  }
}
