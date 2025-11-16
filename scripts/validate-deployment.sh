#!/bin/bash
# Deployment Validation Script
# Validates that all components are deployed and functioning correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="terraform"
ENVIRONMENT="${1:-dev}"

echo "========================================="
echo "AWS Cost Optimization Platform"
echo "Deployment Validation Script"
echo "Environment: $ENVIRONMENT"
echo "========================================="
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check prerequisites
echo "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}✗${NC} Terraform is not installed"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}✗${NC} AWS CLI is not installed"; exit 1; }
print_status 0 "Prerequisites installed"
echo ""

# Check AWS credentials
echo "Checking AWS credentials..."
aws sts get-caller-identity >/dev/null 2>&1
print_status $? "AWS credentials configured"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "  Account ID: $ACCOUNT_ID"
echo ""

# Get Terraform outputs
echo "Retrieving Terraform outputs..."
cd $TERRAFORM_DIR
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null)
SERVICE_NAME=$(terraform output -raw ecs_service_name 2>/dev/null)
ALB_URL=$(terraform output -raw alb_url 2>/dev/null)
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null)
COST_OPTIMIZER_LAMBDA=$(terraform output -raw cost_optimizer_lambda_name 2>/dev/null)
BUDGET_HANDLER_LAMBDA=$(terraform output -raw budget_handler_lambda_name 2>/dev/null)
cd ..

if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${RED}✗${NC} Failed to retrieve Terraform outputs. Is the infrastructure deployed?"
    exit 1
fi
print_status 0 "Terraform outputs retrieved"
echo ""

# Validate VPC
echo "Validating VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=cost-optimization" "Name=tag:Environment,Values=$ENVIRONMENT" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    print_status 0 "VPC exists: $VPC_ID"
else
    print_status 1 "VPC not found"
fi
echo ""

# Validate ECS Cluster
echo "Validating ECS Cluster..."
CLUSTER_STATUS=$(aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].status' --output text 2>/dev/null)
if [ "$CLUSTER_STATUS" == "ACTIVE" ]; then
    print_status 0 "ECS Cluster is active: $CLUSTER_NAME"
else
    print_status 1 "ECS Cluster is not active"
fi
echo ""

# Validate ECS Service
echo "Validating ECS Service..."
SERVICE_STATUS=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query 'services[0].status' --output text 2>/dev/null)
RUNNING_COUNT=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query 'services[0].runningCount' --output text 2>/dev/null)
DESIRED_COUNT=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query 'services[0].desiredCount' --output text 2>/dev/null)

if [ "$SERVICE_STATUS" == "ACTIVE" ]; then
    print_status 0 "ECS Service is active: $SERVICE_NAME"
    echo "  Running tasks: $RUNNING_COUNT / $DESIRED_COUNT"
    if [ "$RUNNING_COUNT" -lt "$DESIRED_COUNT" ]; then
        print_warning "Not all tasks are running yet"
    fi
else
    print_status 1 "ECS Service is not active"
fi
echo ""

# Validate ALB
echo "Validating Application Load Balancer..."
if [ -n "$ALB_URL" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $ALB_URL --max-time 10 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "301" ] || [ "$HTTP_CODE" == "302" ]; then
        print_status 0 "ALB is responding: $ALB_URL (HTTP $HTTP_CODE)"
    else
        print_status 1 "ALB is not responding correctly (HTTP $HTTP_CODE)"
    fi
else
    print_status 1 "ALB URL not found"
fi
echo ""

# Validate Lambda Functions
echo "Validating Lambda Functions..."
COST_OPT_STATUS=$(aws lambda get-function --function-name $COST_OPTIMIZER_LAMBDA --query 'Configuration.State' --output text 2>/dev/null)
if [ "$COST_OPT_STATUS" == "Active" ]; then
    print_status 0 "Cost Optimizer Lambda is active: $COST_OPTIMIZER_LAMBDA"
else
    print_status 1 "Cost Optimizer Lambda is not active"
fi

BUDGET_HANDLER_STATUS=$(aws lambda get-function --function-name $BUDGET_HANDLER_LAMBDA --query 'Configuration.State' --output text 2>/dev/null)
if [ "$BUDGET_HANDLER_STATUS" == "Active" ]; then
    print_status 0 "Budget Handler Lambda is active: $BUDGET_HANDLER_LAMBDA"
else
    print_status 1 "Budget Handler Lambda is not active"
fi
echo ""

# Validate S3 Buckets
echo "Validating S3 Buckets..."
if aws s3 ls s3://$BUCKET_NAME >/dev/null 2>&1; then
    print_status 0 "S3 Bucket exists: $BUCKET_NAME"
    
    # Check encryption
    ENCRYPTION=$(aws s3api get-bucket-encryption --bucket $BUCKET_NAME --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text 2>/dev/null)
    if [ -n "$ENCRYPTION" ]; then
        print_status 0 "S3 Bucket encryption enabled: $ENCRYPTION"
    else
        print_warning "S3 Bucket encryption not detected"
    fi
