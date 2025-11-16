"""
Cost Optimizer Lambda Function
Safely stops non-production EC2 and RDS instances to reduce costs
"""
import json
import os
import boto3
from datetime import datetime, timezone
from typing import Dict, List, Any

ec2_client = boto3.client('ec2')
rds_client = boto3.client('rds')
ecs_client = boto3.client('ecs')
sns_client = boto3.client('sns')

ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
ENABLE_AUTOMATION = os.environ.get('ENABLE_COST_AUTOMATION', 'true').lower() == 'true'


def lambda_handler(event, context):
    """Main Lambda handler"""
    print(f"Event received: {json.dumps(event)}")
    
    action = event.get('action', 'stop_dev_instances')
    dry_run = event.get('dry_run', False)
    
    results = {
        'timestamp': datetime.now(timezone.utc).isoformat(),
        'environment': ENVIRONMENT,
        'action': action,
        'dry_run': dry_run,
        'automation_enabled': ENABLE_AUTOMATION
    }
    
    if not ENABLE_AUTOMATION and not dry_run:
        message = "Cost automation is disabled. Set ENABLE_COST_AUTOMATION=true to enable."
        print(message)
        results['message'] = message
        return {
            'statusCode': 200,
            'body': json.dumps(results)
        }
    
    try:
        if action == 'stop_dev_instances':
            results['ec2'] = stop_dev_ec2_instances(dry_run)
            results['rds'] = stop_dev_rds_instances(dry_run)
        elif action == 'scale_ecs_tasks':
            results['ecs'] = scale_down_ecs_tasks(dry_run)
        else:
            results['error'] = f"Unknown action: {action}"
        
        # Send notification
        send_notification(results)
        
        return {
            'statusCode': 200,
            'body': json.dumps(results)
        }
    
    except Exception as e:
        error_msg = f"Error in cost optimizer: {str(e)}"
        print(error_msg)
        results['error'] = error_msg
        send_notification(results, is_error=True)
        
        return {
            'statusCode': 500,
            'body': json.dumps(results)
        }


def stop_dev_ec2_instances(dry_run: bool = False) -> Dict[str, Any]:
    """Stop EC2 instances tagged for auto-stop"""
    print("Checking EC2 instances for cost optimization...")
    
    # Find instances with AutoStop=true tag and not in production
    filters = [
        {'Name': 'tag:AutoStop', 'Values': ['true']},
        {'Name': 'instance-state-name', 'Values': ['running']}
    ]
    
    # Additional safety: exclude production environment
    if ENVIRONMENT != 'prod':
        filters.append({'Name': 'tag:Environment', 'Values': [ENVIRONMENT]})
    
    response = ec2_client.describe_instances(Filters=filters)
    
    instances_to_stop = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
            
            # Safety check: never stop production instances
            if tags.get('Environment', '').lower() == 'prod':
                print(f"Skipping production instance: {instance_id}")
                continue
            
            instances_to_stop.append({
                'id': instance_id,
                'name': tags.get('Name', 'N/A'),
                'environment': tags.get('Environment', 'N/A'),
                'type': instance['InstanceType']
            })
    
    result = {
        'instances_found': len(instances_to_stop),
        'instances': instances_to_stop,
        'stopped': []
    }
    
    if instances_to_stop and not dry_run:
        instance_ids = [inst['id'] for inst in instances_to_stop]
        try:
            ec2_client.stop_instances(InstanceIds=instance_ids)
            result['stopped'] = instance_ids
            print(f"Stopped {len(instance_ids)} EC2 instances: {instance_ids}")
        except Exception as e:
            result['error'] = str(e)
            print(f"Error stopping instances: {e}")
    
    return result


def stop_dev_rds_instances(dry_run: bool = False) -> Dict[str, Any]:
    """Stop RDS instances tagged for auto-stop"""
    print("Checking RDS instances for cost optimization...")
    
    response = rds_client.describe_db_instances()
    
    instances_to_stop = []
    for db_instance in response['DBInstances']:
        db_id = db_instance['DBInstanceIdentifier']
        status = db_instance['DBInstanceStatus']
        
        # Only consider available instances
        if status != 'available':
            continue
        
        # Get tags
        arn = db_instance['DBInstanceArn']
        tags_response = rds_client.list_tags_for_resource(ResourceName=arn)
        tags = {tag['Key']: tag['Value'] for tag in tags_response['TagList']}
        
        # Check if instance should be stopped
        auto_stop = tags.get('AutoStop', '').lower() == 'true'
        environment = tags.get('Environment', '').lower()
        
        # Safety check: never stop production or multi-AZ instances
        if environment == 'prod' or db_instance.get('MultiAZ', False):
            print(f"Skipping RDS instance: {db_id} (prod or multi-AZ)")
            continue
        
        if auto_stop and environment == ENVIRONMENT.lower():
            instances_to_stop.append({
                'id': db_id,
                'engine': db_instance['Engine'],
                'environment': environment,
                'class': db_instance['DBInstanceClass']
            })
    
    result = {
        'instances_found': len(instances_to_stop),
        'instances': instances_to_stop,
        'stopped': []
    }
    
    if instances_to_stop and not dry_run:
        for instance in instances_to_stop:
            try:
                rds_client.stop_db_instance(DBInstanceIdentifier=instance['id'])
                result['stopped'].append(instance['id'])
                print(f"Stopped RDS instance: {instance['id']}")
            except Exception as e:
                print(f"Error stopping RDS instance {instance['id']}: {e}")
                if 'error' not in result:
                    result['error'] = []
                result['error'].append(f"{instance['id']}: {str(e)}")
    
    return result


