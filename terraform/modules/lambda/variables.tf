variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "budget_alert_topic_arn" {
  description = "ARN of budget alert SNS topic"
  type        = string
}

variable "operations_alert_topic_arn" {
  description = "ARN of operations alert SNS topic"
  type        = string
}

variable "cost_optimizer_role_arn" {
  description = "ARN of cost optimizer IAM role"
  type        = string
}

variable "budget_handler_role_arn" {
  description = "ARN of budget handler IAM role"
  type        = string
}

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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
