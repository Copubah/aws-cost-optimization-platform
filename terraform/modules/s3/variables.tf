variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_versioning" {
  description = "Enable S3 versioning"
  type        = bool
  default     = false
}

variable "enable_lifecycle_policies" {
  description = "Enable lifecycle policies"
  type        = bool
  default     = true
}

variable "transition_to_ia_days" {
  description = "Days before transitioning to Infrequent Access"
  type        = number
  default     = 30
}

variable "transition_to_glacier_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 90
}

variable "expiration_days" {
  description = "Days before object expiration"
  type        = number
  default     = 365
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
