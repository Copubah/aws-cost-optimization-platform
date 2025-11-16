# Testing Guide

Comprehensive testing procedures to validate cost optimization and reliability features.

## Testing Overview

This guide covers:
1. Budget alert testing
2. Cost automation validation
3. Reliability alarm verification
4. Failover testing
5. Security validation
6. Performance testing

## Prerequisites

- Deployed infrastructure (see DEPLOYMENT.md)
- AWS CLI configured
- Appropriate IAM permissions
- SNS subscriptions confirmed

## 1. Budget Alert Testing

### Test Budget Threshold Notifications

```bash
# Get budget names
aws budgets describe-budgets \
 --account-id $(aws sts get-caller-identity --query Account --output text) \
 --query 'Budgets[].BudgetName'

# Note: Budget alerts trigger based on actual spending
# For testing, you can temporarily lower budget amounts
```

### Simulate Budget Alert

```bash
# Manually invoke budget handler Lambda with test payload
aws lambda invoke \
 --function-name cost-optimization-dev-budget-handler \
 --payload '{
 "budgetName": "cost-optimization-dev-monthly-budget",
 "threshold": 85,
 "actualSpend": 850,
 "forecastedSpend": 950
 }' \
 response.json

# Check response
cat response.json

# Verify notification received via email
```

### Verify Budget Handler Logs

```bash
# View Lambda logs
aws logs tail /aws/lambda/cost-optimization-dev-budget-handler --follow

# Check for errors
aws logs filter-log-events \
 --log-group-name /aws/lambda/cost-optimization-dev-budget-handler \
 --filter-pattern "ERROR"
```

## 2. Cost Automation Testing

### Test EC2 Instance Stop Automation

```bash
# Create test EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
 --image-id ami-0c55b159cbfafe1f0 \
 --instance-type t3.micro \
 --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-autostop},{Key=Environment,Value=dev},{Key=AutoStop,Value=true}]' \
 --query 'Instances[0].InstanceId' \
 --output text)

echo "Created test instance: $INSTANCE_ID"

# Wait for instance to be running
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Invoke cost optimizer Lambda (dry run)
aws lambda invoke \
 --function-name cost-optimization-dev-cost-optimizer \
 --payload '{
 "action": "stop_dev_instances",
 "dry_run": true
 }' \
 response.json

# Check if instance was identified
cat response.json | jq '.body | fromjson | .ec2'

# Invoke cost optimizer Lambda (actual stop)
aws lambda invoke \
 --function-name cost-optimization-dev-cost-optimizer \
 --payload '{
 "action": "stop_dev_instances",
 "dry_run": false
 }' \
 response.json

# Verify instance is stopping
aws ec2 describe-instances \
 --instance-ids $INSTANCE_ID \
 --query 'Reservations[0].Instances[0].State.Name'

# Cleanup
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

### Test ECS Task Scaling

```bash
# Get current task count
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)

CURRENT_COUNT=$(aws ecs describe-services \
 --cluster $CLUSTER \
 --services $SERVICE \
 --query 'services[0].desiredCount' \
 --output text)

echo "Current task count: $CURRENT_COUNT"

# Invoke ECS scaling Lambda (dry run)
aws lambda invoke \
 --function-name cost-optimization-dev-cost-optimizer \
 --payload '{
 "action": "scale_ecs_tasks",
 "dry_run": true
 }' \
 response.json

cat response.json | jq '.body | fromjson | .ecs'

# Invoke ECS scaling Lambda (actual scale)
aws lambda invoke \
 --function-name cost-optimization-dev-cost-optimizer \
 --payload '{
 "action": "scale_ecs_tasks",
 "dry_run": false
 }' \
 response.json

# Verify task count changed
NEW_COUNT=$(aws ecs describe-services \
 --cluster $CLUSTER \
 --services $SERVICE \
 --query 'services[0].desiredCount' \
 --output text)

echo "New task count: $NEW_COUNT"

# Restore original count
aws ecs update-service \
 --cluster $CLUSTER \
 --service $SERVICE \
 --desired-count $CURRENT_COUNT
```

### Test Scheduled Automation

```bash
# Check EventBridge rules
aws events list-rules \
 --name-prefix "cost-optimization" \
 --query 'Rules[].{Name:Name,Schedule:ScheduleExpression,State:State}'

# Manually trigger scheduled rule
aws events put-events \
 --entries '[{
 "Source": "manual.test",
 "DetailType": "Scheduled Event",
 "Detail": "{\"action\":\"stop_dev_instances\"}"
 }]'
```

## 3. Reliability Alarm Testing

### Test ECS CPU Alarm

```bash
# Generate CPU load on ECS tasks
# First, get task ARN
TASK_ARN=$(aws ecs list-tasks \
 --cluster $CLUSTER \
 --service-name $SERVICE \
 --query 'taskArns[0]' \
 --output text)

