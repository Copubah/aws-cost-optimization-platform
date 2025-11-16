output "budget_alert_topic_arn" {
  description = "ARN of budget alert SNS topic"
  value       = aws_sns_topic.budget_alerts.arn
}

output "operations_alert_topic_arn" {
  description = "ARN of operations alert SNS topic"
  value       = aws_sns_topic.operations_alerts.arn
}

output "sns_kms_key_id" {
  description = "KMS key ID for SNS encryption"
  value       = aws_kms_key.sns.id
}
