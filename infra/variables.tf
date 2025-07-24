variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "mlops-taxi-prediction"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-north-1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis stream"
  type        = number
  default     = 1
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda function in MB"
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 30
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.10"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "MLOps Taxi Prediction"
    Environment = "dev"
    Terraform   = "true"
  }
}

# VPC Module Configuration
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost optimization)"
  type        = bool
  default     = true  # Save $45/month
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network monitoring"
  type        = bool
  default     = false
}

variable "enable_s3_endpoint" {
  description = "Enable VPC endpoint for S3 (cost and security optimization)"
  type        = bool
  default     = false
}

variable "production_allowed_cidrs" {
  description = "CIDR blocks allowed to access ALB in production"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Should be restricted in production
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# RDS Configuration
variable "rds_postgres_version" {
  description = "PostgreSQL version for RDS"
  type        = string
  default     = "15.4"
}

variable "rds_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t4g.micro"  # ARM-based, cheaper than t3.micro
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS instance in GB"
  type        = number
  default     = 20  # Minimum for gp3
}

variable "rds_max_allocated_storage" {
  description = "Maximum allocated storage for RDS instance in GB"
  type        = number
  default     = 100
}

variable "rds_performance_insights_enabled" {
  description = "Enable Performance Insights for RDS"
  type        = bool
  default     = false
}

variable "rds_monitoring_interval" {
  description = "Enhanced monitoring interval for RDS"
  type        = number
  default     = 0
}

# Airflow Database Configuration
variable "airflow_db_name" {
  description = "Database name for Airflow"
  type        = string
  default     = "airflow"
}

variable "airflow_db_username" {
  description = "Database username for Airflow"
  type        = string
  default     = "airflow"
}

variable "airflow_db_password" {
  description = "Database password for Airflow"
  type        = string
  sensitive   = true
  default     = "changeme123!"  # Should be overridden in terraform.tfvars
}

# EFS Configuration
variable "efs_provisioned_throughput" {
  description = "Provisioned throughput for EFS in MiB/s"
  type        = number
  default     = 0  # Use bursting mode instead of provisioned (saves $15/month)
}

# ECS Configuration
variable "ecs_cpu" {
  description = "CPU units for ECS tasks"
  type        = number
  default     = 512
}

variable "ecs_memory" {
  description = "Memory for ECS tasks in MB"
  type        = number
  default     = 1024
}

# Airflow ECS Configuration
variable "airflow_cpu" {
  description = "CPU units for Airflow ECS tasks (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 1024  # 1 vCPU - sufficient for Airflow with LocalExecutor
}

variable "airflow_memory" {
  description = "Memory for Airflow ECS tasks in MB (minimum 512, max depends on CPU)"
  type        = number
  default     = 3072  # 3GB - based on Docker Compose experience (8GB was too little, 12GB worked)
}

# MLflow ECS Configuration  
variable "mlflow_cpu" {
  description = "CPU units for MLflow ECS tasks (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 512  # 0.5 vCPU - MLflow is less CPU intensive
}

variable "mlflow_memory" {
  description = "Memory for MLflow ECS tasks in MB (minimum 512, max depends on CPU)"
  type        = number
  default     = 1024  # 1GB - MLflow mainly serves UI and metadata
}

# ECR Configuration
variable "ecr_enable_image_scanning" {
  description = "Enable image scanning on ECR repositories"
  type        = bool
  default     = true
}

variable "ecr_max_image_count" {
  description = "Maximum number of images to keep in ECR repositories"
  type        = number
  default     = 10  # Cost optimization for personal project
}

variable "ecr_untagged_expiry_days" {
  description = "Number of days after which untagged images expire"
  type        = number
  default     = 1  # Clean up untagged images quickly
}

# Route 53 Configuration
variable "domain_name" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""  # Leave empty if no custom domain
}

variable "create_route53_records" {
  description = "Whether to create Route 53 DNS records"
  type        = bool
  default     = false  # Set to true if you have a domain
}

variable "airflow_subdomain" {
  description = "Subdomain for Airflow service"
  type        = string
  default     = "airflow"
}

variable "mlflow_subdomain" {
  description = "Subdomain for MLflow service"
  type        = string
  default     = "mlflow"
}

variable "enable_https" {
  description = "Enable HTTPS with SSL certificate"
  type        = bool
  default     = false  # Set to true for production
}
