"""
Budget Alert Handler Lambda Function
Processes AWS Budget alerts and triggers appropriate cost optimization actions
"""
import json
import os
import boto3
from datetime import datetime, timezone
from typing import Dict, Any

lambda_client = boto3.client('lambda')
sns_client = boto3.client('sns')
ce_client = boto3.client('ce')

ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
COST_OPTIMIZER_LAMBDA_ARN = os.environ.get('COST_OPTIMIZER_LAMBDA_ARN')
OPERATIONS_SNS_TOPIC_ARN = os.environ.get('OPERATIONS_SNS_TOPIC_ARN')


def lambda_handler(event, context):
    """Main Lambda handler for budget alerts"""
    print(f"Budget alert received: {json.dumps(event)}")
    
    try:
        # Parse SNS message
        if 'Records' in event:
            for record in event['Records']:
                if record.get('EventSource') == 'aws:sns':
                    message = json.loads(record['Sns']['Message'])
                    process_budget_alert(message)
        else:
            # Direct invocation for testing
            process_budget_alert(event)
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Budget alert processed successfully'})
        }
    
    except Exception as e:
        error_msg = f"Error processing budget alert: {str(e)}"
        print(error_msg)
        send_error_notification(error_msg)
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_msg})
        }


def process_budget_alert(message: Dict[str, Any]):
    """Process budget alert and take appropriate action"""
    print(f"Processing budget alert: {json.dumps(message)}")
    
    # Extract budget information
    budget_name = message.get('budgetName', 'Unknown')
    threshold = message.get('threshold', 0)
    actual_spend = message.get('actualSpend', 0)
    forecasted_spend = message.get('forecastedSpend', 0)
    
    print(f"Budget: {budget_name}")
    print(f"Threshold: {threshold}%")
    print(f"Actual Spend: ${actual_spend}")
    print(f"Forecasted Spend: ${forecasted_spend}")
    
    # Get current cost details
    cost_details = get_current_costs()
    
    # Determine action based on threshold
    action_taken = None
    
    if threshold >= 100:
        # Critical: Budget exceeded
        print("CRITICAL: Budget exceeded! Triggering aggressive cost optimization...")
        action_taken = trigger_cost_optimization(aggressive=True)
    elif threshold >= 80:
        # Warning: Approaching budget limit
        print("WARNING: Approaching budget limit. Triggering standard cost optimization...")
        action_taken = trigger_cost_optimization(aggressive=False)
    else:
        # Info: Early warning
        print("INFO: Budget threshold reached. Monitoring only.")
        action_taken = "monitoring_only"
    
    # Send detailed notification
    send_budget_notification(
        budget_name=budget_name,
        threshold=threshold,
        actual_spend=actual_spend,
        forecasted_spend=forecasted_spend,
        cost_details=cost_details,
        action_taken=action_taken
    )


def get_current_costs() -> Dict[str, Any]:
    """Get current month's cost breakdown by service"""
    try:
        # Get current month's costs
        now = datetime.now(timezone.utc)
        start_date = now.replace(day=1).strftime('%Y-%m-%d')
        end_date = now.strftime('%Y-%m-%d')
        
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date,
                'End': end_date
            },
            Granularity='MONTHLY',
            Metrics=['UnblendedCost'],
            GroupBy=[
                {
                    'Type': 'DIMENSION',
                    'Key': 'SERVICE'
                }
            ]
        )
        
        costs_by_service = {}
        total_cost = 0
        
        for result in response['ResultsByTime']:
            for group in result['Groups']:
                service = group['Keys'][0]
                cost = float(group['Metrics']['UnblendedCost']['Amount'])
                costs_by_service[service] = cost
                total_cost += cost
        
        # Sort by cost descending
        sorted_costs = dict(sorted(costs_by_service.items(), key=lambda x: x[1], reverse=True))
        
        return {
            'total': round(total_cost, 2),
            'by_service': {k: round(v, 2) for k, v in list(sorted_costs.items())[:10]},
            'period': f"{start_date} to {end_date}"
        }
    
    except Exception as e:
        print(f"Error getting cost details: {e}")
        return {'error': str(e)}


