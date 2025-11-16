# Deployment Guide

This guide walks through deploying the AWS Cost Optimization & Reliability Platform from scratch.

## Prerequisites

### Required Tools
- Terraform >= 1.5.0
- AWS CLI >= 2.0
- Python >= 3.11 (for Lambda development/testing)
- Git (for version control)

### AWS Account Requirements
- AWS account with appropriate permissions
- IAM user or role with permissions to create:
 - VPC, Subnets, NAT Gateways
 - ECS Clusters, Services, Task Definitions
 - Lambda Functions
 - CloudWatch Alarms, Dashboards, Log Groups
 - SNS Topics
 - S3 Buckets
 - IAM Roles and Policies
 - AWS Budgets

### AWS CLI Configuration

```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity
```

## Step 1: Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd aws-cost-optimization

# Copy example configuration
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

## Step 2: Configure Variables

Edit `terraform.tfvars` with your specific values:

```hcl
# AWS Configuration
aws_region = "us-east-1"
project_name = "cost-optimization"
environment = "dev" # or "staging", "prod"
cost_center = "engineering"

# Notification Configuration
budget_alert_emails = ["finance@yourcompany.com", "devops@yourcompany.com"]
operations_alert_emails = ["ops@yourcompany.com", "oncall@yourcompany.com"]

# Budget Configuration
monthly_budget_amount = 1000 # USD

# ECS Configuration
ecs_task_cpu = 256
ecs_task_memory = 512
ecs_desired_count = 2
app_image = "nginx:latest" # Replace with your application image

# Cost Automation
enable_cost_automation = true
business_hours_start = "09:00" # UTC
business_hours_end = "18:00" # UTC
```

## Step 3: Backend Configuration (Optional but Recommended)

For production deployments, configure remote state storage:

```bash
# Create S3 bucket for Terraform state
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
 --table-name terraform-state-lock \
 --attribute-definitions AttributeName=LockID,AttributeType=S \
 --key-schema AttributeName=LockID,KeyType=HASH \
 --billing-mode PAY_PER_REQUEST \
 --region us-east-1

# Create backend.tf
cat > backend.tf <<EOF
terraform {
 backend "s3" {
 bucket = "your-terraform-state-bucket"
 key = "cost-optimization/terraform.tfstate"
 region = "us-east-1"
 encrypt = true
 dynamodb_table = "terraform-state-lock"
 }
}
EOF
```

## Step 4: Initialize Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

## Step 5: Review Deployment Plan

```bash
# Generate and review execution plan
terraform plan -out=tfplan

# Review the plan carefully
# Verify resource counts and configurations
```

Expected resources to be created:
- VPC with public/private subnets
- NAT Gateway(s)
- ECS Cluster and Service
- Application Load Balancer
- Lambda Functions (2)
- SNS Topics (2)
- CloudWatch Alarms (8+)
- AWS Budgets (4)
- S3 Buckets (2)
- IAM Roles and Policies

## Step 6: Deploy Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# Or apply directly (will prompt for confirmation)
terraform apply
```

Deployment typically takes 5-10 minutes.

## Step 7: Verify Deployment

### Check Terraform Outputs

```bash
terraform output

# Get specific outputs
terraform output alb_url
terraform output ecs_cluster_name
```

### Verify SNS Subscriptions

Check your email for SNS subscription confirmation emails:
1. Budget alerts subscription
2. Operations alerts subscription

Click the confirmation links in both emails.

### Test Application

```bash
# Get ALB URL
ALB_URL=$(terraform output -raw alb_url)

# Test application endpoint
curl $ALB_URL

# Should return nginx welcome page or your application response
```

### Verify ECS Service

```bash
# Get cluster and service names
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)

# Check service status
aws ecs describe-services \
 --cluster $CLUSTER \
 --services $SERVICE \
 --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
```

### Check CloudWatch Dashboard

```bash
# Get dashboard name
DASHBOARD=$(terraform output -raw cloudwatch_dashboard_name)

# Open in browser (macOS)
open "https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=$DASHBOARD"
```

### Verify Lambda Functions

```bash
# List Lambda functions
aws lambda list-functions \
 --query "Functions[?contains(FunctionName, 'cost-optimization')].{Name:FunctionName,Runtime:Runtime,LastModified:LastModified}"

# Test cost optimizer (dry run)
aws lambda invoke \
 --function-name $(terraform output -raw cost_optimizer_lambda_name) \
 --payload '{"action":"stop_dev_instances","dry_run":true}' \
 response.json

