# RCA - User Login Failure (cthompson) Resolved 09:09

## Document Control
- Incident type: User authentication failure / account lockout
- User affected: `FINBRIDGE\cthompson`
- Scope: Single user only
- Reported symptom: User unable to log in
- Reported start: ~08:40
- Resolution confirmed: 09:09 AM
- Resolver identity (from logs): `FINBRIDGE\helpdesk-admin`
- Endpoint observed: `DESKTOP-FB022` (IP reference in notes: `10.10.1.88`)

## Executive Summary
At approximately 08:44, multiple bad-password authentication failures were recorded for `FINBRIDGE\cthompson` from `DESKTOP-FB022`, followed by an explicit account lockout event. After lockout, additional wrong-password Kerberos pre-auth attempts continued from a different source IP (`10.10.8.112`), indicating at least one stale credential source persisted beyond the initial interactive attempts.

Service desk remediation restored access by re-enabling/unlocking the user account and validating fresh interactive sign-in. Successful user logon was confirmed at 09:09 from `DESKTOP-FB022`, and the user reported no further issues.

## Impact Assessment
- Business impact: Single-user productivity interruption (logon blocked).
- Blast radius: Contained to one user; no multi-user or platform-wide outage indicators.
- Service impact: Authentication access for one endpoint/user context only.

## Supporting Evidence (Security Event Logs)

### Failure and lockout evidence
1. `08:44:01` - Security Event `4776` (Audit Failure)
- Detail: Domain controller attempted credential validation.
- Account: `FINBRIDGE\cthompson`
- Error code: `0xC000006A` (wrong password)
- Source workstation: `DESKTOP-FB022`

2. `08:44:03` - Security Event `4625` (Audit Failure)
- Failure reason: Unknown user name or bad password
- Logon type: `2` (Interactive)
- Source: `DESKTOP-FB022`

3. `08:44:28` - Security Event `4625` (Audit Failure)
- Failure reason: Unknown user name or bad password
- Logon type: `2` (Interactive)
- Source: `DESKTOP-FB022`

4. `08:44:55` - Security Event `4625` (Audit Failure)
- Failure reason: Unknown user name or bad password
- Logon type: `2` (Interactive)
- Source: `DESKTOP-FB022`

5. `08:44:56` - Security Event `4740` (Audit Failure)
- Detail: A user account was locked out
- Account: `FINBRIDGE\cthompson`
- Caller computer: `DESKTOP-FB022`

6. `08:45:10` - Security Event `4625` (Audit Failure)
- Failure reason: Account locked out
- Logon type: `7` (Unlock attempt)
- Source: `DESKTOP-FB022`

### Ongoing bad credential attempts after lockout
7. `08:45:44` - Security Event `4771` (Audit Failure)
- Detail: Kerberos pre-authentication failed
- Failure code: `0x18` (wrong password)
- Source IP: `10.10.8.112`

8. `08:46:01` - Security Event `4771` (Audit Failure)
- Detail: Kerberos pre-authentication failed
- Failure code: `0x18` (wrong password)
- Source IP: `10.10.8.112`

9. `08:46:33` - Security Event `4771` (Audit Failure)
- Detail: Kerberos pre-authentication failed
- Failure code: `0x18` (wrong password)
- Source IP: `10.10.8.112`

### Recovery evidence
10. `09:08:14` - Security Event `4722` (Audit Success)
- Detail: A user account was enabled
- Account: `FINBRIDGE\cthompson`
- Done by: `FINBRIDGE\helpdesk-admin`

11. `09:09:01` - Security Event `4624` (Audit Success)
- Detail: Account successfully logged on
- Account: `FINBRIDGE\cthompson`
- Logon type: `2` (Interactive)
- Source: `DESKTOP-FB022`

## Timeline (End-to-End)
- ~08:40: User-reported inability to log in begins.
- 08:44:01: Wrong password validation failure (`4776`, `0xC000006A`) from `DESKTOP-FB022`.
- 08:44:03 to 08:44:55: Repeated interactive bad-password failures (`4625`) from `DESKTOP-FB022`.
- 08:44:56: Account lockout occurs (`4740`) for `FINBRIDGE\cthompson`.
- 08:45:10: Unlock/login attempt still fails due to lockout (`4625`, logon type 7).
- 08:45:44 to 08:46:33: Continued wrong-password Kerberos pre-auth failures (`4771`, `0x18`) from `10.10.8.112`.
- 09:08:14: Account enabled by helpdesk admin (`4722`).
- 09:09:01: Successful interactive login recorded (`4624`) from `DESKTOP-FB022`.
- 09:09: User confirms access restored and no further issues reported.

