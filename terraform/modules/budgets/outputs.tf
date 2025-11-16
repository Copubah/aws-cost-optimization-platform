output "monthly_budget_name" {
  description = "Name of monthly budget"
  value       = aws_budgets_budget.monthly.name
}

output "ec2_budget_name" {
  description = "Name of EC2 budget"
  value       = aws_budgets_budget.ec2.name
}

output "rds_budget_name" {
  description = "Name of RDS budget"
  value       = aws_budgets_budget.rds.name
}

output "s3_budget_name" {
  description = "Name of S3 budget"
  value       = aws_budgets_budget.s3.name
}
