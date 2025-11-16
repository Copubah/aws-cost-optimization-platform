output "cost_optimizer_lambda_arn" {
  description = "ARN of cost optimizer Lambda function"
  value       = aws_lambda_function.cost_optimizer.arn
}

output "cost_optimizer_lambda_name" {
  description = "Name of cost optimizer Lambda function"
  value       = aws_lambda_function.cost_optimizer.function_name
}

output "budget_handler_lambda_arn" {
  description = "ARN of budget handler Lambda function"
  value       = aws_lambda_function.budget_handler.arn
}

output "budget_handler_lambda_name" {
  description = "Name of budget handler Lambda function"
  value       = aws_lambda_function.budget_handler.function_name
}
