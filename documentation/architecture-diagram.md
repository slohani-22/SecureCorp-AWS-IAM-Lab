# SecureCorp AWS IAM Security Lab — Architecture

## Environment Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AWS Organization (o-jym8v4vtts)                      │
│                                                                         │
│  SCPs Applied to Root:                                                  │
│  ✗ No CloudTrail Disable  ✗ No GuardDuty Disable                       │
│  ✗ No Root API Calls      ✗ Non-us-east-1 Regions                      │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │            AWS Account 318731645112 — us-east-1                   │  │
│  │                                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────┐ │  │
│  │  │                     Identity Layer                           │ │  │
│  │  │                                                             │ │  │
│  │  │  SecureCorp-Admins ──── john.admin                          │ │  │
│  │  │  SecureCorp-Security ── sarah.security                      │ │  │
│  │  │  SecureCorp-Developers ─ dev.user                           │ │  │
│  │  │  SecureCorp-Finance ─── finance.user                        │ │  │
│  │  │                                                             │ │  │
│  │  │  breakglass-admin (standalone — AdministratorAccess)        │ │  │
│  │  │                                                             │ │  │
│  │  │  All dept users: Permission Boundary applied                │ │  │
│  │  │  All groups: MFAEnforcement + ExplicitDeny + IPRestricted   │ │  │
│  │  └─────────────────────────────────────────────────────────────┘ │  │
│  │                                                                   │  │
│  │  ┌──────────────────────┐   ┌──────────────────────────────────┐ │  │
│  │  │   Compute and Data   │   │           Federation             │ │  │
│  │  │                      │   │                                  │ │  │
│  │  │  securecorp-app-     │   │  IAM Identity Center             │ │  │
│  │  │  server (EC2 t3.     │   │  External IdP: Entra ID (SAML)   │ │  │
│  │  │  micro) — IAM role,  │   │  Permission Sets:                │ │  │
│  │  │  no access keys      │   │  ReadOnly / PowerUser            │ │  │
│  │  │                      │   │                                  │ │  │
│  │  │  securecorp-data     │   │  OIDC: GitHub Actions            │ │  │
│  │  │  S3 bucket           │   │  SecureCorp-GitHubActionsRole    │ │  │
│  │  │  /finance /hr        │   │  Scoped to slohani-22 repo       │ │  │
│  │  │  /engineering        │   └──────────────────────────────────┘ │  │
│  │  │                      │                                         │  │
│  │  │  securecorp/db/      │                                         │  │
│  │  │  password (Secrets   │                                         │  │
│  │  │  Manager — 30d rot)  │                                         │  │
│  │  └──────────────────────┘                                         │  │
│  │                                                                   │  │
│  │  ┌───────────────────────────────────────────────────────────┐   │  │
│  │  │                 Governance Automation                      │   │  │
│  │  │                                                           │   │  │
│  │  │  SNS: JITApprovals      Lambda: JITAccessRequest          │   │  │
│  │  │  SNS: SecurityAlerts    Lambda: JITAccessGrant            │   │  │
│  │  │  DynamoDB: JITRequests  Lambda: JITAccessRevoke           │   │  │
│  │  │  (state tracking)       Lambda: StaleAccessDetector       │   │  │
│  │  │                         Lambda: LifecycleAutomation       │   │  │
│  │  │  EventBridge: Weekly stale scan + IAM CreateUser trigger  │   │  │
│  │  └───────────────────────────────────────────────────────────┘   │  │
│  │                                                                   │  │
│  │  ┌───────────────────────────────────────────────────────────┐   │  │
│  │  │                Monitoring and Detection                    │   │  │
│  │  │                                                           │   │  │
│  │  │  CloudTrail (multi-region, log validation)                │   │  │
│  │  │       │                                                   │   │  │
│  │  │       ├──► S3: securecorp-cloudtrail-logs                 │   │  │
│  │  │       │         │                                         │   │  │
│  │  │       │         └──► SQS: SecureCorp-SentinelQueue        │   │  │
│  │  │       │                                                   │   │  │
│  │  │       └──► CloudWatch Logs → 6 Metric Filters             │   │  │
│  │  │                              6 Alarms → SNS email         │   │  │
│  │  │                                                           │   │  │
│  │  │  GuardDuty ──────────────► Security Hub (aggregated)      │   │  │
│  │  │  IAM Access Analyzer ────► Findings reviewed and archived │   │  │
│  │  └───────────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │ AWS S3 Data Connector
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│         Microsoft Sentinel — sentinel-prodd (West US 2)                  │
│                                                                          │
│  AWSCloudTrail table ──► KQL detection rules ──► Incidents               │
│  Azure Activity logs ──► Combined cross-cloud SOC visibility             │
│                                                                          │
│  Entra ID tenant also connected to IAM Identity Center via SAML          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Trust Relationships

```
Microsoft Entra ID ──SAML──► IAM Identity Center ──► AWS Console
                                                        (federated user)

GitHub Actions ──OIDC──► SecureCorp-GitHubActionsRole ──► S3 ReadOnly

Microsoft Sentinel ──AssumeRole──► SecureCorp-SentinelRole ──► SQS/S3 read
(account 197857026523)
```

---

## Data Flows

**Access Request (JIT):**
```
Request event → JITAccessRequest Lambda → DynamoDB (PENDING)
→ SNS email to approver → JITAccessGrant Lambda (APPROVE)
→ IAM AttachUserPolicy → EventBridge expiry rule
→ JITAccessRevoke Lambda → IAM DetachUserPolicy → DynamoDB (REVOKED)
```

**Audit Log Flow:**
```
API call anywhere in account → CloudTrail captures
→ S3 storage (integrity validated) + CloudWatch Logs stream
→ Metric filters pattern match → Alarm threshold exceeded
→ SNS notification → Security team email
→ SQS queue → Sentinel connector → AWSCloudTrail table → KQL
```

**Secret Retrieval (EC2):**
```
EC2 instance boot → Instance profile role assumed automatically
→ Application calls secretsmanager:GetSecretValue
→ Secrets Manager validates role permissions → Returns secret value
→ No access keys, no hardcoded credentials anywhere in this flow
```

---

## Key Design Decisions

**Group-based RBAC:** Policies on groups, not users. New user added to group = correct permissions immediately. User removed = access revoked immediately.

**Two independent deny layers:** SCPs block dangerous actions at the organization level — cannot be overridden. Explicit deny policies block them at the identity level. Both must be bypassed for an attacker to succeed.

**Permission boundaries as misconfiguration defense:** Even if an admin accidentally attaches AdminPolicy to a developer, the permission boundary caps what that developer can actually do. Policy misconfiguration cannot create privilege escalation.

**OIDC instead of stored keys:** GitHub Actions credentials exist only for the duration of each workflow run. There are no long-lived credentials to steal, rotate, or accidentally expose in logs.

**JIT with state tracking:** DynamoDB records every request, approval decision, expiry time, and revocation timestamp. Every elevated access event is fully auditable with a complete lifecycle record.
