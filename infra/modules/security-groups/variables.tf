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
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# SSH Configuration
variable "enable_ssh_access" {
  description = "Enable SSH access to EC2 instances"
  type        = bool
  default     = true
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# EC2 Configuration
variable "create_ec2_sg" {
  description = "Create EC2 security group"
  type        = bool
  default     = true
}

variable "ec2_custom_ports" {
  description = "Custom ports to allow on EC2"
  type = list(object({
    port        = number
    protocol    = string
    description = string
  }))
  default = []
}

# Lambda Configuration
variable "create_lambda_sg" {
  description = "Create Lambda security group"
  type        = bool
  default     = false
}

# VPC Endpoints Configuration
variable "create_vpc_endpoints_sg" {
  description = "Create VPC endpoints security group"
  type        = bool
  default     = false
}
