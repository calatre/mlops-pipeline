# ECR Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_image_scanning" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Maximum number of images to keep in repository"
  type        = number
  default     = 10
}

variable "untagged_expiry_days" {
  description = "Number of days after which untagged images expire"
  type        = number
  default     = 1
}

variable "enable_cross_account_access" {
  description = "Enable cross-account access to repositories"
  type        = bool
  default     = false
}

variable "cross_account_arns" {
  description = "List of AWS account ARNs that can access the repositories"
  type        = list(string)
  default     = []
}
