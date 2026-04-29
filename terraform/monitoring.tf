# CloudWatch Log Group for CloudTrail
resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "/aws/cloudtrail/SecureCorp-CloudTrail"
  retention_in_days = 90
}

# CloudTrail
resource "aws_cloudtrail" "securecorp_trail" {
  name                          = "SecureCorp-CloudTrail-TF"
  s3_bucket_name                = var.cloudtrail_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"

  tags = {
    ManagedBy = "Terraform"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_bucket_policy]
}

# SNS Topic for Security Alerts
resource "aws_sns_topic" "security_alerts" {
  name = "SecureCorp-SecurityAlerts-TF"
}

resource "aws_sns_topic_subscription" "security_alerts_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.sns_alert_email
}

# CloudWatch Metric Filters and Alarms
resource "aws_cloudwatch_log_metric_filter" "break_glass_used" {
  name           = "BreakGlassAccountUsed"
  pattern        = "{ $.userIdentity.userName = \"breakglass-admin\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name          = "BreakGlassAccountUsed"
    namespace     = "SecureCorp/SecurityEvents"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "break_glass_alarm" {
  alarm_name          = "SecureCorp-BreakGlassUsed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "BreakGlassAccountUsed"
  namespace           = "SecureCorp/SecurityEvents"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Break-glass account was used"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

resource "aws_cloudwatch_log_metric_filter" "root_account_used" {
  name           = "RootAccountUsed"
  pattern        = "{ $.userIdentity.type = \"Root\" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != \"AwsServiceEvent\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name          = "RootAccountUsed"
    namespace     = "SecureCorp/SecurityEvents"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "root_account_alarm" {
  alarm_name          = "SecureCorp-RootAccountUsed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "RootAccountUsed"
  namespace           = "SecureCorp/SecurityEvents"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Root account API call detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

resource "aws_cloudwatch_log_metric_filter" "mfa_deactivated" {
  name           = "MFADeviceDeactivated"
  pattern        = "{ $.eventName = \"DeactivateMFADevice\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name          = "MFADeviceDeactivated"
    namespace     = "SecureCorp/SecurityEvents"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "mfa_deactivated_alarm" {
  alarm_name          = "SecureCorp-MFADeactivated"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "MFADeviceDeactivated"
  namespace           = "SecureCorp/SecurityEvents"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "MFA device was deactivated"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

resource "aws_cloudwatch_log_metric_filter" "cloudtrail_stopped" {
  name           = "CloudTrailLoggingStopped"
  pattern        = "{ $.eventName = \"StopLogging\" }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name          = "CloudTrailLoggingStopped"
    namespace     = "SecureCorp/SecurityEvents"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudtrail_stopped_alarm" {
  alarm_name          = "SecureCorp-CloudTrailStopped"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CloudTrailLoggingStopped"
  namespace           = "SecureCorp/SecurityEvents"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "CloudTrail logging was stopped"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}