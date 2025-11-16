# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.ecs_service_name, "ClusterName", var.ecs_cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ECS Service Metrics"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix],
            [".", "RequestCount", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = data.aws_region.current.name
          title  = "ALB Metrics"
        }
      }
    ]
  })
}

# ECS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold_percent
  alarm_description   = "ECS CPU utilization is too high"
  alarm_actions       = [var.operations_alert_topic_arn]

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = var.tags
}

# ECS Memory Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_threshold_percent
  alarm_description   = "ECS memory utilization is too high"
  alarm_actions       = [var.operations_alert_topic_arn]

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = var.tags
}

# ECS Task Count Alarm (Low)
resource "aws_cloudwatch_metric_alarm" "ecs_task_count_low" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-task-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = var.ecs_task_count_min
  alarm_description   = "ECS running task count is below minimum"
  alarm_actions       = [var.operations_alert_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    ServiceName = var.ecs_service_name
    ClusterName = var.ecs_cluster_name
  }

  tags = var.tags
}

# ALB Target Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "alb_latency_high" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.alb_latency_threshold_ms / 1000 # Convert to seconds
  alarm_description   = "ALB target response time is too high"
  alarm_actions       = [var.operations_alert_topic_arn]

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# ALB 5XX Error Alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.alb_5xx_threshold
  alarm_description   = "ALB 5XX error count is too high"
  alarm_actions       = [var.operations_alert_topic_arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# ALB Unhealthy Target Alarm
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "ALB has unhealthy targets"
  alarm_actions       = [var.operations_alert_topic_arn]

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# ALB Healthy Target Count Low Alarm
resource "aws_cloudwatch_metric_alarm" "alb_healthy_targets_low" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-healthy-targets-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = var.ecs_task_count_min
  alarm_description   = "ALB healthy target count is below minimum"
  alarm_actions       = [var.operations_alert_topic_arn]
  treat_missing_data  = "breaching"

  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }

  tags = var.tags
}

# Composite Alarm for Critical Service Health
resource "aws_cloudwatch_composite_alarm" "service_critical" {
  alarm_name        = "${var.project_name}-${var.environment}-service-critical"
  alarm_description = "Critical service health issues detected"
  actions_enabled   = true
  alarm_actions     = [var.operations_alert_topic_arn]

  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.ecs_task_count_low.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.alb_unhealthy_targets.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.alb_healthy_targets_low.alarm_name})"
  ])

  tags = var.tags
}

# Log Metric Filter for Application Errors
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${var.project_name}-${var.environment}-app-errors"
  log_group_name = "/ecs/${var.project_name}-${var.environment}"
  pattern        = "[time, request_id, level = ERROR*, ...]"

  metric_transformation {
    name          = "ApplicationErrors"
    namespace     = "${var.project_name}/${var.environment}"
    value         = "1"
    default_value = 0
  }
}

# Application Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "app_error_rate" {
  alarm_name          = "${var.project_name}-${var.environment}-app-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApplicationErrors"
  namespace           = "${var.project_name}/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Application error rate is too high"
  alarm_actions       = [var.operations_alert_topic_arn]
  treat_missing_data  = "notBreaching"

  tags = var.tags
}

data "aws_region" "current" {}
