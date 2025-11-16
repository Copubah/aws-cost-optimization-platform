# AWS Cost Optimization & Reliability Platform

A production-ready AWS infrastructure project that balances cost optimization with high reliability using automated controls, monitoring, and safeguards.

## Architecture Overview

This solution implements a comprehensive cost optimization strategy while maintaining system reliability through:

- Cost Controls: AWS Budgets with automated responses, scheduled Lambda functions for resource optimization
- Reliability Safeguards: CloudWatch alarms for critical metrics, auto-scaling policies, multi-AZ deployments
- Automation: Lambda functions triggered by budget alerts and schedules to optimize costs safely
- Notifications: SNS topics for budget alerts, CloudWatch alarms, and operational events
- Workload: Sample ECS-based application with auto-scaling and cost-optimized configurations

### Key Components

1. Budget Management: Multi-tier budgets (monthly, service-specific) with threshold alerts
2. Cost Automation: Safe shutdown of non-production resources, ECS task scaling, S3 lifecycle policies
3. Reliability Monitoring: CPU, memory, latency, error rate, and storage alarms
4. Tagging Strategy: Consistent tagging for cost allocation and automation targeting
5. Security: IAM least privilege, encryption at rest/transit, audit logging

## AWS Well-Architected Framework Alignment

### Cost Optimization Pillar
- Practice Cloud Financial Management: Budgets with alerts and automated responses
- Expenditure Awareness: CloudWatch dashboards and cost allocation tags
- Cost-Effective Resources: Right-sized instances, Spot instances for non-critical workloads
- Manage Demand: Auto-scaling based on actual usage patterns
- Optimize Over Time: Automated lifecycle policies and scheduled resource optimization

### Reliability Pillar
- Foundations: Service quotas monitoring, network topology with redundancy
- Workload Architecture: Multi-AZ deployments, health checks, graceful degradation
- Change Management: Automated monitoring of deployments, rollback capabilities
- Failure Management: CloudWatch alarms, automated recovery, backup strategies

## Project Structure

```
.
 README.md
 terraform/
 main.tf # Root module orchestration
 variables.tf # Global variables
 outputs.tf # Stack outputs
 terraform.tfvars.example # Example configuration
 modules/
 budgets/ # AWS Budgets configuration
 sns/ # SNS topics and subscriptions
 iam/ # IAM roles and policies
 lambda/ # Lambda functions for automation
 cloudwatch/ # CloudWatch alarms and dashboards
 ecs/ # ECS cluster and services
 vpc/ # VPC and networking
 s3/ # S3 buckets with lifecycle policies
 environments/
 dev/
 staging/
 prod/
 lambda/
 cost_optimizer/ # Cost optimization functions
 stop_dev_instances.py
 scale_ecs_tasks.py
 requirements.txt
 notifications/ # Notification handlers
 budget_alert_handler.py
 docs/
 ARCHITECTURE.md
 DEPLOYMENT.md
 TESTING.md
 SECURITY.md
```

## Quick Start

### Prerequisites
- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- Python 3.11+ (for Lambda development)

### Deployment

1. Clone and configure:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
```

2. Initialize and deploy:
```bash
terraform init
terraform plan
terraform apply
```

3. Verify deployment:
```bash
terraform output
```

## Cost Optimization Features

### Automated Actions
- Development Instance Management: Automatically stop EC2/RDS instances tagged as 'dev' outside business hours
- ECS Task Scaling: Scale down non-production ECS tasks during low-usage periods
- S3 Lifecycle Policies: Transition objects to cheaper storage classes, expire old data
- Spot Instance Integration: Use Spot instances for fault-tolerant workloads

### Budget Alerts
- Monthly budget with 50%, 80%, 100%, 120% thresholds
- Service-specific budgets (EC2, RDS, S3)
- Automated Lambda triggers at critical thresholds
- SNS notifications to operations team

## Reliability Features

### CloudWatch Alarms
- Application Health: ECS task count, CPU/memory utilization, error rates
- Database: RDS CPU, storage space, connection count, replica lag
- Network: ALB target health, latency, 5xx errors
- Infrastructure: EC2 status checks, EBS volume metrics

### High Availability
- Multi-AZ ECS service deployment
- Application Load Balancer with health checks
- Auto-scaling based on CPU and memory metrics
- RDS Multi-AZ with automated backups

## Security Considerations

- IAM roles with least privilege access
- Encryption at rest (EBS, RDS, S3)
- Encryption in transit (TLS/SSL)
- VPC with private subnets for workloads
- CloudTrail logging enabled
- Secrets Manager for sensitive data
- Security groups with minimal required access

## Monitoring & Observability

- CloudWatch Logs for all Lambda functions
- ECS container insights enabled
- Custom CloudWatch dashboard
- X-Ray tracing for distributed applications
- Cost and Usage Reports enabled

## Testing

See [TESTING.md](docs/TESTING.md) for comprehensive testing procedures including:
- Budget alert validation
- Cost automation testing
- Reliability alarm verification
- Failover testing
- Security validation

## Contributing

Follow AWS Well-Architected Framework best practices and ensure all changes include:
- Terraform formatting (`terraform fmt`)
- Validation (`terraform validate`)
- Security scanning
- Documentation updates

## License

MIT License - See LICENSE file for details