## Root Cause Statement
Primary root cause was account lockout triggered by repeated wrong-password authentication attempts for `FINBRIDGE\cthompson` from `DESKTOP-FB022`, with evidence of an additional stale-credential source (`10.10.8.112`) continuing wrong-password attempts after lockout.

## 5 Whys Analysis
1. Why could the user not log in?
- Because the account was locked out.
- Evidence: `08:44:56` Event `4740`; `08:45:10` Event `4625` (account locked out).

2. Why was the account locked out?
- Because multiple authentication attempts used an incorrect password until lockout threshold was exceeded.
- Evidence: `08:44:01` Event `4776` wrong password; `08:44:03/08:44:28/08:44:55` Event `4625` bad password.

3. Why were repeated wrong-password attempts occurring?
- Because one or more endpoints/sessions were submitting stale or incorrect credentials repeatedly.
- Evidence: Initial failures from `DESKTOP-FB022`, and continued Kerberos failures from `10.10.8.112` after lockout (`4771` at `08:45:44`, `08:46:01`, `08:46:33`).

4. Why were stale/incorrect credentials still being submitted after lockout?
- Because at least one secondary credential store/process (separate source IP) was not yet updated/cleared and continued automatic auth attempts.
- Evidence: Different source (`10.10.8.112` vs `DESKTOP-FB022`) with repeated wrong-password pre-auth failures.

5. Why was this not prevented before user impact?
- Because no effective pre-lockout control/alert interrupted repeated bad-credential submissions across multiple sources before threshold was reached.
- Evidence: Consecutive failure chain leading directly to lockout before service desk intervention.

## Corrective Actions Taken
1. Service desk performed account recovery action (enable/unlock path) for `FINBRIDGE\cthompson`.
- Evidence: `09:08:14` Event `4722` by `FINBRIDGE\helpdesk-admin`.

2. User interactive sign-in validated after recovery.
- Evidence: `09:09:01` Event `4624` from `DESKTOP-FB022`.

3. Incident closure confirmed with user.
- Evidence: User reported no further login issues post-recovery at 09:09.

## Preventive Actions

### Immediate (0-2 days)
1. Identify and remediate host/service behind source IP `10.10.8.112`.
- Remove stale credentials from Credential Manager, mapped drives, scheduled tasks, services, and app sign-ins.

2. Force credential refresh across all user sessions/devices after password reset events.
- Require re-authentication in Outlook/Teams/OneDrive/VPN and persistent drive mappings.

3. Add short-term monitoring watch for the user for recurring `4771`/`4776`/`4740`.

### Near-term (this sprint)
1. Implement lockout early-warning alerting.
- Trigger alert when bad-password events for same user exceed threshold within short interval.

2. Enrich SOC/helpdesk runbook with multi-source bad-password triage.
- Mandatory step: compare workstation source and Kerberos source IPs for divergence.

3. Standardize post-recovery validation checklist.
- Require successful `4624` plus no recurring bad-password events for defined observation window.

### Longer-term (1-2 months)
1. Reduce stale credential persistence risk.
- Review policy baselines for cached credentials and persistent auth artifacts.

2. Improve user education and communication.
- Password-change guidance must include updating secondary devices/apps immediately.

3. Automate stale credential detection patterns.
- Detect repeated `4771/4776` combinations from different sources for the same account and auto-create incident.

## Preventive Action Owners and Targets
- Service Desk Lead: update operational runbook and checklist (target: 5 business days).
- IAM/AD Team: configure lockout early-warning alerts (target: 10 business days).
- Endpoint Engineering: review and tighten credential caching controls where feasible (target: 30 days).
- SOC/Monitoring Team: implement correlation rule for multi-source bad-password patterns (target: 30 days).

## Validation and Closure Criteria
- User can authenticate interactively (`4624`) on primary host.
- No new lockout (`4740`) events in monitoring window.
- No recurring wrong-password failures (`4771` code `0x18`, `4776` code `0xC000006A`) after remediation.
- User confirms normal access restored.

## Final Status
- Status: **Resolved**
- Resolution time: **09:09 AM**
- Confidence in root cause: **High** (direct lockout and bad-password event chain with successful post-fix login evidence)
