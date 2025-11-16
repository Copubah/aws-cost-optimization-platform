data "archive_file" "cost_optimizer" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/cost_optimizer"
  output_path = "${path.module}/cost_optimizer.zip"
}

data "archive_file" "budget_handler" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/notifications"
  output_path = "${path.module}/budget_handler.zip"
}

# Cost Optimizer Lambda Function
resource "aws_lambda_function" "cost_optimizer" {
  filename         = data.archive_file.cost_optimizer.output_path
  function_name    = "${var.project_name}-${var.environment}-cost-optimizer"
  role             = var.cost_optimizer_role_arn
  handler          = "stop_dev_instances.lambda_handler"
  source_code_hash = data.archive_file.cost_optimizer.output_base64sha256
  runtime          = "python3.11"
  timeout          = 300
  memory_size      = 256

  environment {
    variables = {
      ENVIRONMENT            = var.environment
      SNS_TOPIC_ARN          = var.operations_alert_topic_arn
      ENABLE_COST_AUTOMATION = var.enable_cost_automation
      BUSINESS_HOURS_START   = var.business_hours_start
      BUSINESS_HOURS_END     = var.business_hours_end
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-cost-optimizer"
    }
  )
}

# Budget Alert Handler Lambda Function
resource "aws_lambda_function" "budget_handler" {
  filename         = data.archive_file.budget_handler.output_path
  function_name    = "${var.project_name}-${var.environment}-budget-handler"
  role             = var.budget_handler_role_arn
  handler          = "budget_alert_handler.lambda_handler"
  source_code_hash = data.archive_file.budget_handler.output_base64sha256
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 128

  environment {
    variables = {
      ENVIRONMENT               = var.environment
      COST_OPTIMIZER_LAMBDA_ARN = aws_lambda_function.cost_optimizer.arn
      OPERATIONS_SNS_TOPIC_ARN  = var.operations_alert_topic_arn
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-budget-handler"
    }
  )
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "cost_optimizer" {
  name              = "/aws/lambda/${aws_lambda_function.cost_optimizer.function_name}"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "budget_handler" {
  name              = "/aws/lambda/${aws_lambda_function.budget_handler.function_name}"
  retention_in_days = 7

  tags = var.tags
}

# SNS Subscription for Budget Alerts
resource "aws_sns_topic_subscription" "budget_handler" {
  topic_arn = var.budget_alert_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.budget_handler.arn
}

# Lambda Permission for SNS
resource "aws_lambda_permission" "budget_handler_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.budget_handler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.budget_alert_topic_arn
}

# EventBridge Rule for Scheduled Cost Optimization (weekdays at 6 PM UTC)
resource "aws_cloudwatch_event_rule" "cost_optimizer_schedule" {
  name                = "${var.project_name}-${var.environment}-cost-optimizer-schedule"
  description         = "Trigger cost optimizer Lambda on weekdays at 6 PM UTC"
  schedule_expression = "cron(0 18 ? * MON-FRI *)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cost_optimizer_schedule" {
  rule      = aws_cloudwatch_event_rule.cost_optimizer_schedule.name
  target_id = "CostOptimizerLambda"
  arn       = aws_lambda_function.cost_optimizer.arn

  input = jsonencode({
    action = "stop_dev_instances"
  })
}

resource "aws_lambda_permission" "cost_optimizer_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_optimizer_schedule.arn
}

# EventBridge Rule for ECS Scaling (weekdays at 7 PM UTC)
resource "aws_cloudwatch_event_rule" "ecs_scaler_schedule" {
  name                = "${var.project_name}-${var.environment}-ecs-scaler-schedule"
  description         = "Scale down ECS tasks on weekdays at 7 PM UTC"
  schedule_expression = "cron(0 19 ? * MON-FRI *)"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "ecs_scaler_schedule" {
  rule      = aws_cloudwatch_event_rule.ecs_scaler_schedule.name
  target_id = "ECSScalerLambda"
  arn       = aws_lambda_function.cost_optimizer.arn

  input = jsonencode({
    action = "scale_ecs_tasks"
  })
}

resource "aws_lambda_permission" "ecs_scaler_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridgeECS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecs_scaler_schedule.arn
}
