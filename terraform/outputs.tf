output "securecorp_data_bucket" {
  description = "SecureCorp data S3 bucket name"
  value       = aws_s3_bucket.securecorp_data.bucket
}

output "cloudtrail_bucket" {
  description = "CloudTrail logs S3 bucket name"
  value       = aws_s3_bucket.cloudtrail_logs.bucket
}

output "ec2_instance_role_arn" {
  description = "EC2 instance role ARN"
  value       = aws_iam_role.ec2_instance_role.arn
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.securecorp_app_server.id
}

output "security_alerts_topic_arn" {
  description = "SNS security alerts topic ARN"
  value       = aws_sns_topic.security_alerts.arn
}

output "iam_groups" {
  description = "Created IAM group names"
  value       = { for k, v in aws_iam_group.securecorp_groups : k => v.name }
}