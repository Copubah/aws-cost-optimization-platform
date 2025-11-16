terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configure backend in backend.tf or via backend-config
    # bucket = "your-terraform-state-bucket"
    # key    = "cost-optimization/terraform.tfstate"
    # region = "us-east-1"
    # encrypt = true
    # dynamodb_table = "terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = var.environment
      CostCenter  = var.cost_center
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CostCenter  = var.cost_center
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.environment != "prod"
  enable_vpn_gateway = false
  enable_flow_logs   = var.environment == "prod"

  tags = local.common_tags
}

# SNS Module - Create topics first as they're dependencies
module "sns" {
  source = "./modules/sns"

  project_name = var.project_name
  environment  = var.environment

  budget_alert_emails     = var.budget_alert_emails
  operations_alert_emails = var.operations_alert_emails

  tags = local.common_tags
}

# IAM Module - Roles and policies for Lambda and ECS
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment

  tags = local.common_tags
}

# Lambda Module - Cost optimization functions
module "lambda" {
  source = "./modules/lambda"

  project_name = var.project_name
  environment  = var.environment

  budget_alert_topic_arn     = module.sns.budget_alert_topic_arn
  operations_alert_topic_arn = module.sns.operations_alert_topic_arn

  cost_optimizer_role_arn = module.iam.cost_optimizer_role_arn
  budget_handler_role_arn = module.iam.budget_handler_role_arn

  enable_cost_automation = var.enable_cost_automation
  business_hours_start   = var.business_hours_start
  business_hours_end     = var.business_hours_end

  tags = local.common_tags
}

# S3 Module - Application storage with lifecycle policies
module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment

  enable_versioning          = var.environment == "prod"
  enable_lifecycle_policies  = true
  transition_to_ia_days      = var.s3_transition_to_ia_days
  transition_to_glacier_days = var.s3_transition_to_glacier_days
  expiration_days            = var.s3_expiration_days

  tags = local.common_tags
}

# ECS Module - Application workload
module "ecs" {
  source = "./modules/ecs"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  ecs_task_cpu      = var.ecs_task_cpu
  ecs_task_memory   = var.ecs_task_memory
  ecs_desired_count = var.ecs_desired_count
  ecs_min_capacity  = var.ecs_min_capacity
  ecs_max_capacity  = var.ecs_max_capacity

  enable_container_insights = var.environment == "prod"
  enable_spot_instances     = var.environment != "prod"

  app_image                   = var.app_image
  app_port                    = var.app_port
  ecs_task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn           = module.iam.ecs_task_role_arn

  tags = local.common_tags
}

# CloudWatch Module - Alarms and monitoring
module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name = var.project_name
  environment  = var.environment

  operations_alert_topic_arn = module.sns.operations_alert_topic_arn

  # ECS monitoring
  ecs_cluster_name = module.ecs.cluster_name
  ecs_service_name = module.ecs.service_name

  # ALB monitoring
  alb_arn_suffix          = module.ecs.alb_arn_suffix
  target_group_arn_suffix = module.ecs.target_group_arn_suffix

  # Alarm thresholds
  cpu_threshold_percent    = var.cpu_threshold_percent
  memory_threshold_percent = var.memory_threshold_percent
  alb_latency_threshold_ms = var.alb_latency_threshold_ms
  alb_5xx_threshold        = var.alb_5xx_threshold
  ecs_task_count_min       = var.ecs_min_capacity

  tags = local.common_tags
}

# Budgets Module - Cost control
module "budgets" {
  source = "./modules/budgets"

  project_name = var.project_name
  environment  = var.environment

  monthly_budget_amount  = var.monthly_budget_amount
  budget_alert_topic_arn = module.sns.budget_alert_topic_arn

  # Budget thresholds
  budget_thresholds = var.budget_thresholds

  tags = local.common_tags
}
