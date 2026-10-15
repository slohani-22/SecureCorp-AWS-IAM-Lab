import json
import os
import boto3
import uuid
from datetime import datetime, timezone

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

TABLE_NAME = 'SecureCorp-JITRequests'
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    # Extract request details from the event
    requester = event.get('requester', 'unknown')
    requested_policy = event.get('requested_policy', 'arn:aws:iam::aws:policy/ReadOnlyAccess')
    duration_minutes = event.get('duration_minutes', 60)
    justification = event.get('justification', 'No justification provided')
    
    # Generate unique request ID
    request_id = str(uuid.uuid4())
    timestamp = datetime.now(timezone.utc).isoformat()
    
    # Store request in DynamoDB
    table = dynamodb.Table(TABLE_NAME)
    table.put_item(
        Item={
            'requestId': request_id,
            'requester': requester,
            'requestedPolicy': requested_policy,
            'durationMinutes': duration_minutes,
            'justification': justification,
            'status': 'PENDING',
            'createdAt': timestamp,
            'expiresAt': 'TBD'
        }
    )
    
    # Send approval notification via SNS
    approval_message = f"""
SecureCorp JIT Access Request

Request ID: {request_id}
Requester: {requester}
Requested Policy: {requested_policy}
Duration: {duration_minutes} minutes
Justification: {justification}
Submitted: {timestamp}

To APPROVE this request, invoke the SecureCorp-JITAccessGrant Lambda with:
{{
    "requestId": "{request_id}",
    "action": "APPROVE"
}}

To DENY this request, invoke with:
{{
    "requestId": "{request_id}",
    "action": "DENY"
}}
    """
    
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f'JIT Access Request - {request_id[:8]} - PENDING APPROVAL',
        Message=approval_message
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'requestId': request_id,
            'status': 'PENDING',
            'message': 'Access request submitted. Approval notification sent.'
        })
    }
