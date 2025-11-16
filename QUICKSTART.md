# Quick Start Guide

Get the AWS Cost Optimization & Reliability Platform up and running in under 15 minutes.

## Prerequisites Checklist

- [ ] AWS Account with admin access
- [ ] AWS CLI installed and configured (`aws --version`)
- [ ] Terraform >= 1.5.0 installed (`terraform --version`)
- [ ] Git installed
- [ ] Email addresses for alerts

## 5-Minute Setup

### Step 1: Configure (2 minutes)

```bash
# Navigate to terraform directory
cd terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars # or use your preferred editor
```

Minimum required changes:
```hcl
budget_alert_emails = ["your-email@company.com"]
operations_alert_emails = ["ops@company.com"]
monthly_budget_amount = 1000 # Your monthly budget in USD
```

### Step 2: Deploy (5 minutes)

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (type 'yes' when prompted)
terraform apply
```

### Step 3: Verify (3 minutes)

```bash
# Get deployment outputs
terraform output

# Test the application
curl $(terraform output -raw alb_url)

# Run validation script
cd ..
./scripts/validate-deployment.sh dev
```

### Step 4: Confirm SNS Subscriptions (2 minutes)

1. Check your email for SNS subscription confirmations
2. Click "Confirm subscription" in both emails
3. You're done!

## What You Just Deployed

### Infrastructure
- Multi-AZ VPC with public/private subnets
- ECS Fargate cluster with sample application
- Application Load Balancer
- Auto-scaling configuration

### Cost Management
- AWS Budgets with 4 budget types
- Lambda functions for cost automation
- Scheduled resource optimization
- SNS notifications

### Monitoring
- 8+ CloudWatch alarms
- CloudWatch dashboard
- Log aggregation
- Composite alarms

## Quick Tests

### Test 1: Check Application
```bash
ALB_URL=$(cd terraform && terraform output -raw alb_url)
curl $ALB_URL
# Should return nginx welcome page
```

### Test 2: Test Cost Optimizer (Dry Run)
```bash
aws lambda invoke \
 --function-name $(cd terraform && terraform output -raw cost_optimizer_lambda_name) \
 --payload '{"action":"stop_dev_instances","dry_run":true}' \
 response.json

cat response.json
```

### Test 3: View CloudWatch Dashboard
```bash
# Get dashboard URL
REGION=$(aws configure get region)
DASHBOARD=$(cd terraform && terraform output -raw cloudwatch_dashboard_name)
echo "https://console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=$DASHBOARD"
```

## Common Issues & Solutions

### Issue: Terraform init fails
Solution: Check AWS credentials
```bash
aws sts get-caller-identity
```

### Issue: ECS tasks not starting
Solution: Check service events
```bash
CLUSTER=$(cd terraform && terraform output -raw ecs_cluster_name)
SERVICE=$(cd terraform && terraform output -raw ecs_service_name)
aws ecs describe-services --cluster $CLUSTER --services $SERVICE --query 'services[0].events[0:5]'
```

### Issue: ALB returns 503
Solution: Wait for tasks to become healthy (2-3 minutes)
```bash
watch -n 5 "aws ecs describe-services --cluster $CLUSTER --services $SERVICE --query 'services[0].{Running:runningCount,Desired:desiredCount}'"
```

### Issue: SNS emails not received
Solution: Check spam folder and verify email addresses in terraform.tfvars

## Next Steps

### Immediate (Today)
1. Confirm SNS subscriptions
2. Review CloudWatch dashboard
3. Tag existing resources for automation
4. Test budget alerts

### This Week
1. Read [ARCHITECTURE.md](docs/ARCHITECTURE.md)
2. Complete [TESTING.md](docs/TESTING.md) procedures
3. Review [SECURITY.md](docs/SECURITY.md) recommendations
4. Set up cost allocation tags

### This Month
1. Optimize resource sizing
2. Analyze cost trends
3. Set up CI/CD pipeline
4. Document custom procedures

## Useful Commands

### View All Resources
```bash
cd terraform
terraform state list
```

### Get Specific Output
```bash
cd terraform
terraform output alb_url
terraform output ecs_cluster_name
```

### Update Configuration
```bash
cd terraform
# Edit terraform.tfvars
terraform plan
terraform apply
```

### View Logs
```bash
# Lambda logs
aws logs tail /aws/lambda/cost-optimization-dev-cost-optimizer --follow

# ECS logs
aws logs tail /ecs/cost-optimization-dev --follow
```

### Check Costs
```bash
# Current month costs
aws ce get-cost-and-usage \
 --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
 --granularity MONTHLY \
 --metrics UnblendedCost
```

## Cleanup

To remove all resources:

```bash
cd terraform
terraform destroy
# Type 'yes' when prompted
```

Warning: This will delete all resources and data. Make sure you have backups if needed.

## Getting Help

### Documentation
- [Architecture Overview](docs/ARCHITECTURE.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Testing Guide](docs/TESTING.md)
- [Security Guide](docs/SECURITY.md)
- [Project Summary](docs/PROJECT_SUMMARY.md)

### Troubleshooting
1. Check CloudWatch Logs
2. Review Terraform state
3. Verify AWS credentials
4. Check security groups
5. Review service events

### Support Resources
- AWS Documentation
- Terraform Registry
- AWS Well-Architected Framework
- Community forums

## Cost Estimate

### Development Environment
- Monthly Cost: $120-200
- Breakdown:
 - ECS Fargate: $50-100
 - NAT Gateway: $32
 - ALB: $20
 - Lambda: $5
 - CloudWatch: $10
 - S3: $5
 - Other: $10

### Optimization Potential
- Auto-stop dev resources: 40-50% savings
- Fargate Spot: 70% savings on non-prod
- S3 lifecycle: 60% savings on storage
- Right-sizing: 20-30% savings

Estimated Monthly Savings: $150-300 after optimization

## Success Metrics

After deployment, you should see:
- Application accessible via ALB URL
- ECS tasks running (2/2)
- CloudWatch alarms in OK state
- SNS subscriptions confirmed
- Lambda functions active
- Budgets configured
- No errors in logs

## What's Next?

You now have a production-ready AWS infrastructure with:
- Automated cost optimization
- High availability and reliability
- Comprehensive monitoring
- Security best practices
- Scalable architecture

Congratulations! 

Start optimizing your AWS costs while maintaining reliability!
