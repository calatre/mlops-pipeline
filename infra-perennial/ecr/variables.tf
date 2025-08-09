variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "mlops-taxi-prediction"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-north-1"
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

variable "max_image_count" {
  description = "Maximum number of images to keep in repository"
  type        = number
  default     = 20
}

