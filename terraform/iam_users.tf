# IAM Groups
resource "aws_iam_group" "securecorp_groups" {
  for_each = toset(["Admins", "Security", "Developers", "Finance"])
  name     = "SecureCorp-${each.key}"
}

# IAM Users
resource "aws_iam_user" "john_admin" {
  name = "john.admin"
  tags = {
    Department = "IT"
    ManagedBy  = "Terraform"
  }
}

resource "aws_iam_user" "sarah_security" {
  name = "sarah.security"
  tags = {
    Department = "Security"
    ManagedBy  = "Terraform"
  }
}

resource "aws_iam_user" "dev_user" {
  name = "dev.user"
  tags = {
    Department = "Development"
    ManagedBy  = "Terraform"
  }
}

resource "aws_iam_user" "finance_user" {
  name = "finance.user"
  tags = {
    Department = "Finance"
    ManagedBy  = "Terraform"
  }
}

# Group Memberships
resource "aws_iam_user_group_membership" "john_admin_membership" {
  user   = aws_iam_user.john_admin.name
  groups = [aws_iam_group.securecorp_groups["Admins"].name]
}

resource "aws_iam_user_group_membership" "sarah_security_membership" {
  user   = aws_iam_user.sarah_security.name
  groups = [aws_iam_group.securecorp_groups["Security"].name]
}

resource "aws_iam_user_group_membership" "dev_user_membership" {
  user   = aws_iam_user.dev_user.name
  groups = [aws_iam_group.securecorp_groups["Developers"].name]
}

resource "aws_iam_user_group_membership" "finance_user_membership" {
  user   = aws_iam_user.finance_user.name
  groups = [aws_iam_group.securecorp_groups["Finance"].name]
}

# Developer Policy
resource "aws_iam_policy" "developer_policy" {
  name        = "SecureCorp-DeveloperPolicy-TF"
  description = "Least privilege policy for SecureCorp Developers"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ReadAndBasicActions"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Finance Policy
resource "aws_iam_policy" "finance_policy" {
  name        = "SecureCorp-FinancePolicy-TF"
  description = "Least privilege policy for SecureCorp Finance"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BillingReadOnly"
        Effect = "Allow"
        Action = [
          "billing:GetBillingData",
          "billing:GetBillingDetails",
          "ce:GetCostAndUsage",
          "ce:GetCostForecast",
          "budgets:ViewBudget"
        ]
        Resource = "*"
      }
    ]
  })
}

# Security Policy
resource "aws_iam_policy" "security_policy" {
  name        = "SecureCorp-SecurityPolicy-TF"
  description = "Read-only security policy for SecureCorp Security team"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecurityReadOnlyEverywhere"
        Effect = "Allow"
        Action = [
          "cloudtrail:Get*",
          "cloudtrail:Describe*",
          "cloudtrail:List*",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "guardduty:Get*",
          "guardduty:List*",
          "securityhub:Get*",
          "securityhub:List*",
          "iam:Get*",
          "iam:List*",
          "s3:GetObject",
          "s3:ListBucket",
          "ec2:Describe*",
          "access-analyzer:Get*",
          "access-analyzer:List*"
        ]
        Resource = "*"
      }
    ]
  })
}

# MFA Enforcement Policy
resource "aws_iam_policy" "mfa_enforcement" {
  name        = "SecureCorp-MFAEnforcement-TF"
  description = "Enforces MFA for all IAM users"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowManageOwnMFA"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ResyncMFADevice"
        ]
        Resource = [
          "arn:aws:iam::*:mfa/$${aws:username}",
          "arn:aws:iam::*:user/$${aws:username}"
        ]
      },
      {
        Sid    = "DenyAllExceptListedIfNoMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# Permission Boundary
resource "aws_iam_policy" "permission_boundary" {
  name        = "SecureCorp-PermissionBoundary-TF"
  description = "Permission boundary for all SecureCorp IAM users"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PermissionBoundary"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "s3:GetObject",
          "s3:ListBucket",
          "iam:GetUser",
          "iam:ListUsers",
          "cloudwatch:Get*",
          "cloudwatch:List*",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policies to groups
resource "aws_iam_group_policy_attachment" "developer_policy_attach" {
  group      = aws_iam_group.securecorp_groups["Developers"].name
  policy_arn = aws_iam_policy.developer_policy.arn
}

resource "aws_iam_group_policy_attachment" "finance_policy_attach" {
  group      = aws_iam_group.securecorp_groups["Finance"].name
  policy_arn = aws_iam_policy.finance_policy.arn
}

resource "aws_iam_group_policy_attachment" "security_policy_attach" {
  group      = aws_iam_group.securecorp_groups["Security"].name
  policy_arn = aws_iam_policy.security_policy.arn
}

resource "aws_iam_group_policy_attachment" "mfa_enforcement_admins" {
  group      = aws_iam_group.securecorp_groups["Admins"].name
  policy_arn = aws_iam_policy.mfa_enforcement.arn
}

resource "aws_iam_group_policy_attachment" "mfa_enforcement_security" {
  group      = aws_iam_group.securecorp_groups["Security"].name
  policy_arn = aws_iam_policy.mfa_enforcement.arn
}

resource "aws_iam_group_policy_attachment" "mfa_enforcement_developers" {
  group      = aws_iam_group.securecorp_groups["Developers"].name
  policy_arn = aws_iam_policy.mfa_enforcement.arn
}

resource "aws_iam_group_policy_attachment" "mfa_enforcement_finance" {
  group      = aws_iam_group.securecorp_groups["Finance"].name
  policy_arn = aws_iam_policy.mfa_enforcement.arn
}

# Permission boundary on users
resource "aws_iam_user_policy_attachment" "john_boundary" {
  user       = aws_iam_user.john_admin.name
  policy_arn = aws_iam_policy.permission_boundary.arn
}

# IAM Account Password Policy
resource "aws_iam_account_password_policy" "securecorp_password_policy" {
  minimum_password_length        = 14
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 12
}