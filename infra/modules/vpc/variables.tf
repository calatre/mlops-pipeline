# VPC Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

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

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost optimization)"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network monitoring"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "CloudWatch log retention period for VPC Flow Logs"
  type        = number
  default     = 14
}

variable "enable_s3_endpoint" {
  description = "Enable VPC endpoint for S3 (cost and security optimization)"
  type        = bool
  default     = false
}

variable "enable_custom_dhcp_options" {
  description = "Enable custom DHCP options set"
  type        = bool
  default     = false
}

variable "dhcp_options_domain_name_servers" {
  description = "List of domain name servers for DHCP options"
  type        = list(string)
  default     = ["AmazonProvidedDNS"]
}

variable "dhcp_options_domain_name" {
  description = "Domain name for DHCP options"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
