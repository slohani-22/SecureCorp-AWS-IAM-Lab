# SecureCorp Policy Decision Matrix

Complete reference of every IAM policy in the SecureCorp environment — what it covers, what it explicitly denies, and what it is attached to.

---

## Identity-Based Policies

| Policy | Type | Attached To | Key Allows | Key Explicit Denies |
|---|---|---|---|---|
| SecureCorp-AdminPolicy | Customer managed | SecureCorp-Admins group | All actions (`*`) — conditioned on MFA present in session | None — MFA condition gates all access |
| SecureCorp-DeveloperPolicy | Customer managed | SecureCorp-Developers group | ec2:Describe*, ec2:StartInstances, ec2:StopInstances, ec2:RebootInstances | All other services implicitly denied |
| SecureCorp-FinancePolicy | Customer managed | SecureCorp-Finance group | billing:Get*, ce:GetCostAndUsage, ce:GetCostForecast, budgets:ViewBudget | All other services implicitly denied |
| SecureCorp-SecurityPolicy | Customer managed | SecureCorp-Security group | CloudTrail/CloudWatch/GuardDuty/SecurityHub/IAM/S3/EC2/AccessAnalyzer read-only | All write actions implicitly denied |
| SecureCorp-MFAEnforcement | Customer managed | All four groups | IAM MFA device self-management | Everything except MFA setup actions if MFA not present |
| SecureCorp-IPRestrictedAccess | Customer managed | All four groups | None — deny policy | Sensitive IAM and S3 actions from IPs outside trusted range |
| SecureCorp-TimeBasedAccess | Customer managed | Developers and Finance groups | None — deny policy | Destructive actions outside approved date window |
| SecureCorp-MFARequiredForSensitiveOps | Customer managed | Admins and Security groups | None — deny policy | s3:DeleteObject, s3:DeleteBucket, iam:AttachUserPolicy, ec2:TerminateInstances, secretsmanager:GetSecretValue if MFA not in session |
| SecureCorp-ExplicitDeny | Customer managed | All four groups | None — deny policy | cloudtrail:DeleteTrail/StopLogging/UpdateTrail, public S3 ACLs, iam:CreateUser/CreateAccessKey without MFA |

---

## Permission Boundaries

| Boundary Policy | Applied To | Maximum Permissions Ceiling | Not Applied To |
|---|---|---|---|
| SecureCorp-PermissionBoundary | john.admin, sarah.security, dev.user, finance.user | EC2 read/start/stop, S3 read/write, IAM self-service, CloudWatch read, CloudTrail read, billing read, GuardDuty read, Secrets Manager read, STS GetCallerIdentity | breakglass-admin — intentional, emergency access requires unconstrained permissions |

---

## Service Control Policies

| SCP | Attached To | Blocked Actions | Cannot Be Overridden By |
|---|---|---|---|
| Prevent-CloudTrail-Disable | Organization Root | cloudtrail:StopLogging, cloudtrail:DeleteTrail, cloudtrail:UpdateTrail | Anyone including root and AdministratorAccess |
| Prevent-GuardDuty-Disable | Organization Root | guardduty:DeleteDetector, guardduty:DisassociateFromMasterAccount, guardduty:StopMonitoringMembers, guardduty:UpdateDetector | Anyone including root and AdministratorAccess |
| Prevent-Root-API-Usage | Organization Root | All actions (`*`) when principal ARN matches root pattern | N/A — root cannot override SCPs |
| Restrict-Region-US-East-1 | Organization Root | All regional service actions outside us-east-1 (global services excluded from restriction) | Anyone including root and AdministratorAccess |
| FullAWSAccess | Organization Root | N/A — this is the AWS default allow | Overridden by all custom deny SCPs above |

---

## Resource-Based Policies

| Resource | Policy Purpose | Key Principal Granted Access |
|---|---|---|
| securecorp-cloudtrail-logs S3 bucket | Allows CloudTrail to write log files | cloudtrail.amazonaws.com |
| SecureCorp-SentinelQueue SQS | Allows S3 to send event notifications | s3.amazonaws.com scoped to cloudtrail logs bucket |
| SecureCorp-GitHubActionsRole trust policy | Allows GitHub OIDC to assume role | token.actions.githubusercontent.com scoped to repo:slohani-22/* |
| SecureCorp-SentinelRole trust policy | Allows Microsoft Sentinel to ingest logs | Microsoft AWS account 197857026523 with workspace ID as external ID |
| SecureCorp-SecretsRotation Lambda resource policy | Allows Secrets Manager to invoke rotation function | secretsmanager.amazonaws.com |

---

## Policy Evaluation Order

When an IAM principal makes an API call, AWS evaluates in this order:

1. **SCPs** — if SCP denies, request is denied. No exceptions.
2. **Resource-based policies** — evaluated alongside identity policies
3. **Permission boundaries** — if action not in boundary, denied. No exceptions.
4. **Identity-based policies** — explicit deny wins over explicit allow
5. **Session policies** — for assumed roles, further restricts session

**In this environment the effective evaluation is:**

SCP → Permission Boundary → Explicit Deny → Group Policy → Allow

**Example:** A developer tries to call `s3:DeleteBucket`
- SCP (Restrict-Region): passes — us-east-1 action
- Permission Boundary: fails — DeleteBucket not in boundary
- Result: **DENIED** — never reaches identity policy evaluation

**Example:** An admin tries to call `cloudtrail:StopLogging`
- SCP (Prevent-CloudTrail-Disable): **DENIED immediately**
- Result: **DENIED** — SCP wins, identity policy never evaluated
