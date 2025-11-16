variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "ecs_task_cpu" {
  description = "CPU units for ECS task"
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

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = false
}

variable "enable_spot_instances" {
  description = "Enable Fargate Spot instances"
  type        = bool
  default     = false
}

variable "app_image" {
  description = "Docker image for application"
  type        = string
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 80
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"
  type        = string
  default     = ""
}

variable "ecs_task_role_arn" {
  description = "ARN of ECS task role"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
