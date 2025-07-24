# CloudWatch Monitoring, Autoscaling and Alarms Module
# This module provides comprehensive monitoring and autoscaling for ECS services

# SNS Topic for CloudWatch Alarms
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"
  
  tags = var.tags
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}

# CloudWatch Dashboard for MLOps Pipeline
resource "aws_cloudwatch_dashboard" "mlops_pipeline" {
  dashboard_name = "${var.project_name}-pipeline-${var.environment}"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.airflow_service_name, "ClusterName", var.cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."],
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.mlflow_service_name, "ClusterName", var.cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "ECS Service Resource Utilization"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_name],
            [".", "ResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "ALB Performance Metrics"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_identifier],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeableMemory", ".", "."],
            [".", "FreeStorageSpace", ".", "."]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "RDS Performance Metrics"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        
        properties = {
          metrics = [
            ["AWS/Kinesis", "IncomingRecords", "StreamName", var.kinesis_stream_name],
            [".", "OutgoingRecords", ".", "."],
            [".", "ReadProvisionedThroughputExceeded", ".", "."],
            [".", "WriteProvisionedThroughputExceeded", ".", "."]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "Kinesis Stream Metrics"
          period = 300
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        
        properties = {
          query = "SOURCE '/ecs/${var.project_name}-airflow-${var.environment}' | fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"
          region = var.aws_region
          title = "Recent Airflow Errors"
          view = "table"
        }
      }
    ]
  })
  
  tags = var.tags
}

# ECS Service Autoscaling Target for Airflow
resource "aws_appautoscaling_target" "airflow" {
  max_capacity       = var.airflow_max_capacity
  min_capacity       = var.airflow_min_capacity
  resource_id        = "service/${var.cluster_name}/${var.airflow_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  
  tags = var.tags
}

# ECS Service Autoscaling Target for MLflow
resource "aws_appautoscaling_target" "mlflow" {
  max_capacity       = var.mlflow_max_capacity
  min_capacity       = var.mlflow_min_capacity
  resource_id        = "service/${var.cluster_name}/${var.mlflow_service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  
  tags = var.tags
}

# Autoscaling Policy for Airflow - CPU Target Tracking
resource "aws_appautoscaling_policy" "airflow_cpu" {
  name               = "${var.project_name}-airflow-cpu-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.airflow.resource_id
  scalable_dimension = aws_appautoscaling_target.airflow.scalable_dimension
  service_namespace  = aws_appautoscaling_target.airflow.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.airflow_cpu_target_value
    scale_in_cooldown = 300
    scale_out_cooldown = 300
  }
  
  tags = var.tags
}

# Autoscaling Policy for Airflow - Memory Target Tracking
resource "aws_appautoscaling_policy" "airflow_memory" {
  name               = "${var.project_name}-airflow-memory-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.airflow.resource_id
  scalable_dimension = aws_appautoscaling_target.airflow.scalable_dimension
  service_namespace  = aws_appautoscaling_target.airflow.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.airflow_memory_target_value
    scale_in_cooldown = 300
    scale_out_cooldown = 300
  }
  
  tags = var.tags
}

# Autoscaling Policy for MLflow - CPU Target Tracking
resource "aws_appautoscaling_policy" "mlflow_cpu" {
  name               = "${var.project_name}-mlflow-cpu-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.mlflow.resource_id
  scalable_dimension = aws_appautoscaling_target.mlflow.scalable_dimension
  service_namespace  = aws_appautoscaling_target.mlflow.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.mlflow_cpu_target_value
    scale_in_cooldown = 300
    scale_out_cooldown = 300
  }
  
  tags = var.tags
}

# CloudWatch Alarms

# ECS Airflow High CPU Alarm
resource "aws_cloudwatch_metric_alarm" "airflow_high_cpu" {
  alarm_name          = "${var.project_name}-airflow-high-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This alarm monitors Airflow ECS service high CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"
  
  dimensions = {
    ServiceName = var.airflow_service_name
    ClusterName = var.cluster_name
  }
  
  tags = var.tags
}

# ECS Airflow High Memory Alarm
resource "aws_cloudwatch_metric_alarm" "airflow_high_memory" {
  alarm_name          = "${var.project_name}-airflow-high-memory-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This alarm monitors Airflow ECS service high memory utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"
  
  dimensions = {
    ServiceName = var.airflow_service_name
    ClusterName = var.cluster_name
  }
  
  tags = var.tags
}

# ECS Service Task Count Alarm (Service Down)
resource "aws_cloudwatch_metric_alarm" "airflow_service_down" {
  alarm_name          = "${var.project_name}-airflow-service-down-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This alarm monitors if Airflow service has no running tasks"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"
  
  dimensions = {
    ServiceName = var.airflow_service_name
    ClusterName = var.cluster_name
  }
  
  tags = var.tags
}

