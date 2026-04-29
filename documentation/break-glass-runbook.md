# Break-Glass Emergency Access Runbook

**Document:** SecureCorp-RUNBOOK-001
**Classification:** Restricted — Security Team Only
**Last Updated:** April 2026

---

## Purpose

This runbook defines the procedure for using the break-glass emergency access account. The break-glass account (`breakglass-admin`) exists solely for emergency situations where all normal authentication methods have failed and immediate administrative access is required.

---

## When To Use

Use the break-glass account ONLY when ALL of the following are true:

- Normal admin accounts are inaccessible (compromised, locked, or MFA devices lost)
- A critical security incident requires immediate administrative action
- No other authorized administrator is available
- The situation cannot wait for normal account recovery procedures

**Do NOT use break-glass for:**
- Routine administrative tasks
- Convenience when normal accounts are working
- Testing or demonstration purposes
- Situations where normal account recovery is possible

---

## Pre-Use Checklist

Before using the break-glass account, document:

- [ ] Date and time of emergency
- [ ] Nature of the incident requiring break-glass access
- [ ] Other remediation options attempted and why they failed
- [ ] Name of person using the account
- [ ] Approving authority

---

## Access Procedure

**Step 1 — Retrieve credentials:**
Break-glass credentials are stored physically offline. Retrieve from the designated secure physical location. Do not store digitally under any circumstances.

**Step 2 — Sign in:**
Go to `https://318731645112.signin.aws.amazon.com/console`
Username: `breakglass-admin`
Enter password and MFA code from the dedicated break-glass MFA device.

**Step 3 — Perform only required actions:**
Limit actions strictly to what is needed to resolve the incident. Every action is logged in CloudTrail and will be reviewed.

**Step 4 — Sign out immediately:**
As soon as the emergency action is complete, sign out. Do not leave the session open.

---

## Post-Use Mandatory Actions

**Within 1 hour:**
- Notify the security team that break-glass was used
- Document every action taken during the session

**Within 24 hours:**
- Pull the CloudTrail log for the break-glass session
- Review every API call made — confirm all were authorized and necessary
- Verify the CloudWatch alarm `SecureCorp-BreakGlassUsed` fired and notification was received
- Document the incident with timeline, actions taken, and outcome

**Within 72 hours:**
- Rotate break-glass password
- Verify no unauthorized access occurred during or after the incident
- Submit incident report to security leadership
- Review whether normal access procedures need improvement

---

## CloudTrail Verification

To pull the break-glass session log:

CloudTrail → Event history → Filter by:
- Attribute: User name
- Value: `breakglass-admin`
- Time range: incident window

Review all events. Any unexpected actions should be escalated immediately as a potential account compromise.

---

## Detection

Any use of the break-glass account triggers:
- CloudWatch alarm: `SecureCorp-BreakGlassUsed`
- SNS notification to: `SecureCorp-SecurityAlerts` topic
- Email alert to security team

If a break-glass usage alert fires and no authorized use was in progress, treat it as an active security incident immediately. Do not wait for confirmation.

---

## Account Details

| Attribute | Value |
|---|---|
| Username | breakglass-admin |
| Group | None — standalone account |
| Policy | AdministratorAccess (directly attached) |
| MFA | Required — dedicated authenticator device |
| Permission Boundary | Not set — intentional for emergency access |
| Console Access | Enabled |
| Access Keys | None |
