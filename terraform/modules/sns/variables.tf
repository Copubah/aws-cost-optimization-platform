variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts"
  type        = list(string)
}

variable "operations_alert_emails" {
  description = "Email addresses for operational alerts"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