def trigger_cost_optimization(aggressive: bool = False) -> str:
    """Trigger cost optimizer Lambda function"""
    if not COST_OPTIMIZER_LAMBDA_ARN:
        print("Cost optimizer Lambda ARN not configured")
        return "not_configured"
    
    # Don't trigger for production environment
    if ENVIRONMENT == 'prod':
        print("Skipping cost optimization for production environment")
        return "skipped_production"
    
    try:
        payload = {
            'action': 'stop_dev_instances',
            'dry_run': False,
            'triggered_by': 'budget_alert',
            'aggressive': aggressive
        }
        
        response = lambda_client.invoke(
            FunctionName=COST_OPTIMIZER_LAMBDA_ARN,
            InvocationType='Event',  # Async invocation
            Payload=json.dumps(payload)
        )
        
        print(f"Cost optimizer invoked: {response['StatusCode']}")
        return "cost_optimizer_triggered"
    
    except Exception as e:
        print(f"Error invoking cost optimizer: {e}")
        return f"error: {str(e)}"


def send_budget_notification(
    budget_name: str,
    threshold: float,
    actual_spend: float,
    forecasted_spend: float,
    cost_details: Dict[str, Any],
    action_taken: str
):
    """Send detailed budget notification"""
    if not OPERATIONS_SNS_TOPIC_ARN:
        print("Operations SNS topic ARN not configured")
        return
    
    # Determine severity
    if threshold >= 100:
        severity = "CRITICAL"
    elif threshold >= 80:
        severity = "WARNING"
    else:
        severity = "INFO"
    
    subject = f"{severity}: Budget Alert - {budget_name} ({threshold}%)"
    
    message = f"""
AWS Budget Alert
================
Severity: {severity}
Environment: {ENVIRONMENT}
Budget Name: {budget_name}
Threshold: {threshold}%
Timestamp: {datetime.now(timezone.utc).isoformat()}

Spending Summary:
-----------------
Actual Spend: ${actual_spend:.2f}
Forecasted Spend: ${forecasted_spend:.2f}

"""
    
    if 'total' in cost_details:
        message += f"""
Current Month Costs:
--------------------
Total: ${cost_details['total']:.2f}
Period: {cost_details.get('period', 'N/A')}

Top Services by Cost:
"""
        for service, cost in cost_details.get('by_service', {}).items():
            message += f"  - {service}: ${cost:.2f}\n"
    
    message += f"""

Action Taken:
-------------
{action_taken.replace('_', ' ').title()}

Recommendations:
----------------
"""
    
    if threshold >= 100:
        message += """
1. Review and stop non-essential resources immediately
2. Check for unexpected resource usage or anomalies
3. Consider increasing budget or optimizing workloads
4. Review cost allocation tags for accuracy
"""
    elif threshold >= 80:
        message += """
1. Review current resource utilization
2. Identify opportunities for rightsizing
3. Consider reserved instances for predictable workloads
4. Enable cost anomaly detection
"""
    else:
        message += """
1. Continue monitoring spending trends
2. Review cost optimization opportunities
3. Ensure proper tagging for cost allocation
"""
    
    try:
        sns_client.publish(
            TopicArn=OPERATIONS_SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        print("Budget notification sent successfully")
    except Exception as e:
        print(f"Error sending notification: {e}")


def send_error_notification(error_message: str):
    """Send error notification"""
    if not OPERATIONS_SNS_TOPIC_ARN:
        return
    
    try:
        sns_client.publish(
            TopicArn=OPERATIONS_SNS_TOPIC_ARN,
            Subject=f"ERROR: Budget Alert Handler - {ENVIRONMENT}",
            Message=f"""
Budget Alert Handler Error
==========================
Environment: {ENVIRONMENT}
Timestamp: {datetime.now(timezone.utc).isoformat()}

Error: {error_message}

Please investigate the budget alert handler Lambda function.
"""
        )
    except Exception as e:
        print(f"Error sending error notification: {e}")
