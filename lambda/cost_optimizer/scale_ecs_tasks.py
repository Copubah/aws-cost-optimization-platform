"""
ECS Task Scaling Module
Scales ECS tasks based on cost optimization requirements
"""
import boto3
from typing import Dict, List, Any

ecs_client = boto3.client('ecs')


def scale_ecs_service(cluster_name: str, service_name: str, desired_count: int, dry_run: bool = False) -> Dict[str, Any]:
    """
    Scale an ECS service to the specified task count
    
    Args:
        cluster_name: ECS cluster name
        service_name: ECS service name
        desired_count: Desired number of tasks
        dry_run: If True, only simulate the action
        
    Returns:
        Dictionary with scaling results
    """
    result = {
        'cluster': cluster_name,
        'service': service_name,
        'previous_count': 0,
        'new_count': desired_count,
        'success': False
    }
    
    try:
        # Get current service configuration
        response = ecs_client.describe_services(
            cluster=cluster_name,
            services=[service_name]
        )
        
        if not response['services']:
            result['error'] = f"Service {service_name} not found"
            return result
        
        service = response['services'][0]
        result['previous_count'] = service['desiredCount']
        
        # Check if scaling is needed
        if result['previous_count'] == desired_count:
            result['message'] = "No scaling needed"
            result['success'] = True
            return result
        
        # Perform scaling
        if not dry_run:
            ecs_client.update_service(
                cluster=cluster_name,
                service=service_name,
                desiredCount=desired_count
            )
            result['success'] = True
            result['message'] = f"Scaled from {result['previous_count']} to {desired_count} tasks"
        else:
            result['success'] = True
            result['message'] = f"DRY RUN: Would scale from {result['previous_count']} to {desired_count} tasks"
        
    except Exception as e:
        result['error'] = str(e)
    
    return result


def get_scalable_services(environment: str) -> List[Dict[str, str]]:
    """
    Get list of ECS services that can be scaled for cost optimization
    
    Args:
        environment: Environment name (dev, staging, prod)
        
    Returns:
        List of services with cluster and service names
    """
    services = []
    
    try:
        # List all clusters
        clusters_response = ecs_client.list_clusters()
        
        for cluster_arn in clusters_response['clusterArns']:
            cluster_name = cluster_arn.split('/')[-1]
            
            # List services in cluster
            services_response = ecs_client.list_services(cluster=cluster_arn)
            
            if not services_response['serviceArns']:
                continue
            
            # Describe services to get tags
            services_detail = ecs_client.describe_services(
                cluster=cluster_arn,
                services=services_response['serviceArns']
            )
            
            for service in services_detail['services']:
                tags = {tag['key']: tag['value'] for tag in service.get('tags', [])}
                
                # Check if service is in the target environment and has AutoScale tag
                if (tags.get('Environment', '').lower() == environment.lower() and
                    tags.get('AutoScale', '').lower() == 'true'):
                    services.append({
                        'cluster': cluster_name,
                        'service': service['serviceName'],
                        'current_count': service['desiredCount']
                    })
    
    except Exception as e:
        print(f"Error getting scalable services: {e}")
    
    return services
