import json
import os
import boto3

iam = boto3.client('iam')
sns = boto3.client('sns')

SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

DEPARTMENT_GROUP_MAP = {
    'IT': 'SecureCorp-Admins',
    'Security': 'SecureCorp-Security',
    'Development': 'SecureCorp-Developers',
    'Finance': 'SecureCorp-Finance'
}

def lambda_handler(event, context):
    # Extract username from CloudTrail event via EventBridge
    detail = event.get('detail', {})
    request_params = detail.get('requestParameters', {})
    username = request_params.get('userName', '')
    
    if not username:
        print('No username found in event')
        return {'statusCode': 400, 'body': 'No username in event'}
    
    # Get user tags to determine department
    try:
        tags_response = iam.list_user_tags(UserName=username)
        tags = {tag['Key']: tag['Value'] for tag in tags_response.get('Tags', [])}
    except Exception as e:
        print(f'Could not get tags for {username}: {str(e)}')
        tags = {}
    
    department = tags.get('Department', '')
    target_group = DEPARTMENT_GROUP_MAP.get(department, '')
    
    if target_group:
        try:
            iam.add_user_to_group(
                GroupName=target_group,
                UserName=username
            )
            group_assigned = target_group
            message = f'User {username} automatically assigned to {target_group} based on Department tag: {department}'
        except Exception as e:
            group_assigned = 'None'
            message = f'Failed to assign {username} to group: {str(e)}'
    else:
        group_assigned = 'None'
        message = f'User {username} created with no Department tag or unrecognized department: {department}. Manual group assignment required.'
    
    # Send welcome/alert notification
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f'New IAM User Created: {username}',
        Message=f'''
SecureCorp IAM Lifecycle Event

New user created: {username}
Department tag: {department if department else "Not set"}
Group assigned: {group_assigned}

{message}

Please verify this user's access is appropriate for their role.
        '''
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'username': username,
            'department': department,
            'groupAssigned': group_assigned
        })
    }
