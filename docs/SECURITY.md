# Security Guide

Security best practices and hardening recommendations for the AWS Cost Optimization & Reliability Platform.

## Security Overview

This platform implements multiple layers of security following AWS Well-Architected Framework security pillar:

1. Identity and Access Management (IAM)
2. Data Protection
3. Infrastructure Protection
4. Detective Controls
5. Incident Response

## 1. Identity and Access Management

### IAM Roles and Policies

All services use IAM roles with least privilege access:

#### Lambda Function Roles

Cost Optimizer Role - Minimal permissions:
```json
{
 "Version": "2012-10-17",
 "Statement": [
 {
 "Effect": "Allow",
 "Action": [
 "ec2:DescribeInstances",
 "ec2:StopInstances"
 ],
 "Resource": "",
 "Condition": {
 "StringEquals": {
 "ec2:ResourceTag/AutoStop": "true"
 }
 }
 }
 ]
}
```

Budget Handler Role - Limited to necessary actions:
- Lambda invocation (specific function only)
- SNS publish
- Cost Explorer read-only

#### ECS Task Roles

- Task execution role: ECR pull, CloudWatch Logs write
- Task role: S3 access (specific buckets only)

### Best Practices

```bash
# Audit IAM policies
aws iam get-role-policy \
 --role-name cost-optimization-dev-cost-optimizer \
 --policy-name cost-optimizer-policy

# Review trust relationships
aws iam get-role \
 --role-name cost-optimization-dev-cost-optimizer \
 --query 'Role.AssumeRolePolicyDocument'

# Check for overly permissive policies
aws iam simulate-principal-policy \
 --policy-source-arn arn:aws:iam::ACCOUNT:role/cost-optimization-dev-cost-optimizer \
 --action-names ec2:TerminateInstances \
 --resource-arns ""
```

### Recommendations

1. Enable MFA for AWS Console Access
```bash
# Require MFA for sensitive operations
aws iam put-role-policy \
 --role-name AdminRole \
 --policy-name RequireMFA \
 --policy-document file://require-mfa-policy.json
```

2. Use IAM Access Analyzer
```bash
# Create analyzer
aws accessanalyzer create-analyzer \
 --analyzer-name cost-optimization-analyzer \
 --type ACCOUNT

# Review findings
aws accessanalyzer list-findings \
 --analyzer-arn arn:aws:access-analyzer:REGION:ACCOUNT:analyzer/cost-optimization-analyzer
```

3. Rotate IAM Credentials Regularly
```bash
# List access keys older than 90 days
aws iam list-access-keys \
 --user-name your-user \
 --query 'AccessKeyMetadata[?CreateDate<=`2024-08-01`]'
```

## 2. Data Protection

### Encryption at Rest

All data is encrypted at rest:

#### S3 Buckets
- AES-256 encryption enabled by default
- Bucket policies prevent unencrypted uploads

```bash
# Verify S3 encryption
aws s3api get-bucket-encryption \
 --bucket cost-optimization-dev-app-data-ACCOUNT

# Enable encryption if not set
aws s3api put-bucket-encryption \
 --bucket BUCKET_NAME \
 --server-side-encryption-configuration '{
 "Rules": [{
 "ApplyServerSideEncryptionByDefault": {
 "SSEAlgorithm": "AES256"
 },
 "BucketKeyEnabled": true
 }]
 }'
```

#### SNS Topics
- KMS encryption for all topics
- Separate KMS key per environment

```bash
# Verify SNS encryption
aws sns get-topic-attributes \
 --topic-arn TOPIC_ARN \
 --query 'Attributes.KmsMasterKeyId'
```

#### CloudWatch Logs
- Encrypted using AWS managed keys
- Can be upgraded to customer-managed KMS keys

```bash
# Enable KMS encryption for log group
aws logs associate-kms-key \
 --log-group-name /aws/lambda/cost-optimization-dev-cost-optimizer \
 --kms-key-id arn:aws:kms:REGION:ACCOUNT:key/KEY_ID
```

### Encryption in Transit

All data in transit is encrypted:

#### ALB Configuration
- TLS 1.2+ only (when HTTPS configured)
- Strong cipher suites

```hcl
# Add HTTPS listener (recommended for production)
resource "aws_lb_listener" "https" {
 load_balancer_arn = aws_lb.main.arn
 port = "443"
 protocol = "HTTPS"
 ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
 certificate_arn = var.certificate_arn

 default_action {
 type = "forward"
 target_group_arn = aws_lb_target_group.app.arn
 }
}
```

#### VPC Endpoints
For enhanced security, use VPC endpoints:

```hcl
# S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
 vpc_id = module.vpc.vpc_id
 service_name = "com.amazonaws.${var.aws_region}.s3"
 route_table_ids = module.vpc.private_route_table_ids
}

# ECR VPC Endpoints
resource "aws_vpc_endpoint" "ecr_api" {
 vpc_id = module.vpc.vpc_id
 service_name = "com.amazonaws.${var.aws_region}.ecr.api"
 vpc_endpoint_type = "Interface"
 subnet_ids = module.vpc.private_subnet_ids
 security_group_ids = [aws_security_group.vpc_endpoints.id]
}
```