# Execute command in task to generate CPU load
aws ecs execute-command \
 --cluster $CLUSTER \
 --task $TASK_ARN \
 --container app \
 --interactive \
 --command "stress --cpu 2 --timeout 300"

# Monitor alarm state
aws cloudwatch describe-alarms \
 --alarm-names "cost-optimization-dev-ecs-cpu-high" \
 --query 'MetricAlarms[0].{State:StateValue,Reason:StateReason}'

# Wait for alarm to trigger (may take 5-10 minutes)
```

### Test ALB Health Check Alarm

```bash
# Stop all ECS tasks to trigger unhealthy target alarm
aws ecs update-service \
 --cluster $CLUSTER \
 --service $SERVICE \
 --desired-count 0

# Wait for alarm
sleep 120

# Check alarm state
aws cloudwatch describe-alarms \
 --alarm-names "cost-optimization-dev-alb-unhealthy-targets" \
 --query 'MetricAlarms[0].StateValue'

# Restore service
aws ecs update-service \
 --cluster $CLUSTER \
 --service $SERVICE \
 --desired-count 2
```

### Test ALB Latency Alarm

```bash
# Generate load to test latency monitoring
ALB_URL=$(terraform output -raw alb_url)

# Use Apache Bench or similar tool
ab -n 10000 -c 100 $ALB_URL/

# Monitor latency metrics
aws cloudwatch get-metric-statistics \
 --namespace AWS/ApplicationELB \
 --metric-name TargetResponseTime \
 --dimensions Name=LoadBalancer,Value=$(terraform output -raw alb_arn_suffix) \
 --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
 --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
 --period 300 \
 --statistics Average
```

### Test Composite Alarm

```bash
# Check composite alarm status
aws cloudwatch describe-alarms \
 --alarm-names "cost-optimization-dev-service-critical" \
 --query 'CompositeAlarms[0].{State:StateValue,Rule:AlarmRule}'

# Trigger multiple child alarms to test composite
# (Use previous tests to trigger individual alarms)
```

## 4. Auto-Scaling Testing

### Test ECS Auto-Scaling

```bash
# Generate load to trigger auto-scaling
ALB_URL=$(terraform output -raw alb_url)

# Run load test (requires Apache Bench)
ab -n 100000 -c 200 $ALB_URL/

# Monitor task count
watch -n 5 "aws ecs describe-services \
 --cluster $CLUSTER \
 --services $SERVICE \
 --query 'services[0].{Desired:desiredCount,Running:runningCount}'"

# Check scaling activities
aws application-autoscaling describe-scaling-activities \
 --service-namespace ecs \
 --resource-id "service/$CLUSTER/$SERVICE" \
 --max-results 10
```

## 5. S3 Lifecycle Policy Testing

```bash
# Get bucket name
BUCKET=$(terraform output -raw s3_bucket_name)

# Upload test objects
echo "test content" > test-file.txt
aws s3 cp test-file.txt s3://$BUCKET/temp/test-file.txt
aws s3 cp test-file.txt s3://$BUCKET/archive/archive-file.txt

# Check lifecycle configuration
aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET

# Note: Lifecycle transitions happen daily, not immediately
# To verify, check object storage class after configured days
```

## 6. Security Testing

### Test IAM Permissions

```bash
# Verify Lambda has minimum required permissions
aws lambda get-policy \
 --function-name cost-optimization-dev-cost-optimizer

# Test that Lambda cannot perform unauthorized actions
aws lambda invoke \
 --function-name cost-optimization-dev-cost-optimizer \
 --payload '{
 "action": "unauthorized_action"
 }' \
 response.json

# Should fail or return error
```

### Test Encryption

```bash
# Verify S3 encryption
aws s3api get-bucket-encryption --bucket $BUCKET

# Verify SNS encryption
aws sns get-topic-attributes \
 --topic-arn $(terraform output -raw budget_alert_topic_arn) \
 --query 'Attributes.KmsMasterKeyId'

# Verify CloudWatch Logs encryption
aws logs describe-log-groups \
 --log-group-name-prefix "/aws/lambda/cost-optimization" \
 --query 'logGroups[].kmsKeyId'
```

### Test Network Security

```bash
# Verify security group rules
aws ec2 describe-security-groups \
 --filters "Name=tag:Project,Values=cost-optimization" \
 --query 'SecurityGroups[].{Name:GroupName,Ingress:IpPermissions}'

# Test that ECS tasks are in private subnets
aws ecs describe-tasks \
 --cluster $CLUSTER \
 --tasks $(aws ecs list-tasks --cluster $CLUSTER --query 'taskArns[0]' --output text) \
 --query 'tasks[0].attachments[0].details[?name==`subnetId`].value'
