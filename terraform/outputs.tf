output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.ecs.alb_dns_name
}

output "alb_url" {
  description = "Application Load Balancer URL"
  value       = "http://${module.ecs.alb_dns_name}"
}

output "budget_alert_topic_arn" {
  description = "SNS topic ARN for budget alerts"
  value       = module.sns.budget_alert_topic_arn
}

output "operations_alert_topic_arn" {
  description = "SNS topic ARN for operational alerts"
  value       = module.sns.operations_alert_topic_arn
}

output "cost_optimizer_lambda_name" {
  description = "Cost optimizer Lambda function name"
  value       = module.lambda.cost_optimizer_lambda_name
}

output "budget_handler_lambda_name" {
  description = "Budget alert handler Lambda function name"
  value       = module.lambda.budget_handler_lambda_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for application data"
  value       = module.s3.bucket_name
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = module.cloudwatch.dashboard_name
}

output "deployment_summary" {
  description = "Deployment summary information"
  value = {
    environment    = var.environment
    region         = var.aws_region
    project_name   = var.project_name
    alb_url        = "http://${module.ecs.alb_dns_name}"
    ecs_cluster    = module.ecs.cluster_name
    monthly_budget = var.monthly_budget_amount
  }
}