# View response
cat response.json
```

## Step 8: Configure Monitoring

### CloudWatch Alarms

All alarms are automatically configured. Verify in AWS Console:

```bash
# List alarms
aws cloudwatch describe-alarms \
 --alarm-name-prefix "cost-optimization" \
 --query 'MetricAlarms[].{Name:AlarmName,State:StateValue}'
```

### Budget Alerts

Budgets are automatically created. Verify:

```bash
# List budgets
aws budgets describe-budgets \
 --account-id $(aws sts get-caller-identity --query Account --output text) \
 --query 'Budgets[].{Name:BudgetName,Amount:BudgetLimit.Amount,Unit:BudgetLimit.Unit}'
```

## Environment-Specific Deployments

### Development Environment

```bash
# Use dev workspace
terraform workspace new dev
terraform workspace select dev

# Deploy with dev settings
terraform apply -var-file=environments/dev/terraform.tfvars
```

### Staging Environment

```bash
# Use staging workspace
terraform workspace new staging
terraform workspace select staging

# Deploy with staging settings
terraform apply -var-file=environments/staging/terraform.tfvars
```

### Production Environment

```bash
# Use prod workspace
terraform workspace new prod
terraform workspace select prod

# Deploy with production settings
terraform apply -var-file=environments/prod/terraform.tfvars
```

## Post-Deployment Configuration

### Tag Existing Resources

For cost automation to work with existing resources, tag them appropriately:

```bash
# Tag EC2 instances for auto-stop
aws ec2 create-tags \
 --resources i-1234567890abcdef0 \
 --tags Key=AutoStop,Value=true Key=Environment,Value=dev

# Tag RDS instances
aws rds add-tags-to-resource \
 --resource-name arn:aws:rds:us-east-1:123456789012:db:mydb \
 --tags Key=AutoStop,Value=true Key=Environment,Value=dev
```

### Configure Cost Allocation Tags

Enable cost allocation tags in AWS Billing Console:
1. Go to AWS Billing Console
2. Navigate to Cost Allocation Tags
3. Activate tags: Environment, Project, CostCenter, ManagedBy

### Set Up Cost and Usage Reports (Optional)

```bash
# Create S3 bucket for CUR
aws s3 mb s3://your-cur-bucket --region us-east-1

# Configure CUR in AWS Console
# Billing > Cost & Usage Reports > Create report
```

## Troubleshooting

### Lambda Function Errors

```bash
# View Lambda logs
aws logs tail /aws/lambda/cost-optimization-dev-cost-optimizer --follow

# Check Lambda function configuration
aws lambda get-function-configuration \
 --function-name cost-optimization-dev-cost-optimizer
```

### ECS Service Not Starting

```bash
# Check service events
aws ecs describe-services \
 --cluster $CLUSTER \
 --services $SERVICE \
 --query 'services[0].events[0:5]'

# Check task logs
aws logs tail /ecs/cost-optimization-dev --follow
```

### SNS Notifications Not Received

```bash
# Check SNS subscriptions
aws sns list-subscriptions \
 --query 'Subscriptions[?contains(TopicArn, `cost-optimization`)]'

# Verify subscription status (should be "Confirmed")
```

### Budget Alerts Not Triggering

- Ensure SNS subscriptions are confirmed
- Check budget thresholds are appropriate
- Verify spending has reached threshold
- Check CloudWatch Logs for budget handler Lambda

## Updating the Deployment

```bash
# Pull latest changes
git pull

# Review changes
terraform plan

# Apply updates
terraform apply

# For Lambda code updates only
terraform taint module.lambda.aws_lambda_function.cost_optimizer
terraform apply
```

## Rollback Procedure

```bash
# Rollback to previous state
terraform state pull > backup.tfstate

# Restore from backup if needed
terraform state push backup.tfstate

# Or destroy and redeploy
terraform destroy
terraform apply
```

## Cleanup

To remove all resources:

```bash
# Destroy all resources
terraform destroy

# Confirm by typing 'yes'

# Verify all resources are deleted
aws resourcegroupstaggingapi get-resources \
 --tag-filters Key=Project,Values=cost-optimization
```

## Next Steps

- Review [TESTING.md](TESTING.md) for testing procedures
- Review [SECURITY.md](SECURITY.md) for security hardening
- Set up CI/CD pipeline for automated deployments
- Configure additional monitoring and alerting
- Implement backup and disaster recovery procedures
