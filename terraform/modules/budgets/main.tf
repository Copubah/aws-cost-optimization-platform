data "aws_caller_identity" "current" {}

# Monthly Budget
resource "aws_budgets_budget" "monthly" {
  name              = "${var.project_name}-${var.environment}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_amount
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Environment$${var.environment}"
    ]
  }

  # Create notifications for each threshold
  dynamic "notification" {
    for_each = var.budget_thresholds
    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value
      threshold_type            = "PERCENTAGE"
      notification_type         = notification.value >= 100 ? "ACTUAL" : "FORECASTED"
      subscriber_sns_topic_arns = [var.budget_alert_topic_arn]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-monthly-budget"
    }
  )
}

# EC2 Service Budget
resource "aws_budgets_budget" "ec2" {
  name              = "${var.project_name}-${var.environment}-ec2-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_amount * 0.4 # 40% of total budget
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Elastic Compute Cloud - Compute"
    ]
  }

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Environment$${var.environment}"
    ]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [var.budget_alert_topic_arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.budget_alert_topic_arn]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-budget"
    }
  )
}

# RDS Service Budget
resource "aws_budgets_budget" "rds" {
  name              = "${var.project_name}-${var.environment}-rds-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_amount * 0.3 # 30% of total budget
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Relational Database Service"
    ]
  }

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Environment$${var.environment}"
    ]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [var.budget_alert_topic_arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.budget_alert_topic_arn]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-budget"
    }
  )
}

# S3 Service Budget
resource "aws_budgets_budget" "s3" {
  name              = "${var.project_name}-${var.environment}-s3-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_amount * 0.1 # 10% of total budget
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  cost_filter {
    name = "Service"
    values = [
      "Amazon Simple Storage Service"
    ]
  }

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Environment$${var.environment}"
    ]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 90
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [var.budget_alert_topic_arn]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-s3-budget"
    }
  )
}
