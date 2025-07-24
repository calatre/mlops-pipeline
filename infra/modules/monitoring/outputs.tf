# SNS Topic Outputs
output "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for CloudWatch alarms"
  value       = aws_sns_topic.alerts.name
}

# CloudWatch Dashboard Output
output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.mlops_pipeline.dashboard_name
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.mlops_pipeline.dashboard_name}"
}

# Autoscaling Target Outputs
output "airflow_autoscaling_target_resource_id" {
  description = "Resource ID of the Airflow autoscaling target"
  value       = aws_appautoscaling_target.airflow.resource_id
}

output "mlflow_autoscaling_target_resource_id" {
  description = "Resource ID of the MLflow autoscaling target"
  value       = aws_appautoscaling_target.mlflow.resource_id
}

# Autoscaling Policy Outputs
output "airflow_cpu_scaling_policy_arn" {
  description = "ARN of the Airflow CPU autoscaling policy"
  value       = aws_appautoscaling_policy.airflow_cpu.arn
}

output "airflow_memory_scaling_policy_arn" {
  description = "ARN of the Airflow memory autoscaling policy"
  value       = aws_appautoscaling_policy.airflow_memory.arn
}

output "mlflow_cpu_scaling_policy_arn" {
  description = "ARN of the MLflow CPU autoscaling policy"
  value       = aws_appautoscaling_policy.mlflow_cpu.arn
}

# Critical Alarm Outputs
output "critical_alarms" {
  description = "Map of critical CloudWatch alarm names and ARNs"
  value = {
    airflow_high_cpu    = aws_cloudwatch_metric_alarm.airflow_high_cpu.arn
    airflow_high_memory = aws_cloudwatch_metric_alarm.airflow_high_memory.arn
    airflow_service_down = aws_cloudwatch_metric_alarm.airflow_service_down.arn
    alb_high_response_time = aws_cloudwatch_metric_alarm.alb_high_response_time.arn
    alb_high_5xx_errors = aws_cloudwatch_metric_alarm.alb_high_5xx_errors.arn
    rds_high_cpu = aws_cloudwatch_metric_alarm.rds_high_cpu.arn
    rds_high_connections = aws_cloudwatch_metric_alarm.rds_high_connections.arn
    rds_low_storage = aws_cloudwatch_metric_alarm.rds_low_storage.arn
    kinesis_put_records_failed = aws_cloudwatch_metric_alarm.kinesis_put_records_failed.arn
  }
}

# Composite Alarm Output
output "service_health_alarm_arn" {
  description = "ARN of the composite service health alarm"
  value       = aws_cloudwatch_composite_alarm.service_health.arn
}

output "service_health_alarm_name" {
  description = "Name of the composite service health alarm"
  value       = aws_cloudwatch_composite_alarm.service_health.alarm_name
}

# Lambda Alarms (conditional)
output "lambda_alarms" {
  description = "Map of Lambda CloudWatch alarm ARNs (if Lambda function is provided)"
  value = var.lambda_function_name != "" ? {
    lambda_high_errors = aws_cloudwatch_metric_alarm.lambda_high_errors[0].arn
    lambda_high_duration = aws_cloudwatch_metric_alarm.lambda_high_duration[0].arn
  } : {}
}

# Log Metric Filter Outputs
output "log_metric_filters" {
  description = "Map of CloudWatch log metric filter names"
  value = {
    airflow_errors = aws_cloudwatch_log_metric_filter.airflow_errors.name
    model_accuracy = aws_cloudwatch_log_metric_filter.ml_model_accuracy.name
  }
}

# Custom Metric Alarms
output "custom_metric_alarms" {
  description = "Map of custom metric alarm ARNs"
  value = {
    airflow_log_errors = aws_cloudwatch_metric_alarm.airflow_log_errors.arn
    model_accuracy_low = aws_cloudwatch_metric_alarm.model_accuracy_low.arn
  }
}

# Monitoring Summary
output "monitoring_summary" {
  description = "Summary of monitoring resources created"
  value = {
    sns_topic_arn = aws_sns_topic.alerts.arn
    dashboard_name = aws_cloudwatch_dashboard.mlops_pipeline.dashboard_name
    total_alarms = length([
      aws_cloudwatch_metric_alarm.airflow_high_cpu,
      aws_cloudwatch_metric_alarm.airflow_high_memory,
      aws_cloudwatch_metric_alarm.airflow_service_down,
      aws_cloudwatch_metric_alarm.alb_high_response_time,
      aws_cloudwatch_metric_alarm.alb_high_5xx_errors,
      aws_cloudwatch_metric_alarm.rds_high_cpu,
      aws_cloudwatch_metric_alarm.rds_high_connections,
      aws_cloudwatch_metric_alarm.rds_low_storage,
      aws_cloudwatch_metric_alarm.kinesis_put_records_failed,
      aws_cloudwatch_metric_alarm.airflow_log_errors,
      aws_cloudwatch_metric_alarm.model_accuracy_low
    ]) + (var.lambda_function_name != "" ? 2 : 0)
    autoscaling_targets = 2
    autoscaling_policies = 3
    log_metric_filters = 2
    composite_alarms = 1
  }
}

# Alarm States (for monitoring dashboard integration)
output "alarm_arns_for_dashboard" {
  description = "List of all alarm ARNs for dashboard integration"
  value = concat([
    aws_cloudwatch_metric_alarm.airflow_high_cpu.arn,
    aws_cloudwatch_metric_alarm.airflow_high_memory.arn,
    aws_cloudwatch_metric_alarm.airflow_service_down.arn,
    aws_cloudwatch_metric_alarm.alb_high_response_time.arn,
    aws_cloudwatch_metric_alarm.alb_high_5xx_errors.arn,
    aws_cloudwatch_metric_alarm.rds_high_cpu.arn,
    aws_cloudwatch_metric_alarm.rds_high_connections.arn,
    aws_cloudwatch_metric_alarm.rds_low_storage.arn,
    aws_cloudwatch_metric_alarm.kinesis_put_records_failed.arn,
    aws_cloudwatch_metric_alarm.airflow_log_errors.arn,
    aws_cloudwatch_metric_alarm.model_accuracy_low.arn,
    aws_cloudwatch_composite_alarm.service_health.arn
  ], var.lambda_function_name != "" ? [
    aws_cloudwatch_metric_alarm.lambda_high_errors[0].arn,
    aws_cloudwatch_metric_alarm.lambda_high_duration[0].arn
  ] : [])
}