```

## 7. Disaster Recovery Testing

### Test ECS Service Recovery

```bash
# Stop all tasks
TASK_ARNS=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --query 'taskArns' --output text)

for TASK in $TASK_ARNS; do
 aws ecs stop-task --cluster $CLUSTER --task $TASK
done

# Monitor automatic recovery
watch -n 5 "aws ecs describe-services \
 --cluster $CLUSTER \
 --services $SERVICE \
 --query 'services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount}'"

# Service should automatically start new tasks
```

### Test Multi-AZ Failover

```bash
# Verify tasks are distributed across AZs
aws ecs describe-tasks \
 --cluster $CLUSTER \
 --tasks $(aws ecs list-tasks --cluster $CLUSTER --query 'taskArns' --output text) \
 --query 'tasks[].{TaskArn:taskArn,AZ:availabilityZone}'

# Simulate AZ failure by stopping tasks in one AZ
# (In production, AWS handles this automatically)
```

## 8. Performance Testing

### Load Testing

```bash
# Install Apache Bench if not available
# sudo apt-get install apache2-utils # Ubuntu/Debian
# brew install httpd # macOS

ALB_URL=$(terraform output -raw alb_url)

# Light load test
ab -n 1000 -c 10 $ALB_URL/

# Medium load test
ab -n 10000 -c 100 $ALB_URL/

# Heavy load test (monitor auto-scaling)
ab -n 100000 -c 500 $ALB_URL/
```

### Monitor Performance Metrics

```bash
# View CloudWatch dashboard
DASHBOARD=$(terraform output -raw cloudwatch_dashboard_name)
echo "Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=$DASHBOARD"

# Get ECS metrics
aws cloudwatch get-metric-statistics \
 --namespace AWS/ECS \
 --metric-name CPUUtilization \
 --dimensions Name=ServiceName,Value=$SERVICE Name=ClusterName,Value=$CLUSTER \
 --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
 --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
 --period 300 \
 --statistics Average,Maximum
```

## 9. Integration Testing

### End-to-End Budget Alert Flow

```bash
# 1. Trigger budget alert
aws lambda invoke \
 --function-name cost-optimization-dev-budget-handler \
 --payload '{
 "budgetName": "test-budget",
 "threshold": 100,
 "actualSpend": 1000,
 "forecastedSpend": 1100
 }' \
 response.json

# 2. Verify cost optimizer was invoked
aws logs filter-log-events \
 --log-group-name /aws/lambda/cost-optimization-dev-cost-optimizer \
 --start-time $(date -u -d '5 minutes ago' +%s)000 \
 --filter-pattern "triggered_by"

# 3. Verify SNS notifications sent
aws logs filter-log-events \
 --log-group-name /aws/lambda/cost-optimization-dev-budget-handler \
 --start-time $(date -u -d '5 minutes ago' +%s)000 \
 --filter-pattern "Notification sent"

# 4. Check email for notifications
```

## Test Checklist

- [ ] Budget alerts trigger correctly
- [ ] Cost optimizer stops dev instances
- [ ] ECS tasks scale down when triggered
- [ ] Scheduled automation runs on schedule
- [ ] CPU alarms trigger at threshold
- [ ] Memory alarms trigger at threshold
- [ ] ALB health check alarms work
- [ ] Latency alarms trigger correctly
- [ ] Composite alarms aggregate properly
- [ ] Auto-scaling increases capacity under load
- [ ] Auto-scaling decreases capacity when idle
- [ ] S3 lifecycle policies configured
- [ ] IAM permissions are least privilege
- [ ] Encryption enabled for all resources
- [ ] Network security groups properly configured
- [ ] ECS service auto-recovers from failures
- [ ] Multi-AZ deployment verified
- [ ] SNS notifications received
- [ ] CloudWatch dashboard displays metrics
- [ ] Lambda functions execute successfully

## Cleanup After Testing

```bash
# Remove test resources
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Reset ECS service to normal
aws ecs update-service \
 --cluster $CLUSTER \
 --service $SERVICE \
 --desired-count 2

# Clear test S3 objects
aws s3 rm s3://$BUCKET/temp/ --recursive
aws s3 rm s3://$BUCKET/archive/ --recursive
```

## Continuous Testing

Set up automated testing in CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
name: Test Infrastructure
on:
 schedule:
 - cron: '0 0   ' # Daily
jobs:
 test:
 runs-on: ubuntu-latest
 steps:
 - uses: actions/checkout@v2
 - name: Configure AWS
 uses: aws-actions/configure-aws-credentials@v1
 - name: Run tests
 run: |
 ./scripts/run-tests.sh
```
