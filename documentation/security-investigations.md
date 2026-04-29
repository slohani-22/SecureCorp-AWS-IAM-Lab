# Security Investigation Reports

---

## IR-AWS-001 — GuardDuty: Persistence/MaliciousIPCaller

**Date:** April 28, 2026
**Severity:** High
**Status:** Closed — Sample finding, no action required
**Analyst:** Sanskar Lohani

### Finding Summary

GuardDuty generated a High severity finding of type `Persistence:Kubernetes/MaliciousIPCaller.Custom` indicating a Kubernetes API commonly used in persistence tactics was invoked from an IP address on a custom threat list.

### Timeline

| Time (UTC) | Event |
|---|---|
| 09:15 | GuardDuty finding generated from sample data |
| 09:17 | Security Hub ingested finding — High severity |
| 09:20 | Analyst began investigation |
| 09:35 | Finding confirmed as sample — closed |

### Analysis

Reviewed the finding detail in GuardDuty. Resource fields showed `GeneratedFindingEKSClusterName` and instance ID `i-99999999` — standard placeholder values used in GuardDuty sample findings. No real EKS cluster exists in this environment.

In a real incident this finding would require:
- Identifying the actual EKS cluster and namespace affected
- Pulling CloudTrail logs for the API call from the flagged IP
- Cross-referencing the IP against threat intelligence feeds
- Isolating the affected pod or node
- Reviewing IAM roles bound to the Kubernetes service account
- Checking for any persistent backdoors or scheduled jobs created

### MITRE ATT&CK

Technique: T1053 — Scheduled Task/Job
Tactic: Persistence

### Outcome

Sample finding. No real threat. Confirmed by placeholder resource identifiers. Documented for MITRE ATT&CK coverage demonstration.

---

## IR-AWS-002 — Access Analyzer: External Access to IAM Roles

**Date:** April 28, 2026
**Severity:** Medium
**Status:** Closed — Archived as intentional access
**Analyst:** Sanskar Lohani

### Finding Summary

IAM Access Analyzer generated two active findings identifying external access to IAM roles:

1. `SecureCorp-GitHubActionsRole` — accessible by `token.actions.githubusercontent.com`
2. `AWSReservedSSO_SecureCorp-ReadOnly_8478886b63c6b7bc` — accessible by SAML provider `AWSSSO_36789b9915f27e1b_DO_NOT_DELETE`

### Analysis

**Finding 1 — GitHub Actions Role:**

Reviewed the trust policy on `SecureCorp-GitHubActionsRole`. Trust policy contains:

```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
  },
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:slohani-22/*:*"
  }
}
```

The role is scoped to the `slohani-22` GitHub organization only. Access from any other GitHub user or organization would be denied by the StringLike condition. This is an intentional OIDC trust configured for credential-free CI/CD pipeline access. Role only has `AmazonS3ReadOnlyAccess` — minimal permissions for the use case.

**Finding 2 — SSO ReadOnly Role:**

This role was created automatically by IAM Identity Center when the `SecureCorp-ReadOnly` permission set was provisioned. The SAML provider trust is required for federated users authenticating through Entra ID to assume this role. Actions allowed: `sts:AssumeRoleWithSAML` and `sts:TagSession` — both necessary for federation to function.

### Remediation Decision

Both findings archived with documented justification:
- Finding 1: Intentional OIDC trust for GitHub Actions CI/CD pipeline scoped to slohani-22 repository
- Finding 2: Intentional IAM Identity Center role for SAML federation with Entra ID — SecureCorp-ReadOnly permission set

### Outcome

No security risk identified. Both findings represent correctly scoped, intentional external access. Investigation demonstrates the process of reviewing Access Analyzer findings, understanding trust relationships, and making a documented risk decision.

---

## IR-AWS-003 — CloudTrail: IAM Policy Change Detection Workflow

**Date:** April 28, 2026
**Severity:** Medium
**Status:** Detection rule verified — workflow documented
**Analyst:** Sanskar Lohani

### Scenario

The CloudWatch alarm `SecureCorp-IAMPolicyChanged` fires on any IAM policy modification. This investigation documents the response workflow when this alarm triggers.

### Detection Trigger

CloudWatch metric filter `IAMPolicyChanged` matches on CloudTrail events:

```
{ ($.eventName = "DeleteGroupPolicy") || ($.eventName = "DeleteRolePolicy") ||
  ($.eventName = "DeleteUserPolicy") || ($.eventName = "PutGroupPolicy") ||
  ($.eventName = "PutRolePolicy") || ($.eventName = "PutUserPolicy") ||
  ($.eventName = "CreatePolicy") || ($.eventName = "DeletePolicy") ||
  ($.eventName = "CreatePolicyVersion") || ($.eventName = "DeletePolicyVersion") ||
  ($.eventName = "SetDefaultPolicyVersion") || ($.eventName = "AttachRolePolicy") ||
  ($.eventName = "DetachRolePolicy") || ($.eventName = "AttachUserPolicy") ||
  ($.eventName = "DetachUserPolicy") || ($.eventName = "AttachGroupPolicy") ||
  ($.eventName = "DetachGroupPolicy") }
```

### Investigation Steps

**Step 1 — Identify the event:**
CloudTrail → Event history → Filter by event name matching the alarm → note timestamp, source IP, and user identity.

**Step 2 — Identify who made the change:**
Review `userIdentity` field:
- `type` — IAMUser, AssumedRole, or Root
- `userName` or `arn` — specific identity
- `sourceIPAddress` — origin of the request
- `userAgent` — console, CLI, or SDK

**Step 3 — Identify what was changed:**
Review `requestParameters` field:
- `policyArn` — which policy was affected
- `userName` or `roleName` — which principal was targeted
- `policyDocument` — what the new policy allows

**Step 4 — Assess risk:**
- Was the change made by an authorized user during business hours from a trusted IP?
- Does the changed policy grant new permissions not previously held?
- Does it affect privileged roles or the break-glass account?
- Was this change part of an approved change request?

**Step 5 — Response:**
- If authorized and expected: document and close
- If unauthorized: immediately revert the policy change, investigate the identity, rotate credentials, review all actions taken by that identity in the past 24 hours

### Detection Confirmation

The `SecureCorp-RootAccountUsed` alarm showed IN ALARM state in CloudWatch during this lab — confirming the full detection pipeline (CloudTrail → CloudWatch Logs → Metric Filter → Alarm → SNS) is functional end to end.

### MITRE ATT&CK

Technique: T1098 — Account Manipulation
Tactic: Persistence / Privilege Escalation

### Outcome

Detection rule verified and working. Investigation workflow documented. This alarm provides early warning of privilege escalation attempts and unauthorized access path creation in the SecureCorp environment.