# ALB High Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "alb_high_response_time" {
  alarm_name          = "${var.project_name}-alb-high-response-time-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"  
  threshold           = "3"
  alarm_description   = "This alarm monitors ALB high response time"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    LoadBalancer = var.alb_name
  }
  
  tags = var.tags
}

# ALB High 5XX Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "alb_high_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-high-5xx-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This alarm monitors ALB high 5XX error rate"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    LoadBalancer = var.alb_name
  }
  
  tags = var.tags
}

# RDS High CPU Alarm
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "${var.project_name}-rds-high-cpu-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This alarm monitors RDS high CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }
  
  tags = var.tags
}

# RDS High Connection Count Alarm
resource "aws_cloudwatch_metric_alarm" "rds_high_connections" {
  alarm_name          = "${var.project_name}-rds-high-connections-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "40"  # t4g.micro supports max 62 connections, alarm at 40
  alarm_description   = "This alarm monitors RDS high database connections"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }
  
  tags = var.tags
}

# RDS Low Free Storage Alarm
resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  alarm_name          = "${var.project_name}-rds-low-storage-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000"  # 2GB in bytes
  alarm_description   = "This alarm monitors RDS low free storage space"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    DBInstanceIdentifier = var.rds_identifier
  }
  
  tags = var.tags
}

# Kinesis High PUT Records Failed Alarm
resource "aws_cloudwatch_metric_alarm" "kinesis_put_records_failed" {
  alarm_name          = "${var.project_name}-kinesis-put-failed-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "PutRecord.Errors"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This alarm monitors Kinesis PUT records failures"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    StreamName = var.kinesis_stream_name
  }
  
  tags = var.tags
}

# Lambda Function Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_high_errors" {
  count = var.lambda_function_name != "" ? 1 : 0
  
  alarm_name          = "${var.project_name}-lambda-high-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This alarm monitors Lambda function high error rate"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = var.lambda_function_name
  }
  
  tags = var.tags
}

# Lambda Function Duration Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_high_duration" {
  count = var.lambda_function_name != "" ? 1 : 0
  
  alarm_name          = "${var.project_name}-lambda-high-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "25000"  # 25 seconds (timeout is 30s)
  alarm_description   = "This alarm monitors Lambda function high duration"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = var.lambda_function_name
  }
  
  tags = var.tags
}

# Custom Composite Alarm for Service Health
resource "aws_cloudwatch_composite_alarm" "service_health" {
  alarm_name = "${var.project_name}-service-health-${var.environment}"
  
  alarm_description = "Composite alarm for overall service health"
  alarm_actions     = [aws_sns_topic.alerts.arn]
  ok_actions        = [aws_sns_topic.alerts.arn]
  
  alarm_rule = format("(%s OR %s OR %s OR %s)",
    aws_cloudwatch_metric_alarm.airflow_service_down.alarm_name,
    aws_cloudwatch_metric_alarm.alb_high_5xx_errors.alarm_name,
    aws_cloudwatch_metric_alarm.rds_high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.kinesis_put_records_failed.alarm_name
  )
  
  tags = var.tags
}

# Log-based Metric Filter for Airflow Errors
resource "aws_cloudwatch_log_metric_filter" "airflow_errors" {
  name           = "${var.project_name}-airflow-errors-${var.environment}"
  log_group_name = var.airflow_log_group_name
  pattern        = "[timestamp, request_id, level=\"ERROR\", ...]"

  metric_transformation {
    name      = "AirflowErrorCount"
    namespace = "MLOps/Pipeline"
    value     = "1"
  }
}

# Alarm for Log-based Airflow Errors
resource "aws_cloudwatch_metric_alarm" "airflow_log_errors" {
  alarm_name          = "${var.project_name}-airflow-log-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "AirflowErrorCount"
  namespace           = "MLOps/Pipeline"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "This alarm monitors Airflow application errors from logs"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  tags = var.tags
}

# Enable Container Insights for ECS Cluster
resource "aws_ecs_cluster_capacity_providers" "insights" {
  cluster_name = var.cluster_name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# Custom Metric for Application-Level Monitoring
resource "aws_cloudwatch_log_metric_filter" "ml_model_accuracy" {
  name           = "${var.project_name}-model-accuracy-${var.environment}"
  log_group_name = var.airflow_log_group_name
  pattern        = "[timestamp, request_id, level, message=\"Model accuracy:\", accuracy_value]"

  metric_transformation {
    name      = "ModelAccuracy"
    namespace = "MLOps/ModelPerformance"
    value     = "$accuracy_value"
  }
}

# Alarm for Model Performance Degradation
resource "aws_cloudwatch_metric_alarm" "model_accuracy_low" {
  alarm_name          = "${var.project_name}-model-accuracy-low-${var.environment}"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ModelAccuracy"
  namespace           = "MLOps/ModelPerformance"
  period              = "3600"  # 1 hour
  statistic           = "Average"
  threshold           = "0.75"  # 75% accuracy threshold
  alarm_description   = "This alarm monitors ML model accuracy degradation"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  
  tags = var.tags
}
