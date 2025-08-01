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
  default     = true # Save $45/month
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
  description = "CIDR blocks allowed to access services in production"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Should be restricted in production
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

# ECR Configuration
variable "ecr_enable_image_scanning" {
  description = "Enable image scanning on ECR repositories"
  type        = bool
  default     = true
}

variable "ecr_max_image_count" {
  description = "Maximum number of images to keep in ECR repositories"
  type        = number
  default     = 10 # Cost optimization for personal project
}

variable "ecr_untagged_expiry_days" {
  description = "Number of days after which untagged images expire"
  type        = number
  default     = 1 # Clean up untagged images quickly
}

variable "create_lambda_function" {
  description = "Whether to create the Lambda function (requires ECR image to exist first)"
  type        = bool
  default     = false
}

variable "airflow_fernet_key" {
  description = "Fernet key for Airflow encryption"
  type        = string
  default     = "qtGpTN6fSAYfPL9AbTO4yDao2s1PTdIJmFgpEY3vtFI="
  sensitive   = true
}
