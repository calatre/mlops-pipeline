variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ECS Service Information
variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "airflow_service_name" {
  description = "Name of the Airflow ECS service"
  type        = string
}

variable "mlflow_service_name" {
  description = "Name of the MLflow ECS service"
  type        = string
}

# ALB Information
variable "alb_name" {
  description = "Name of the Application Load Balancer (ALB ARN suffix)"
  type        = string
}

# RDS Information
variable "rds_identifier" {
  description = "RDS instance identifier"
  type        = string
}

# Kinesis Information
variable "kinesis_stream_name" {
  description = "Name of the Kinesis stream"
  type        = string
}

# Lambda Information
variable "lambda_function_name" {
  description = "Name of the Lambda function (optional)"
  type        = string
  default     = ""
}

# Log Group Information
variable "airflow_log_group_name" {
  description = "CloudWatch log group name for Airflow"
  type        = string
}

variable "mlflow_log_group_name" {
  description = "CloudWatch log group name for MLflow"
  type        = string
}

# Autoscaling Configuration - Airflow
variable "airflow_min_capacity" {
  description = "Minimum number of Airflow tasks"
  type        = number
  default     = 1
}

variable "airflow_max_capacity" {
  description = "Maximum number of Airflow tasks"
  type        = number
  default     = 5
}

variable "airflow_cpu_target_value" {
  description = "Target CPU utilization percentage for Airflow autoscaling"
  type        = number
  default     = 70
}

variable "airflow_memory_target_value" {
  description = "Target memory utilization percentage for Airflow autoscaling"
  type        = number
  default     = 70
}

# Autoscaling Configuration - MLflow
variable "mlflow_min_capacity" {
  description = "Minimum number of MLflow tasks"
  type        = number
  default     = 1
}

variable "mlflow_max_capacity" {
  description = "Maximum number of MLflow tasks"
  type        = number
  default     = 3
}

variable "mlflow_cpu_target_value" {
  description = "Target CPU utilization percentage for MLflow autoscaling"
  type        = number
  default     = 70
}

variable "mlflow_memory_target_value" {
  description = "Target memory utilization percentage for MLflow autoscaling"
  type        = number
  default     = 70
}

# Alarm Thresholds
variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for alarms (%)"
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Memory utilization threshold for alarms (%)"
  type        = number
  default     = 85
}

variable "alb_response_time_threshold" {
  description = "ALB response time threshold for alarms (seconds)"
  type        = number
  default     = 3
}

variable "alb_5xx_error_threshold" {
  description = "ALB 5XX error count threshold for alarms"
  type        = number
  default     = 10
}

variable "rds_cpu_threshold" {
  description = "RDS CPU utilization threshold for alarms (%)"
  type        = number
  default     = 80
}

variable "rds_connections_threshold" {
  description = "RDS database connections threshold for alarms"
  type        = number
  default     = 40
}

variable "rds_free_storage_threshold" {
  description = "RDS free storage threshold for alarms (bytes)"
  type        = number
  default     = 2000000000  # 2GB
}

variable "kinesis_put_errors_threshold" {
  description = "Kinesis PUT records error threshold for alarms"
  type        = number
  default     = 5
}

variable "lambda_error_threshold" {
  description = "Lambda error count threshold for alarms"
  type        = number
  default     = 5
}

variable "lambda_duration_threshold" {
  description = "Lambda duration threshold for alarms (milliseconds)"
  type        = number
  default     = 25000
}

variable "airflow_log_error_threshold" {
  description = "Airflow log error count threshold for alarms"
  type        = number
  default     = 3
}

variable "model_accuracy_threshold" {
  description = "ML model accuracy threshold for alarms (0.0-1.0)"
  type        = number
  default     = 0.75
}

# SNS Configuration
variable "sns_email_endpoints" {
  description = "List of email addresses to receive alarm notifications"
  type        = list(string)
  default     = []
}

variable "enable_email_notifications" {
  description = "Whether to enable email notifications for alarms"
  type        = bool
  default     = false
}

# Dashboard Configuration
variable "dashboard_time_range" {
  description = "Default time range for dashboard widgets (in seconds)"
  type        = number
  default     = 3600  # 1 hour
}

# Monitoring Features
variable "enable_container_insights" {
  description = "Enable Container Insights for ECS cluster"
  type        = bool
  default     = true
}

variable "enable_log_metric_filters" {
  description = "Enable CloudWatch log metric filters"
  type        = bool
  default     = true
}

variable "enable_custom_metrics" {
  description = "Enable custom application metrics"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}