else
    print_status 1 "S3 Bucket not accessible"
fi
echo ""

# Validate CloudWatch Alarms
echo "Validating CloudWatch Alarms..."
ALARM_COUNT=$(aws cloudwatch describe-alarms --alarm-name-prefix "cost-optimization-$ENVIRONMENT" --query 'length(MetricAlarms)' --output text 2>/dev/null)
if [ "$ALARM_COUNT" -gt 0 ]; then
    print_status 0 "CloudWatch Alarms configured: $ALARM_COUNT alarms"
    
    # Check for alarms in ALARM state
    ALARM_STATE_COUNT=$(aws cloudwatch describe-alarms --alarm-name-prefix "cost-optimization-$ENVIRONMENT" --state-value ALARM --query 'length(MetricAlarms)' --output text 2>/dev/null)
    if [ "$ALARM_STATE_COUNT" -gt 0 ]; then
        print_warning "$ALARM_STATE_COUNT alarm(s) in ALARM state"
    fi
else
    print_status 1 "No CloudWatch Alarms found"
fi
echo ""

# Validate SNS Topics
echo "Validating SNS Topics..."
SNS_TOPICS=$(aws sns list-topics --query "Topics[?contains(TopicArn, 'cost-optimization-$ENVIRONMENT')].TopicArn" --output text 2>/dev/null)
TOPIC_COUNT=$(echo "$SNS_TOPICS" | wc -w)
if [ "$TOPIC_COUNT" -ge 2 ]; then
    print_status 0 "SNS Topics configured: $TOPIC_COUNT topics"
else
    print_status 1 "Expected 2 SNS topics, found $TOPIC_COUNT"
fi
echo ""

# Validate Budgets
echo "Validating AWS Budgets..."
BUDGET_COUNT=$(aws budgets describe-budgets --account-id $ACCOUNT_ID --query "Budgets[?contains(BudgetName, 'cost-optimization-$ENVIRONMENT')].BudgetName" --output text 2>/dev/null | wc -w)
if [ "$BUDGET_COUNT" -ge 1 ]; then
    print_status 0 "AWS Budgets configured: $BUDGET_COUNT budget(s)"
else
    print_status 1 "No AWS Budgets found"
fi
echo ""

# Validate EventBridge Rules
echo "Validating EventBridge Rules..."
RULE_COUNT=$(aws events list-rules --name-prefix "cost-optimization-$ENVIRONMENT" --query 'length(Rules)' --output text 2>/dev/null)
if [ "$RULE_COUNT" -ge 2 ]; then
    print_status 0 "EventBridge Rules configured: $RULE_COUNT rule(s)"
else
    print_status 1 "Expected at least 2 EventBridge rules, found $RULE_COUNT"
fi
echo ""

# Test Lambda Function
echo "Testing Lambda Function..."
echo "Running cost optimizer in dry-run mode..."
LAMBDA_RESULT=$(aws lambda invoke \
    --function-name $COST_OPTIMIZER_LAMBDA \
    --payload '{"action":"stop_dev_instances","dry_run":true}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/lambda-response.json 2>&1)

if [ $? -eq 0 ]; then
    print_status 0 "Lambda function executed successfully"
    echo "  Response saved to /tmp/lambda-response.json"
else
    print_status 1 "Lambda function execution failed"
fi
echo ""

# Summary
echo "========================================="
echo "Validation Summary"
echo "========================================="
echo ""
echo "Infrastructure Components:"
echo "  - VPC: $VPC_ID"
echo "  - ECS Cluster: $CLUSTER_NAME"
echo "  - ECS Service: $SERVICE_NAME ($RUNNING_COUNT/$DESIRED_COUNT tasks)"
echo "  - ALB URL: $ALB_URL"
echo "  - S3 Bucket: $BUCKET_NAME"
echo ""
echo "Automation Components:"
echo "  - Lambda Functions: 2"
echo "  - CloudWatch Alarms: $ALARM_COUNT"
echo "  - SNS Topics: $TOPIC_COUNT"
echo "  - AWS Budgets: $BUDGET_COUNT"
echo "  - EventBridge Rules: $RULE_COUNT"
echo ""
echo "Next Steps:"
echo "  1. Confirm SNS subscription emails"
echo "  2. Review CloudWatch dashboard"
echo "  3. Test budget alerts (see docs/TESTING.md)"
echo "  4. Configure resource tags for automation"
echo ""
echo "For detailed testing procedures, see docs/TESTING.md"
echo "========================================="
