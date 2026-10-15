import json
import os
import boto3
import csv
import io
import time
from datetime import datetime, timezone, timedelta

iam = boto3.client('iam')
s3 = boto3.client('s3')
sns = boto3.client('sns')

BUCKET_NAME = os.environ['BUCKET_NAME']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
STALE_DAYS_THRESHOLD = 30

def lambda_handler(event, context):
    # Generate IAM credential report
    iam.generate_credential_report()
    time.sleep(5)
    
    response = iam.get_credential_report()
    report_content = response['Content'].decode('utf-8')
    
    # Parse CSV report
    reader = csv.DictReader(io.StringIO(report_content))
    stale_users = []
    now = datetime.now(timezone.utc)
    threshold_date = now - timedelta(days=STALE_DAYS_THRESHOLD)
    
    for row in reader:
        username = row['user']
        
        if username == '<root_account>':
            continue
        
        password_last_used = row.get('password_last_used', 'N/A')
        access_key_1_last_used = row.get('access_key_1_last_used_date', 'N/A')
        
        is_stale = False
        reason = []
        
        # Check password last used
        if password_last_used not in ['N/A', 'no_information', 'never']:
            try:
                last_used = datetime.fromisoformat(password_last_used.replace('Z', '+00:00'))
                if last_used < threshold_date:
                    is_stale = True
                    days_inactive = (now - last_used).days
                    reason.append(f'Password not used in {days_inactive} days')
            except:
                pass
        elif password_last_used == 'never':
            is_stale = True
            reason.append('Password never used')
        
        if is_stale:
            stale_users.append({
                'username': username,
                'passwordLastUsed': password_last_used,
                'accessKey1LastUsed': access_key_1_last_used,
                'reasons': reason
            })
    
    # Generate report
    report_date = now.strftime('%Y-%m-%d')
    report_key = f'hr/stale-access-report-{report_date}.json'
    
    report = {
        'generatedAt': now.isoformat(),
        'thresholdDays': STALE_DAYS_THRESHOLD,
        'totalStaleUsers': len(stale_users),
        'staleUsers': stale_users
    }
    
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=report_key,
        Body=json.dumps(report, indent=2),
        ContentType='application/json'
    )
    
    # Send SNS notification
    if stale_users:
        user_list = '\n'.join([f"- {u['username']}: {', '.join(u['reasons'])}" for u in stale_users])
        message = f"""
SecureCorp Stale Access Report - {report_date}

Found {len(stale_users)} stale user(s) with no activity in {STALE_DAYS_THRESHOLD}+ days:

{user_list}

Full report saved to: s3://{BUCKET_NAME}/{report_key}

Review and disable or delete these accounts if no longer needed.
        """
    else:
        message = f"SecureCorp Stale Access Report - {report_date}\n\nNo stale users found. All users active within {STALE_DAYS_THRESHOLD} days."
    
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=f'Stale Access Report - {len(stale_users)} users flagged',
        Message=message
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'staleUsersFound': len(stale_users),
            'reportLocation': f's3://{BUCKET_NAME}/{report_key}'
        })
    }
