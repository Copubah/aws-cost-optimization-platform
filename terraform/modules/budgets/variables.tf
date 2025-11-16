variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
}

variable "budget_alert_topic_arn" {
  description = "ARN of SNS topic for budget alerts"
  type        = string
}

variable "budget_thresholds" {
  description = "Budget alert thresholds as percentages"
  type        = list(number)
  default     = [50, 80, 100, 120]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