def scale_down_ecs_tasks(dry_run: bool = False) -> Dict[str, Any]:
    """Scale down ECS services in non-production environments"""
    print("Checking ECS services for cost optimization...")
    
    # Safety check: never scale production
    if ENVIRONMENT == 'prod':
        return {
            'message': 'Skipping ECS scaling for production environment',
            'services_scaled': []
        }
    
    result = {
        'services_found': 0,
        'services_scaled': []
    }
    
    try:
        # List all clusters
        clusters_response = ecs_client.list_clusters()
        
        for cluster_arn in clusters_response['clusterArns']:
            # List services in cluster
            services_response = ecs_client.list_services(cluster=cluster_arn)
            
            if not services_response['serviceArns']:
                continue
            
            # Describe services
            services_detail = ecs_client.describe_services(
                cluster=cluster_arn,
                services=services_response['serviceArns']
            )
            
            for service in services_detail['services']:
                service_name = service['serviceName']
                current_count = service['desiredCount']
                
                # Get service tags
                tags = {tag['key']: tag['value'] for tag in service.get('tags', [])}
                environment = tags.get('Environment', '').lower()
                auto_scale = tags.get('AutoScale', '').lower() == 'true'
                
                # Only scale services in current environment with AutoScale tag
                if environment != ENVIRONMENT.lower() or not auto_scale:
                    continue
                
                result['services_found'] += 1
                
                # Scale down to minimum (1 task) if currently running more
                if current_count > 1 and not dry_run:
                    try:
                        ecs_client.update_service(
                            cluster=cluster_arn,
                            service=service_name,
                            desiredCount=1
                        )
                        result['services_scaled'].append({
                            'cluster': cluster_arn.split('/')[-1],
                            'service': service_name,
                            'previous_count': current_count,
                            'new_count': 1
                        })
                        print(f"Scaled down {service_name} from {current_count} to 1 task")
                    except Exception as e:
                        print(f"Error scaling service {service_name}: {e}")
    
    except Exception as e:
        result['error'] = str(e)
        print(f"Error in ECS scaling: {e}")
    
    return result


def send_notification(results: Dict[str, Any], is_error: bool = False):
    """Send notification via SNS"""
    if not SNS_TOPIC_ARN:
        print("SNS topic ARN not configured, skipping notification")
        return
    
    subject = f"{'ERROR: ' if is_error else ''}Cost Optimization Report - {ENVIRONMENT}"
    
    message = f"""
Cost Optimization Report
========================
Environment: {results.get('environment')}
Timestamp: {results.get('timestamp')}
Action: {results.get('action')}
Dry Run: {results.get('dry_run')}

"""
    
    if 'ec2' in results:
        ec2 = results['ec2']
        message += f"""
EC2 Instances:
- Found: {ec2.get('instances_found', 0)}
- Stopped: {len(ec2.get('stopped', []))}
"""
        if ec2.get('stopped'):
            message += f"- Instance IDs: {', '.join(ec2['stopped'])}\n"
    
    if 'rds' in results:
        rds = results['rds']
        message += f"""
RDS Instances:
- Found: {rds.get('instances_found', 0)}
- Stopped: {len(rds.get('stopped', []))}
"""
        if rds.get('stopped'):
            message += f"- Instance IDs: {', '.join(rds['stopped'])}\n"
    
    if 'ecs' in results:
        ecs = results['ecs']
        message += f"""
ECS Services:
- Found: {ecs.get('services_found', 0)}
- Scaled: {len(ecs.get('services_scaled', []))}
"""
    
    if results.get('error'):
        message += f"\nERROR: {results['error']}\n"
    
    try:
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        print("Notification sent successfully")
    except Exception as e:
        print(f"Error sending notification: {e}")
