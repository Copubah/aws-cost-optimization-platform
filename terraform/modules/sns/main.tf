# Budget Alert Topic
resource "aws_sns_topic" "budget_alerts" {
  name              = "${var.project_name}-${var.environment}-budget-alerts"
  display_name      = "Budget Alerts for ${var.project_name} ${var.environment}"
  kms_master_key_id = aws_kms_key.sns.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-budget-alerts"
    }
  )
}

resource "aws_sns_topic_policy" "budget_alerts" {
  arn = aws_sns_topic.budget_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBudgetsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.budget_alerts.arn
      }
    ]
  })
}

# Operations Alert Topic
resource "aws_sns_topic" "operations_alerts" {
  name              = "${var.project_name}-${var.environment}-operations-alerts"
  display_name      = "Operations Alerts for ${var.project_name} ${var.environment}"
  kms_master_key_id = aws_kms_key.sns.id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-operations-alerts"
    }
  )
}

resource "aws_sns_topic_policy" "operations_alerts" {
  arn = aws_sns_topic.operations_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.operations_alerts.arn
      },
      {
        Sid    = "AllowLambdaToPublish"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.operations_alerts.arn
      }
    ]
  })
}

# Email Subscriptions for Budget Alerts
resource "aws_sns_topic_subscription" "budget_email" {
  count = length(var.budget_alert_emails)

  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = var.budget_alert_emails[count.index]
}

# Email Subscriptions for Operations Alerts
resource "aws_sns_topic_subscription" "operations_email" {
  count = length(var.operations_alert_emails)

  topic_arn = aws_sns_topic.operations_alerts.arn
  protocol  = "email"
  endpoint  = var.operations_alert_emails[count.index]
}

# KMS Key for SNS Encryption
resource "aws_kms_key" "sns" {
  description             = "KMS key for SNS topic encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch to use the key"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Budgets to use the key"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${var.project_name}-${var.environment}-sns"
  target_key_id = aws_kms_key.sns.key_id
}

data "aws_caller_identity" "current" {}
