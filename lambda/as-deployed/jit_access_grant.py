import json
import os
import boto3
from datetime import datetime, timezone, timedelta

dynamodb = boto3.resource('dynamodb')
iam = boto3.client('iam')
events = boto3.client('events')
sns = boto3.client('sns')
lambda_client = boto3.client('lambda')

TABLE_NAME = 'SecureCorp-JITRequests'
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
REVOKE_LAMBDA_ARN = os.environ['REVOKE_LAMBDA_ARN']

def lambda_handler(event, context):
    request_id = event.get('requestId')
    action = event.get('action', 'APPROVE')
    
    if not request_id:
        return {'statusCode': 400, 'body': 'requestId is required'}
    
    # Get request from DynamoDB
    table = dynamodb.Table(TABLE_NAME)
    response = table.get_item(Key={'requestId': request_id})
    
    if 'Item' not in response:
        return {'statusCode': 404, 'body': f'Request {request_id} not found'}
    
    request = response['Item']
    
    if request['status'] != 'PENDING':
        return {'statusCode': 400, 'body': f'Request is already {request["status"]}'}
    
    if action == 'DENY':
        table.update_item(
            Key={'requestId': request_id},
            UpdateExpression='SET #s = :s',
            ExpressionAttributeNames={'#s': 'status'},
            ExpressionAttributeValues={':s': 'DENIED'}
        )
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f'JIT Access Request DENIED - {request_id[:8]}',
            Message=f'Access request {request_id} for {request["requester"]} has been DENIED.'
        )
        return {'statusCode': 200, 'body': f'Request {request_id} denied'}
    
    # APPROVE — attach policy to user
    requester = request['requester']
    requested_policy = request['requestedPolicy']
    duration_minutes = int(request['durationMinutes'])
    
    expires_at = (datetime.now(timezone.utc) + timedelta(minutes=duration_minutes)).isoformat()
    
    try:
        iam.attach_user_policy(
            UserName=requester,
            PolicyArn=requested_policy
        )
    except Exception as e:
        return {'statusCode': 500, 'body': f'Failed to attach policy: {str(e)}'}
    
    # Update DynamoDB with approved status and expiry
    table.update_item(
        Key={'requestId': request_id},
        UpdateExpression='SET #s = :s, expiresAt = :e, approvedAt = :a',
        ExpressionAttributeNames={'#s': 'status'},
        ExpressionAttributeValues={
            ':s': 'APPROVED',
            ':e': expires_at,
            ':a': datetime.now(timezone.utc).isoformat()
        }
    )
    
    # Schedule revocation via EventBridge
    rule_name = f'JIT-Revoke-{request_id[:8]}'
    
    # Create EventBridge rule to fire at expiry time
    events.put_rule(
        Name=rule_name,
        ScheduleExpression=f'rate({duration_minutes} minutes)',
        State='ENABLED',
        Description=f'Auto-revoke JIT access for request {request_id}'
    )
    
    # Send approval notification
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f'JIT Access APPROVED - {request_id[:8]}',
        Message=f'''
JIT Access Approved

Request ID: {request_id}
User: {requester}
Policy: {requested_policy}
Expires: {expires_at}

Access will be automatically revoked at expiry.
        '''
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'requestId': request_id,
            'status': 'APPROVED',
            'expiresAt': expires_at
        })
    }