### Secrets Management

Use AWS Secrets Manager for sensitive data:

```bash
# Store database credentials
aws secretsmanager create-secret \
 --name cost-optimization/dev/db-password \
 --secret-string '{"username":"admin","password":"SECURE_PASSWORD"}' \
 --kms-key-id alias/cost-optimization

# Retrieve in Lambda
aws secretsmanager get-secret-value \
 --secret-id cost-optimization/dev/db-password
```

Update Lambda to use Secrets Manager:

```python
import boto3
import json

secrets_client = boto3.client('secretsmanager')

def get_secret(secret_name):
 response = secrets_client.get_secret_value(SecretId=secret_name)
 return json.loads(response['SecretString'])
```

## 3. Infrastructure Protection

### Network Security

#### VPC Configuration
- Private subnets for ECS tasks
- Public subnets for ALB only
- NAT Gateway for outbound internet access

#### Security Groups

ALB Security Group - Restrictive ingress:
```hcl
resource "aws_security_group_rule" "alb_https" {
 type = "ingress"
 from_port = 443
 to_port = 443
 protocol = "tcp"
 cidr_blocks = ["0.0.0.0/0"] # Consider restricting to known IPs
 security_group_id = aws_security_group.alb.id
}
```

ECS Security Group - Only from ALB:
```hcl
resource "aws_security_group_rule" "ecs_from_alb" {
 type = "ingress"
 from_port = var.app_port
 to_port = var.app_port
 protocol = "tcp"
 source_security_group_id = aws_security_group.alb.id
 security_group_id = aws_security_group.ecs_tasks.id
}
```

#### Network ACLs

Add network ACLs for additional protection:

```hcl
resource "aws_network_acl" "private" {
 vpc_id = module.vpc.vpc_id
 subnet_ids = module.vpc.private_subnet_ids

 ingress {
 protocol = "tcp"
 rule_no = 100
 action = "allow"
 cidr_block = module.vpc.vpc_cidr
 from_port = 0
 to_port = 65535
 }

 egress {
 protocol = "tcp"
 rule_no = 100
 action = "allow"
 cidr_block = "0.0.0.0/0"
 from_port = 443
 to_port = 443
 }

 tags = var.tags
}
```

### WAF Protection (Recommended for Production)

```hcl
resource "aws_wafv2_web_acl" "main" {
 name = "${var.project_name}-${var.environment}-waf"
 scope = "REGIONAL"

 default_action {
 allow {}
 }

 rule {
 name = "RateLimitRule"
 priority = 1

 action {
 block {}
 }

 statement {
 rate_based_statement {
 limit = 2000
 aggregate_key_type = "IP"
 }
 }

 visibility_config {
 cloudwatch_metrics_enabled = true
 metric_name = "RateLimitRule"
 sampled_requests_enabled = true
 }
 }

 visibility_config {
 cloudwatch_metrics_enabled = true
 metric_name = "WAFMetrics"
 sampled_requests_enabled = true
 }
}

resource "aws_wafv2_web_acl_association" "main" {
 resource_arn = module.ecs.alb_arn
 web_acl_arn = aws_wafv2_web_acl.main.arn
}
```

## 4. Detective Controls

### CloudTrail Logging

Enable CloudTrail for audit logging:

```hcl
resource "aws_cloudtrail" "main" {
 name = "${var.project_name}-${var.environment}-trail"
 s3_bucket_name = aws_s3_bucket.cloudtrail.id
 include_global_service_events = true
 is_multi_region_trail = true
 enable_log_file_validation = true

 event_selector {
 read_write_type = "All"
 include_management_events = true

 data_resource {
 type = "AWS::S3::Object"
 values = ["arn:aws:s3:::${aws_s3_bucket.app_data.id}/"]
 }

 data_resource {
 type = "AWS::Lambda::Function"
 values = ["arn:aws:lambda:::function/"]
 }
 }

 tags = var.tags
}
```

### GuardDuty

Enable GuardDuty for threat detection:

```bash
# Enable GuardDuty
aws guardduty create-detector \
 --enable \
 --finding-publishing-frequency FIFTEEN_MINUTES

# Get detector ID
DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)

# Create SNS topic for findings
aws guardduty create-publishing-destination \
 --detector-id $DETECTOR_ID \
 --destination-type SNS \
 --destination-properties DestinationArn=arn:aws:sns:REGION:ACCOUNT:security-alerts
```

### AWS Config

Enable AWS Config for compliance monitoring:

```hcl
resource "aws_config_configuration_recorder" "main" {
 name = "${var.project_name}-${var.environment}-recorder"
 role_arn = aws_iam_role.config.arn

 recording_group {
 all_supported = true
 }
}

resource "aws_config_configuration_recorder_status" "main" {
 name = aws_config_configuration_recorder.main.name
 is_enabled = true
}
```

### Security Hub

