# Security Groups Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where security groups will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

# ALB Configuration
variable "alb_allowed_cidrs" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Allow from anywhere, restrict for production
}

variable "alb_custom_ports" {
  description = "Custom ports to allow on ALB"
  type = list(object({
    port        = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

# Application Ports
variable "airflow_port" {
  description = "Port for Airflow web UI"
  type        = number
  default     = 8080
}

variable "mlflow_port" {
  description = "Port for MLflow UI"
  type        = number
  default     = 5000
}

variable "postgres_port" {
  description = "Port for PostgreSQL"
  type        = number
  default     = 5432
}

variable "nfs_port" {
  description = "Port for NFS (EFS)"
  type        = number
  default     = 2049
}

variable "redis_port" {
  description = "Port for Redis"
  type        = number
  default     = 6379
}

# ECS Configuration
variable "ecs_custom_ports" {
  description = "Custom ports to allow on ECS from ALB"
  type = list(object({
    port     = number
    protocol = string
  }))
  default = []
}

# SSH Access
variable "enable_ssh_access" {
  description = "Enable SSH access to ECS tasks (for debugging)"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = []
}

# Database Admin Access
variable "db_admin_access_cidrs" {
  description = "CIDR blocks allowed for database admin access"
  type        = list(string)
  default     = []
}

# EFS Admin Access
variable "efs_admin_access_cidrs" {
  description = "CIDR blocks allowed for EFS admin access"
  type        = list(string)
  default     = []
}

# Optional Security Groups
variable "create_lambda_sg" {
  description = "Create security group for Lambda functions"
  type        = bool
  default     = false
}

variable "create_vpc_endpoints_sg" {
  description = "Create security group for VPC endpoints"
  type        = bool
  default     = false
}

variable "create_redis_sg" {
  description = "Create security group for Redis/ElastiCache"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
