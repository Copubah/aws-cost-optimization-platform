output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_arn" {
  description = "CloudWatch dashboard ARN"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

output "ecs_cpu_alarm_arn" {
  description = "ECS CPU alarm ARN"
  value       = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
}

output "ecs_memory_alarm_arn" {
  description = "ECS memory alarm ARN"
  value       = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
}

output "alb_latency_alarm_arn" {
  description = "ALB latency alarm ARN"
  value       = aws_cloudwatch_metric_alarm.alb_latency_high.arn
}

output "service_critical_alarm_arn" {
  description = "Service critical composite alarm ARN"
  value       = aws_cloudwatch_composite_alarm.service_critical.arn
}
