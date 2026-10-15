import json
import os
import boto3
from datetime import datetime, timezone

dynamodb = boto3.resource('dynamodb')
iam = boto3.client('iam')
sns = boto3.client('sns')
events = boto3.client('events')

TABLE_NAME = 'SecureCorp-JITRequests'
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    request_id = event.get('requestId')
    
    if not request_id:
        return {'statusCode': 400, 'body': 'requestId is required'}
    
    table = dynamodb.Table(TABLE_NAME)
    response = table.get_item(Key={'requestId': request_id})
    
    if 'Item' not in response:
        return {'statusCode': 404, 'body': f'Request {request_id} not found'}
    
    request = response['Item']
    
    if request['status'] != 'APPROVED':
        return {'statusCode': 400, 'body': 'Request is not in APPROVED state'}
    
    requester = request['requester']
    requested_policy = request['requestedPolicy']
    
    # Detach policy from user
    try:
        iam.detach_user_policy(
            UserName=requester,
            PolicyArn=requested_policy
        )
    except Exception as e:
        print(f'Warning: Could not detach policy: {str(e)}')
    
    # Update DynamoDB record
    table.update_item(
        Key={'requestId': request_id},
        UpdateExpression='SET #s = :s, revokedAt = :r',
        ExpressionAttributeNames={'#s': 'status'},
        ExpressionAttributeValues={
            ':s': 'REVOKED',
            ':r': datetime.now(timezone.utc).isoformat()
        }
    )
    
    # Clean up EventBridge rule
    rule_name = f'JIT-Revoke-{request_id[:8]}'
    try:
        events.remove_targets(Rule=rule_name, Ids=['1'])
        events.delete_rule(Name=rule_name)
    except Exception as e:
        print(f'Warning: Could not clean up EventBridge rule: {str(e)}')
    
    # Send revocation notification
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f'JIT Access REVOKED - {request_id[:8]}',
        Message=f'''
JIT Access Automatically Revoked

Request ID: {request_id}
User: {requester}
Policy: {requested_policy}
Revoked At: {datetime.now(timezone.utc).isoformat()}

Access has been removed per the approved time window.
        '''
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'requestId': request_id,
            'status': 'REVOKED'
        })
    }
