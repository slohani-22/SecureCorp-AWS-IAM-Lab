variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
  default     = "318731645112"
}

variable "company_name" {
  description = "Company name for resource naming"
  type        = string
  default     = "SecureCorp"
}

variable "departments" {
  description = "List of departments"
  type        = list(string)
  default     = ["Admins", "Security", "Developers", "Finance"]
}

variable "trusted_ip" {
  description = "Trusted IP address for IP-restricted policies"
  type        = string
  default     = "YOUR_PUBLIC_IP/32"
}

variable "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
  default     = "securecorp-cloudtrail-logs-318731645112"
}

variable "data_bucket_name" {
  description = "S3 bucket name for SecureCorp data"
  type        = string
  default     = "securecorp-data-318731645112"
}

variable "sns_alert_email" {
  description = "Email address for security alerts"
  type        = string
  default     = "sl.securecorp.lab@gmail.com"
}