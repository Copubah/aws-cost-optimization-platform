variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "cost-optimization"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

# SNS Configuration
variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
}

variable "operations_alert_emails" {
  description = "Email addresses for operational alerts"
  type        = list(string)
}

# Budget Configuration
variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 1000
}

variable "budget_thresholds" {
  description = "Budget alert thresholds as percentages"
  type        = list(number)
  default     = [50, 80, 100, 120]
}

# ECS Configuration
variable "ecs_task_cpu" {
  description = "CPU units for ECS task (1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory for ECS task in MB"
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 1
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 10
}

variable "app_image" {
  description = "Docker image for application"
  type        = string
  default     = "nginx:latest"
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 80
}

# CloudWatch Alarm Thresholds
variable "cpu_threshold_percent" {
  description = "CPU utilization threshold for alarms"
  type        = number
  default     = 80
}

variable "memory_threshold_percent" {
  description = "Memory utilization threshold for alarms"
  type        = number
  default     = 80
}

variable "alb_latency_threshold_ms" {
  description = "ALB target response time threshold in milliseconds"
  type        = number
  default     = 1000
}

variable "alb_5xx_threshold" {
  description = "ALB 5xx error count threshold"
  type        = number
  default     = 10
}

# S3 Lifecycle Configuration
variable "s3_transition_to_ia_days" {
  description = "Days before transitioning to Infrequent Access"
  type        = number
  default     = 30
}

variable "s3_transition_to_glacier_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 90
}

variable "s3_expiration_days" {
  description = "Days before object expiration"
  type        = number
  default     = 365
}

# Cost Automation Configuration
variable "enable_cost_automation" {
  description = "Enable automated cost optimization actions"
  type        = bool
  default     = true
}

variable "business_hours_start" {
  description = "Business hours start time (24h format, UTC)"
  type        = string
  default     = "09:00"
}

variable "business_hours_end" {
  description = "Business hours end time (24h format, UTC)"
  type        = string
  default     = "18:00"
}
