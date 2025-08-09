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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "MLOps Taxi Prediction"
    Environment = "dev"
    Terraform   = "true"
  }
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


# ECR Configuration
variable "ecr_enable_image_scanning" {
  description = "Enable image scanning on ECR repositories"
  type        = bool
  default     = true
}

variable "ecr_max_image_count" {
  description = "Maximum number of images to keep in ECR repositories"
  type        = number
  default     = 10 # Cost optimization
}

variable "ecr_untagged_expiry_days" {
  description = "Number of days after which untagged images expire"
  type        = number
  default     = 1 # Clean up untagged images quickly
}


