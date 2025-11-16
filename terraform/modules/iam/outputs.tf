output "cost_optimizer_role_arn" {
  description = "ARN of cost optimizer IAM role"
  value       = aws_iam_role.cost_optimizer.arn
}

output "budget_handler_role_arn" {
  description = "ARN of budget handler IAM role"
  value       = aws_iam_role.budget_handler.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution IAM role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task IAM role"
  value       = aws_iam_role.ecs_task.arn
}
