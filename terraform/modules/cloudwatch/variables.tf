variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "operations_alert_topic_arn" {
  description = "ARN of operations alert SNS topic"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix"
  type        = string
}

variable "cpu_threshold_percent" {
  description = "CPU utilization threshold"
  type        = number
  default     = 80
}

variable "memory_threshold_percent" {
  description = "Memory utilization threshold"
  type        = number
  default     = 80
}

variable "alb_latency_threshold_ms" {
  description = "ALB latency threshold in milliseconds"
  type        = number
  default     = 1000
}

variable "alb_5xx_threshold" {
  description = "ALB 5XX error count threshold"
  type        = number
  default     = 10
}

variable "ecs_task_count_min" {
  description = "Minimum ECS task count"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
