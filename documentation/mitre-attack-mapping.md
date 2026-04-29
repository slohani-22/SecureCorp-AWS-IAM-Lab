# MITRE ATT&CK Mapping — SecureCorp Detection Rules

**Framework:** MITRE ATT&CK for Cloud (IaaS — AWS)
**Coverage:** CloudWatch metric filter alarms + GuardDuty finding types

---

## CloudWatch Alarm Mappings

| Alarm | Detection Logic | ATT&CK ID | Technique | Tactic | Why It Matters |
|---|---|---|---|---|---|
| SecureCorp-BreakGlassUsed | CloudTrail userName = breakglass-admin | T1078 | Valid Accounts | Initial Access / Persistence | Break-glass use indicates either legitimate emergency or compromised emergency credentials — both require immediate investigation |
| SecureCorp-RootAccountUsed | CloudTrail userIdentity.type = Root | T1078.004 | Valid Accounts: Cloud Accounts | Privilege Escalation | Root API calls should never occur in normal operations — any root API call indicates misconfiguration or active attack |
| SecureCorp-MFADeactivated | CloudTrail eventName = DeactivateMFADevice | T1556 | Modify Authentication Process | Credential Access | Attackers disable MFA to prevent account recovery and establish persistent access |
| SecureCorp-IAMPolicyChanged | CloudTrail IAM policy create/modify/delete events | T1098 | Account Manipulation | Persistence / Privilege Escalation | IAM policy changes can silently escalate privileges or create backdoor access paths |
| SecureCorp-CloudTrailStopped | CloudTrail eventName = StopLogging | T1562.008 | Impair Defenses: Disable Cloud Logs | Defense Evasion | Disabling audit logging is the first action attackers take after gaining access — detected and blocked by SCP as first layer, alarmed as second layer |
| SecureCorp-S3BucketPublic | CloudTrail S3 bucket policy modification events | T1537 | Transfer Data to Cloud Account | Exfiltration | Making S3 buckets public is a common data exfiltration technique |

---

## GuardDuty Finding Type Mappings

| GuardDuty Finding Type | ATT&CK ID | Technique | Tactic |
|---|---|---|---|
| UnauthorizedAccess:IAMUser/MaliciousIPCaller | T1078 | Valid Accounts | Initial Access |
| CredentialAccess:RDS/MaliciousIPCaller.FailedLogin | T1110 | Brute Force | Credential Access |
| Persistence:Kubernetes/MaliciousIPCaller.Custom | T1053 | Scheduled Task/Job | Persistence |
| PrivilegeEscalation:Runtime/ContainerMountsHostDirectory | T1611 | Escape to Host | Privilege Escalation |
| DefenseEvasion:EC2/UnusualDNSResolver | T1071 | Application Layer Protocol | Command and Control |
| Trojan:Runtime/DropPoint | T1105 | Ingress Tool Transfer | Command and Control |
| Impact:EC2/AbusedDomainRequest.Reputation | T1496 | Resource Hijacking | Impact |
| UnauthorizedAccess:EC2/SSHBruteForce | T1110.001 | Brute Force: Password Guessing | Credential Access |

---

## Preventive Controls Mapped to ATT&CK

| Control | ATT&CK Technique Mitigated | How |
|---|---|---|
| MFA Enforcement Policy | T1078 Valid Accounts | Denies all actions without MFA in session |
| Permission Boundaries | T1098 Account Manipulation | Caps maximum permissions regardless of policy changes |
| SCP: Prevent-CloudTrail-Disable | T1562.008 Disable Cloud Logs | Blocks StopLogging at organization level — cannot be overridden |
| SCP: Prevent-GuardDuty-Disable | T1562 Impair Defenses | Blocks GuardDuty detector deletion |
| SCP: Prevent-Root-API-Usage | T1078.004 Cloud Accounts | Blocks all root API calls |
| ExplicitDeny: No Public S3 | T1537 Transfer Data to Cloud | Blocks ACLs that would make buckets public |
| OIDC over Access Keys | T1528 Steal Application Access Token | Short-lived tokens replace long-lived credentials |
| Secrets Manager Rotation | T1552 Unsecured Credentials | Credentials rotate automatically, reducing exposure window |

---

## ATT&CK Tactic Coverage Summary

| Tactic | Covered By |
|---|---|
| Initial Access | Break-glass alarm, GuardDuty malicious IP findings |
| Persistence | IAM policy alarm, GuardDuty persistence findings, lifecycle automation |
| Privilege Escalation | Root account alarm, IAM policy alarm, permission boundaries |
| Defense Evasion | CloudTrail stopped alarm, MFA deactivation alarm, SCPs |
| Credential Access | GuardDuty credential findings, MFA deactivation alarm, Secrets Manager |
| Discovery | Security read-only policy scoping, Access Analyzer |
| Exfiltration | S3 public access alarm, explicit deny policy |
| Command and Control | GuardDuty DNS and network findings |
| Impact | GuardDuty resource hijacking findings |