Enable Security Hub for centralized security findings:

```bash
# Enable Security Hub
aws securityhub enable-security-hub

# Enable standards
aws securityhub batch-enable-standards \
 --standards-subscription-requests '[
 {"StandardsArn": "arn:aws:securityhub:REGION::standards/aws-foundational-security-best-practices/v/1.0.0"},
 {"StandardsArn": "arn:aws:securityhub:REGION::standards/cis-aws-foundations-benchmark/v/1.2.0"}
 ]'
```

## 5. Incident Response

### Automated Response

Create Lambda function for automated incident response:

```python
def lambda_handler(event, context):
 """Respond to security events"""
 
 # Parse GuardDuty finding
 finding = event['detail']
 severity = finding['severity']
 finding_type = finding['type']
 
 if severity >= 7: # High or Critical
 # Isolate compromised instance
 if 'UnauthorizedAccess' in finding_type:
 instance_id = finding['resource']['instanceDetails']['instanceId']
 isolate_instance(instance_id)
 
 # Send alert
 send_alert(finding)
 
 # Create incident ticket
 create_incident(finding)

def isolate_instance(instance_id):
 """Isolate EC2 instance by changing security group"""
 ec2 = boto3.client('ec2')
 
 # Create isolation security group
 sg = ec2.create_security_group(
 GroupName=f'isolation-{instance_id}',
 Description='Isolation security group',
 VpcId=get_vpc_id()
 )
 
 # Remove all rules (deny all traffic)
 ec2.modify_instance_attribute(
 InstanceId=instance_id,
 Groups=[sg['GroupId']]
 )
```

### Incident Response Playbooks

#### Compromised IAM Credentials

1. Immediate Actions
```bash
# Disable access key
aws iam update-access-key \
 --access-key-id AKIAIOSFODNN7EXAMPLE \
 --status Inactive \
 --user-name compromised-user

# Revoke active sessions
aws iam delete-login-profile --user-name compromised-user
```

2. Investigation
```bash
# Review CloudTrail logs
aws cloudtrail lookup-events \
 --lookup-attributes AttributeKey=Username,AttributeValue=compromised-user \
 --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
 --max-results 50
```

3. Remediation
```bash
# Create new credentials
aws iam create-access-key --user-name compromised-user

# Update applications with new credentials
# Rotate secrets in Secrets Manager
```

#### Unauthorized Resource Access

1. Identify affected resources
```bash
# Check GuardDuty findings
aws guardduty list-findings \
 --detector-id $DETECTOR_ID \
 --finding-criteria '{"Criterion":{"severity":{"Gte":7}}}'
```

2. Isolate resources
```bash
# Modify security groups
# Disable IAM roles
# Stop instances if necessary
```

3. Analyze and remediate
```bash
# Review VPC Flow Logs
# Check CloudWatch Logs
# Update security groups
```

## Security Checklist

### Pre-Deployment
- [ ] Review IAM policies for least privilege
- [ ] Enable encryption for all data stores
- [ ] Configure VPC with private subnets
- [ ] Set up security groups with minimal access
- [ ] Enable CloudTrail logging
- [ ] Configure AWS Config rules
- [ ] Set up GuardDuty
- [ ] Enable Security Hub

### Post-Deployment
- [ ] Verify encryption is enabled
- [ ] Test IAM permissions
- [ ] Review security group rules
- [ ] Enable MFA for console access
- [ ] Set up automated security scanning
- [ ] Configure incident response procedures
- [ ] Document security architecture
- [ ] Train team on security practices

### Ongoing
- [ ] Regular security audits
- [ ] Review CloudTrail logs weekly
- [ ] Monitor GuardDuty findings
- [ ] Update security patches
- [ ] Rotate credentials quarterly
- [ ] Review IAM policies monthly
- [ ] Test incident response procedures
- [ ] Update security documentation

## Compliance

### GDPR Considerations
- Data encryption at rest and in transit
- Data retention policies (S3 lifecycle)
- Right to deletion (S3 object deletion)
- Audit logging (CloudTrail)

### HIPAA Considerations
- Enable encryption for all services
- Use AWS HIPAA-eligible services
- Sign BAA with AWS
- Implement access controls
- Enable audit logging

### PCI DSS Considerations
- Network segmentation (VPC)
- Encryption (TLS, KMS)
- Access control (IAM)
- Logging and monitoring (CloudWatch, CloudTrail)
- Regular security testing

## Security Tools

### Automated Security Scanning

```bash
# Install and run Prowler
git clone https://github.com/prowler-cloud/prowler
cd prowler
./prowler aws

# Run specific checks
./prowler aws -c check11,check12,check13
```

### Vulnerability Scanning

```bash
# Scan container images
aws ecr start-image-scan \
 --repository-name app \
 --image-id imageTag=latest

# Get scan results
aws ecr describe-image-scan-findings \
 --repository-name app \
 --image-id imageTag=latest
```

## Additional Resources

- [AWS Security Best Practices](https://aws.amazon.com/security/best-practices/)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
