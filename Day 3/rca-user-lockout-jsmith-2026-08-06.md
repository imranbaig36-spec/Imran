# Root Cause Analysis (RCA): User Lockout - jsmith

## Incident Summary
- Incident type: User account lockout
- Affected account: `jsmith`
- Observation window: 30 minutes (events captured between 08:02:14 and 08:23:44)
- Source endpoint in events: `DESKTOP-FB001`
- Domain actor for remediation: `FINBRIDGE\helpdesk-admin`
- Date analyzed: 2026-08-06

## Event ID Explanation

### Event ID 4625 (An account failed to log on)
Records a failed sign-in attempt. The key fields here are:
- Account: the target user (`jsmith`)
- Failure reason: why authentication failed
- Source workstation: where the logon attempt originated (`DESKTOP-FB001`)
- Logon type:
  - `2` = Interactive (local/console sign-in)
  - `7` = Unlock (attempt to unlock an already signed-in session)

### Event ID 4740 (A user account was locked out)
Records that the account reached lockout threshold and Active Directory/user account policy locked it. The event includes the caller computer (`DESKTOP-FB001`) that generated the triggering attempt.

### Event ID 4722 (A user account was enabled)
Records administrative action to enable an account. In this case, `FINBRIDGE\helpdesk-admin` performed the action. In many environments, unlock/reset workflows can generate related admin events; this entry indicates intervention by Helpdesk to restore access.

### Event ID 4624 (An account was successfully logged on)
Records a successful authentication. Here, `Logon type 2` confirms successful interactive sign-in after remediation.

## Reconstructed Sequence (Plain English)
1. At 08:02:14, `jsmith` entered credentials at the local machine (`DESKTOP-FB001`) and failed due to bad password/username (Event 4625, logon type 2).
2. At 08:04:22, a second interactive sign-in failed with the same reason from the same machine (Event 4625, logon type 2).
3. At 08:06:01, the account was locked by policy after repeated failed attempts (Event 4740), called from `DESKTOP-FB001`.
4. At 08:07:45, another attempt occurred while the account was already locked, this time on unlock flow (Event 4625, logon type 7).
5. At 08:22:10, Helpdesk admin (`FINBRIDGE\helpdesk-admin`) performed account recovery action (Event 4722).
6. At 08:23:44, `jsmith` logged in successfully at the console (Event 4624, logon type 2).

## Most Likely Cause of Lockout (with Evidence)
Most likely cause: repeated incorrect password entry by the user at the local workstation, leading to policy-based lockout.

Evidence from events:
- Two consecutive failed interactive logons from the same source (`DESKTOP-FB001`) with reason `Unknown username or bad password` (08:02:14, 08:04:22; Event 4625).
- Immediate lockout event (08:06:01; Event 4740) tied to the same source machine.
- Post-lockout failed unlock attempt explicitly says `Account locked out` (08:07:45; Event 4625, type 7), proving the account state was locked, not just a transient auth issue.
- Successful login occurred only after Helpdesk administrative action (08:22:10 Event 4722 followed by 08:23:44 Event 4624), which is consistent with lockout recovery.

## 5-Why Analysis

### Problem Statement
`jsmith` could not access their machine during the incident window because the account became locked.

### Why 1
Why was `jsmith` locked out?
- Because the account exceeded failed authentication threshold and was locked by policy (Event 4740 at 08:06:01).

### Why 2
Why was the threshold exceeded?
- Because there were repeated failed interactive logons with bad credentials from `DESKTOP-FB001` (4625 at 08:02:14 and 08:04:22).

### Why 3
Why were bad credentials repeatedly used?
- The user likely entered an incorrect password multiple times at the console, or attempted sign-in with stale remembered credentials on that endpoint.

### Why 4
Why was the incorrect credential state not corrected before lockout?
- No pre-lockout intervention occurred (for example, self-service password check/reset guidance or user pause after first failures). Attempts continued until policy threshold was reached.

### Why 5
Why did recovery require Helpdesk involvement?
- The environment appears to rely on admin-led unlock/enable workflow (Event 4722 by `FINBRIDGE\helpdesk-admin`) instead of immediate user self-recovery, increasing downtime.

## Root Cause and Contributing Factors

### Root Cause
Incorrect credentials repeatedly presented on the local interactive logon path from `DESKTOP-FB001`, triggering account lockout policy.

### Contributing Factors
- User continued attempts after initial failures.
- Standard lockout threshold enforcement acted as designed but reduced availability.
- Recovery depended on Helpdesk timing rather than immediate self-service.

## Corrective and Preventive Actions (CAPA)

### Immediate Corrective Actions
- Confirm account is unlocked/enabled and user can authenticate (verified by 4624 at 08:23:44).
- Validate keyboard layout/Caps Lock/credential format on endpoint to prevent repeat failures.

### Preventive Actions
1. User guidance
- Communicate a "stop after 1-2 failures" practice and prompt password verification before additional attempts.

2. Self-service recovery
- Enable or improve self-service password reset/unlock workflow to reduce reliance on Helpdesk and lower MTTR.

3. Monitoring and alerting
- Alert on repeated 4625 failures from same endpoint before 4740 lockout to allow proactive intervention.

4. Endpoint credential hygiene
- Review cached/remembered credentials and sign-in methods on `DESKTOP-FB001` to identify stale auth sources.

5. Policy review
- Reconfirm lockout threshold and reset windows are appropriate for user behavior and security posture.

## Validation Plan
- Check for absence of further 4625 bursts for `jsmith` over next 7 days.
- Confirm no repeat 4740 lockout for same user/device pairing.
- Track time-to-recover if recurrence happens; target reduction through self-service path.

## Evidence Table

| Time     | Event ID | Outcome | Key Detail |
|----------|----------|---------|------------|
| 08:02:14 | 4625     | Failure | Bad password/username, type 2, source `DESKTOP-FB001` |
| 08:04:22 | 4625     | Failure | Bad password/username, type 2, source `DESKTOP-FB001` |
| 08:06:01 | 4740     | Failure | Account locked out, caller `DESKTOP-FB001` |
| 08:07:45 | 4625     | Failure | Attempt denied because account locked, type 7 unlock |
| 08:22:10 | 4722     | Success | Account enabled by `FINBRIDGE\helpdesk-admin` |
| 08:23:44 | 4624     | Success | Interactive logon succeeded, type 2 |

## Analyst Conclusion
The lockout was most likely caused by repeated incorrect password attempts at the local machine (`DESKTOP-FB001`), with account policy enforcing lockout as intended. Service restoration occurred after Helpdesk administrative intervention, followed by successful interactive sign-in.