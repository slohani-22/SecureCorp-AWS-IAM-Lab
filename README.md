# SecureCorp AWS IAM Security Lab

A comprehensive enterprise Identity and Access Management security environment built on AWS, demonstrating least-privilege RBAC, Zero Trust access controls, SAML/OIDC federation, Just-In-Time access automation, secrets management, threat detection, and cross-cloud monitoring with Microsoft Sentinel.

**Author:** Sanskar Lohani | [slohani-22](https://github.com/slohani-22)
**Certifications:** CompTIA Security+ · AZ-500
**Target Roles:** IAM Analyst · Cloud Security Engineer · SOC Analyst

---

## What This Project Demonstrates

- Least-privilege RBAC with custom IAM policies scoped per department
- Permission boundaries and SCPs as independent defense-in-depth layers
- SAML federation connecting Microsoft Entra ID to AWS IAM Identity Center
- OIDC federation for credential-free GitHub Actions CI/CD pipelines
- Just-In-Time access automation with approval workflow, DynamoDB state tracking, and auto-expiry
- Secrets management — EC2 retrieves credentials via IAM role, no hardcoded keys anywhere
- CloudTrail detection rules mapped to MITRE ATT&CK framework
- Cross-cloud monitoring — AWS CloudTrail events ingested into Microsoft Sentinel

---

## Tech Stack

AWS IAM · IAM Identity Center · S3 · EC2 · Lambda · DynamoDB · CloudTrail · CloudWatch · GuardDuty · Security Hub · IAM Access Analyzer · Secrets Manager · AWS Organizations · SNS · EventBridge · SQS · Terraform · GitHub Actions · Microsoft Entra ID · Microsoft Sentinel

---

## Environment Summary

| Component | Details |
|---|---|
| AWS Account | 318731645112 |
| Primary Region | us-east-1 |
| IAM Users | 5 (4 department + 1 break-glass) |
| IAM Groups | 4 |
| Custom IAM Policies | 10 |
| SCPs | 4 |
| Lambda Functions | 5 |
| CloudWatch Alarms | 6 |
| DynamoDB Tables | 1 |
| SNS Topics | 2 |
| Cross-cloud | AWS CloudTrail → Microsoft Sentinel |

---

## Identity Infrastructure

Built group-based RBAC for SecureCorp's four departments. No user has policies attached directly except the break-glass account.

**Groups and Users:**

| Group | User | Access Level |
|---|---|---|
| SecureCorp-Admins | john.admin | Full access with MFA condition |
| SecureCorp-Security | sarah.security | Read-only across all security services |
| SecureCorp-Developers | dev.user | EC2 describe/start/stop/reboot only |
| SecureCorp-Finance | finance.user | Billing and cost read-only |

**Key controls:**
- Password policy: 14-character minimum, complexity required, 90-day rotation, 12-password reuse prevention
- MFA enforcement deny policy on all groups — explicit deny all actions if MFA not present in session
- Break-glass account: AdministratorAccess attached directly, MFA enabled, credentials stored offline
- S3 bucket securecorp-data: versioning enabled, SSE-S3 encryption, all public access blocked
- EC2 instance: IAM role attached via instance profile, no access keys on the instance

**Screenshots:** `screenshots/identity-infrastructure/`

| Screenshot | Description |
|---|---|
| 01-iam-user-groups-final.png | All 4 groups with Defined permissions and 1 user each |
| 02-iam-users.png | All 5 users with MFA column showing breakglass Virtual MFA |
| 03-password-policy.png | Account password policy configured |
| 04-breakglass-admin.png | Break-glass user with AdministratorAccess directly attached |
| 05-s3-bucket-overview.png | securecorp-data bucket with all 3 folders visible |
| 05-s3-engineering-folder.png | engineering/ folder with placeholder file |
| 06-s3-finance-folder.png | finance/ folder with placeholder file |
| 07-s3-hr-folder.png | hr/ folder with placeholder file |
| 08-ec2-instance-role.png | EC2 role with AmazonS3ReadOnlyAccess and AmazonSSMManagedInstanceCore |
| 09-ec2-instance-running.png | EC2 instance Running state with SecureCorp-EC2-InstanceRole attached |

---

## Zero Trust Access Controls

Added defense-in-depth controls that enforce least privilege even if a policy is misconfigured.

**Permission Boundaries:** Applied to all 4 department users. Defines the maximum permissions ceiling regardless of what group policies grant. An admin accidentally attaching AdminPolicy to a developer group cannot exceed the boundary.

**Service Control Policies:**

| SCP | What It Blocks |
|---|---|
| Prevent-CloudTrail-Disable | StopLogging, DeleteTrail, UpdateTrail — organization-wide |
| Prevent-GuardDuty-Disable | DeleteDetector, StopMonitoringMembers |
| Prevent-Root-API-Usage | All API calls from root account principal |
| Restrict-Region-US-East-1 | Resource creation in any region except us-east-1 |

**Condition Key Policies:**
- `SecureCorp-IPRestrictedAccess` — sensitive IAM and S3 actions blocked from untrusted IPs
- `SecureCorp-TimeBasedAccess` — destructive actions restricted by time window
- `SecureCorp-MFARequiredForSensitiveOps` — MFA required in session for high-risk actions specifically

**Explicit Deny Policy:** Permanently blocks CloudTrail deletion, public S3 ACLs, and IAM user creation without MFA. Explicit deny always overrides any allow regardless of other attached policies.

**Screenshots:** `screenshots/zero-trust/`

| Screenshot | Description |
|---|---|
| 10-aws-organization.png | AWS Organization created with Securecorp as management account |
| 11-permission-boundary.png | SecureCorp-PermissionBoundary set on sarah.security |
| 12-scps-attached.png | Root showing all 4 custom SCPs plus FullAWSAccess attached |
| 13-all-securecorp-policies.png | All 10 SecureCorp policies in IAM with usage confirmed |
| 14-admin-group-policies.png | SecureCorp-Admins group showing all 5 attached policies |

---

## Federation

**SAML Federation — Microsoft Entra ID to AWS:**
- Personal Entra ID tenant configured as external identity provider in IAM Identity Center
- AWS IAM Identity Center enterprise application installed in Entra gallery
- SAML metadata exchanged between Entra ID and AWS
- Test user federated and authenticated successfully via Microsoft credentials
- User landed in AWS access portal with SecureCorp-ReadOnly permission set
- Single-user proof of concept demonstrating enterprise SSO trust configuration

**OIDC Federation — GitHub Actions to AWS:**
- `token.actions.githubusercontent.com` registered as OIDC provider in IAM
- `SecureCorp-GitHubActionsRole` trust policy scoped to `repo:slohani-22/*:*`
- GitHub Actions workflow assumes role via short-lived OIDC token — zero stored credentials in GitHub Secrets
- Workflow confirmed: role assumed, S3 bucket listed, all three folders visible

**Permission Sets:** SecureCorp-ReadOnly and SecureCorp-PowerUser created in IAM Identity Center.

**Screenshots:** `screenshots/federation/`

| Screenshot | Description |
|---|---|
| 15-identity-center-external-idp.png | IAM Identity Center Settings showing External identity provider configured |
| 16-identity-center-user-assignment.png | Test user assigned to Securecorp account with SecureCorp-ReadOnly |
| 17-saml-federation-working.png | AWS access portal showing federated user signed in via Entra ID |
| 18-github-oidc-provider.png | GitHub OIDC provider registered with audience sts.amazonaws.com |
| 19-github-role-trust-policy.png | SecureCorp-GitHubActionsRole trust policy scoped to slohani-22 |
| 20-github-actions-oidc-success.png | GitHub Actions workflow all steps green |
| 21-oidc-assumed-role.png | aws sts get-caller-identity confirming assumed role ARN and S3 listing |
| 22-permission-sets-list.png | SecureCorp-PowerUser permission set with PowerUserAccess |

---

## Governance Automation

Automated the full access lifecycle — request, approval, grant, expiry, stale detection, and new user onboarding.

**JIT Access Workflow:**

```
Request submitted → Lambda stores in DynamoDB (PENDING)
→ SNS approval email sent
→ Approver invokes Grant Lambda (APPROVE/DENY)
→ Policy attached to user, expiry scheduled in EventBridge
→ Revoke Lambda fires at expiry
→ Policy detached, DynamoDB updated (REVOKED)
→ SNS revocation notification sent
```

End-to-end test: dev.user requested AmazonS3ReadOnlyAccess for 5 minutes. Approval email received. Policy attached. Auto-revoked at expiry. Full record in DynamoDB.

**Stale Access Detector:** Weekly EventBridge schedule triggers Lambda, queries IAM credential report, flags users inactive 30+ days, writes JSON report to S3, sends SNS notification.

**Lifecycle Automation:** EventBridge watches CloudTrail for IAM CreateUser events. Lambda reads department tag and auto-assigns user to correct SecureCorp group.

**Screenshots:** `screenshots/governance-automation/`

| Screenshot | Description |
|---|---|
| 23-dynamodb-jit-table.png | SecureCorp-JITRequests table Active with requestId partition key |
| 24-sns-topics.png | SecureCorp-JITApprovals and SecureCorp-SecurityAlerts topics |
| 25-lambda-governance-role.png | SecureCorp-LambdaGovernanceRole with all 4 policies attached |
| 26-eventbridge-rules.png | SecureCorp-IAMUserCreationTrigger event pattern rule enabled |
| 26-eventbridge-schedules.png | SecureCorp-WeeklyStaleAccessScan schedule targeting Lambda |
| 27-jit-request-test.png | JITAccessRequest Lambda test returning 200 with requestId |
| 27b-jit-approval-email.png | Gmail showing JIT Access APPROVED email from AWS Notifications |
| 27c-jit-grant-test.png | JITAccessGrant Lambda test returning APPROVED status with expiry |
| 28-dynamodb-jit-record.png | DynamoDB record showing all fields with status APPROVED |
| 29-stale-access-report-s3.png | hr/ folder showing stale-access-report-2026-04-28.json |
| 30-stale-access-detector-test.png | StaleAccessDetector Lambda test returning 200 with report location |

---

## Secrets and Credential Security

**Secrets Manager:**
- Secret `securecorp/db/password` stores simulated database credentials
- 30-day automatic rotation enabled
- EC2 instance retrieves secret via IAM instance profile role — no access keys, no hardcoded credentials anywhere

**Retrieval demonstration (run on EC2 via Session Manager):**
```python
import boto3, json
client = boto3.client('secretsmanager', region_name='us-east-1')
response = client.get_secret_value(SecretId='securecorp/db/password')
secret = json.loads(response['SecretString'])
print(f"Username: {secret['username']}")
print(f"Password: {'*' * len(secret['password'])}")
# Authentication via IAM role — no access keys used
```

**IAM Access Analyzer:** Two findings identified, reviewed, and archived as intentional:
- SecureCorp-GitHubActionsRole — intentional OIDC trust scoped to slohani-22 repository
- AWSReservedSSO_SecureCorp-ReadOnly — intentional IAM Identity Center SAML federation role

**Credential Audit:** IAM credential report reviewed. No active access keys on any department user. Break-glass account MFA confirmed active.

**Screenshots:** `screenshots/secrets-and-credentials/`

| Screenshot | Description |
|---|---|
| 31-secrets-manager-secret.png | securecorp/db/password rotation tab showing 30-day schedule enabled |
| 32-ec2-secret-retrieval.png | Session Manager terminal showing secret retrieved via IAM role |
| 33-ec2-role-secrets-policy.png | EC2 role showing SecureCorp-EC2-SecretsAccess inline policy attached |
| 34-access-analyzer.png | SecureCorp-AccessAnalyzer active, External access type |
| 35-access-analyzer-finding-detail.png | Active findings list showing both findings before archiving |
| 35-access-analyzer-finding-detail1.png | GitHub OIDC finding detail — sts:AssumeRoleWithWebIdentity |
| 35-access-analyzer-finding-detail2.png | SSO SAML role finding detail — sts:AssumeRoleWithSAML |
| 36-access-analyzer-remediation.png | Both findings Archived as intentional access |
| 37-credential-report.png | IAM credential report showing all users, no active access keys |

---

## Monitoring and Detection

**CloudTrail:** Multi-region trail, log file integrity validation enabled, CloudWatch Logs integration.

**Detection Rules — MITRE ATT&CK Mapping:**

| Alarm | Detects | ATT&CK Technique |
|---|---|---|
| SecureCorp-BreakGlassUsed | breakglass-admin API call | T1078 Valid Accounts |
| SecureCorp-RootAccountUsed | Root account API call | T1078.004 Cloud Accounts |
| SecureCorp-MFADeactivated | MFA device deactivation | T1556 Modify Authentication |
| SecureCorp-IAMPolicyChanged | Any IAM policy modification | T1098 Account Manipulation |
| SecureCorp-CloudTrailStopped | StopLogging API call | T1562.008 Disable Cloud Logs |
| SecureCorp-S3BucketPublic | S3 bucket policy change | T1537 Transfer Data to Cloud |

**Security Hub:** AWS Foundational Security Best Practices standard enabled. Findings aggregated from GuardDuty.

**GuardDuty:** 133 sample findings generated across finding types including credential access, privilege escalation, persistence, defense evasion, and impact.

**Cross-Cloud Monitoring:** CloudTrail logs forwarded to Microsoft Sentinel via SQS queue and AWS S3 data connector. CloudTrail events confirmed in Sentinel Log Analytics workspace. Combined with existing Azure detection rules in the same workspace — unified cross-cloud SOC visibility.

**Screenshots:** `screenshots/monitoring-detection/`

| Screenshot | Description |
|---|---|
| 38-cloudtrail-active.png | SecureCorp-CloudTrail actively logging, validation enabled, CloudWatch integrated |
| 39-cloudwatch-alarms.png | All 6 CloudWatch alarms including RootAccountUsed in ALARM state |
| 40-cloudwatch-metric-filters.png | CloudWatch metric filters showing detection patterns |
| 41-security-hub-enabled.png | Security Hub summary showing 11 Critical 155 High findings |
| 42-guardduty-findings.png | GuardDuty 133 sample findings across severity levels |
| 43-guardduty-finding-detail.png | High severity Persistence finding detail |
| 44-sentinel-aws-connector.png | Sentinel AWS S3 connector Connected status |
| 45-sentinel-aws-logs.png | KQL query AWSCloudTrail returning 10 events in Sentinel |

---

## Infrastructure as Code

All core resources codified in Terraform for reproducibility and version control.

| File | Contents |
|---|---|
| main.tf | AWS provider configuration |
| variables.tf | Region, account ID, bucket names, email, trusted IP |
| iam_users.tf | Users, groups, memberships, all IAM policies, password policy |
| s3.tf | Data bucket and CloudTrail bucket with policies |
| ec2.tf | EC2 role, instance profile, AMI data source, instance |
| monitoring.tf | CloudTrail, CloudWatch filters and alarms, SNS |
| outputs.tf | Bucket names, role ARNs, instance ID, SNS ARN |

```bash
terraform init      # Downloads AWS provider v5.100.0
terraform validate  # Confirms configuration is valid
terraform plan      # Shows execution plan (requires AWS credentials configured)
terraform apply     # Deploys all resources to a fresh account
```

**Screenshots:** `screenshots/infrastructure-as-code/`

| Screenshot | Description |
|---|---|
| 46-terraform-init.png | terraform init successful, AWS provider v5.100.0 installed |
| 47-terraform-validate.png | terraform validate — configuration is valid |
| 48-terraform-plan.png | terraform plan output — requires AWS credentials configured locally |
| 49-github-terraform-files.png | GitHub repo showing all Terraform files committed |

---

## Security Documentation

Full documentation in `/documentation/`:

- `break-glass-runbook.md` — Emergency access procedure, post-use mandatory actions, detection verification
- `mitre-attack-mapping.md` — Full ATT&CK technique mapping for all detection rules and GuardDuty findings
- `security-investigations.md` — Three documented investigations: GuardDuty finding, Access Analyzer finding, CloudTrail detection
- `policy-decision-matrix.md` — Every policy, what it allows, what it explicitly denies, what it is attached to
- `architecture-diagram.md` — Full environment diagram with design decision rationale

---

## Cross-Cloud Integration

This lab connects to an existing Microsoft Sentinel SIEM lab (also on GitHub at slohani-22) running on Azure. AWS CloudTrail events flow into the same Log Analytics workspace that monitors Azure activity.

**Data flow:**
```
AWS API call → CloudTrail → S3 bucket → SQS notification
→ Sentinel AWS S3 connector → AWSCloudTrail table → KQL detection
```

**Combined coverage:**
- Azure: Activity logs, Entra ID sign-in logs, Defender for Cloud
- AWS: CloudTrail API audit, GuardDuty threat findings

**Related project:** [Microsoft Sentinel SIEM Lab](https://github.com/slohani-22) — 13 custom KQL detection rules, 8-stage kill chain simulation, automated incident response via Logic Apps and Microsoft Graph API

---

## Repository Structure

```
securecorp-aws-iam-lab/
├── README.md
├── terraform/                        # IaC for all resources
├── documentation/                    # Runbook, MITRE mapping, investigations
├── sample-data/                      # Simulated SecureCorp data files
├── reports/                          # Generated stale access report
└── screenshots/
    ├── identity-infrastructure/
    ├── zero-trust/
    ├── federation/
    ├── governance-automation/
    ├── secrets-and-credentials/
    ├── monitoring-detection/
    └── infrastructure-as-code/
```

---

## Key Design Decisions

**Group-based RBAC over direct user policies:** Policies attached to groups apply automatically to all members. Adding a new user to SecureCorp-Developers gives them exactly the right permissions with no manual policy attachment required.

**Permission boundaries in addition to group policies:** A group policy misconfiguration could grant a developer access to IAM. The boundary caps maximum permissions regardless of what group policies say — independent enforcement layer.

**SCPs in addition to explicit deny policies:** Explicit deny policies only work if they are attached. An admin could detach them. SCPs cannot be overridden by anyone in the account including root — two independent enforcement points.

**OIDC over stored access keys for GitHub Actions:** An access key stored in GitHub Secrets is a long-lived credential. An OIDC token is generated fresh for each workflow run and expires when the run ends — nothing to steal.

**JIT access over standing permissions:** Standing elevated access means a compromised account has that access immediately. JIT access means elevated permissions exist only for an approved, time-limited window — attack surface is minimized.
