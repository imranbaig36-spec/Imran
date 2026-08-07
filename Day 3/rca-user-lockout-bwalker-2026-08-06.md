# Root Cause Analysis (RCA): User Lockout - bwalker

## Incident Summary
- Incident type: User account lockout during Remote Desktop sign-in attempts
- Affected account: `FINBRIDGE\bwalker`
- Observation window: 30 minutes (14:01:02 to 14:22:09)
- Primary source client: `10.10.5.44`
- Primary access path: RDP (`Logon type 10`, RemoteInteractive)
- Date analyzed: 2026-08-06

## Event ID Explanation

### System | Source: `TermDD` | Event ID 56
Records a Terminal Services transport/protocol stream error. In practice, this often appears when an RDP session is abruptly dropped due to failed negotiation, malformed/terminated stream, or security-layer interruption.

### System | Source: `RemoteDesktopServices-RdpCoreTS` | Event ID 140
Records a failed RDP authentication at the RDP core layer. The event explicitly states the username or password is incorrect for the incoming client IP.

### Security | Event ID 4625 (Audit Failure)
Records a failed logon attempt.
- `Logon type 10` means RemoteInteractive (RDP/Remote Desktop style sign-in).
- `Failure reason: Unknown username or bad password` indicates credential validation failed.
- `Source IP: 10.10.5.44` identifies the originating client.

### Security | Event ID 4740 (Audit Failure)
Records that an account was locked out after lockout policy threshold was reached. The caller computer/client identifies where the final triggering attempt came from.

### System | Source: `RemoteDesktopServices-RdpCoreTS` | Event ID 131
Records that the server accepted a new TCP connection from a client. This is network/session establishment only, not proof of successful authentication by itself.

### Security | Event ID 4624 (Audit Success)
Records a successful logon. Here, `Logon type 10` confirms successful RDP authentication from the same source IP.

## Reconstructed Sequence (Plain English)
1. At 14:01:02, client `10.10.5.44` attempted RDP access and the session hit protocol/security disruption (`TermDD` 56) while RDP auth also reported bad credentials (`RdpCoreTS` 140).
2. At 14:01:04, a Security failure (`4625`) confirms `FINBRIDGE\bwalker` failed RemoteInteractive logon from `10.10.5.44` because of bad username/password.
3. Additional failed RDP logons occurred at 14:03:18 and 14:05:33 (`4625` x2), same account, same source IP, same failure reason.
4. At 14:05:34, the account was locked (`4740`) immediately after the third recorded failed attempt in this set, indicating policy threshold was reached.
5. At 14:22:07, a new TCP RDP connection was accepted from `10.10.5.44` (`RdpCoreTS` 131).
6. At 14:22:09, authentication succeeded (`4624`, logon type 10) for `FINBRIDGE\bwalker` from the same source IP.

## Most Likely Cause of Lockout (with Evidence)
Most likely cause: repeated RDP authentication attempts from client `10.10.5.44` using incorrect credentials (very likely manual re-tries and/or stale saved credentials), which exceeded the account lockout threshold.

Evidence:
- `RdpCoreTS` 140 explicitly reports incorrect username/password from `10.10.5.44` at 14:01:02.
- Three Security `4625` failures (14:01:04, 14:03:18, 14:05:33), all `Logon type 10`, all from `10.10.5.44`, all bad-credential reason.
- `4740` lockout fired at 14:05:34, one second after the third failure in this sequence.
- Later successful `4624` from the same IP at 14:22:09 suggests connectivity/path was available and the issue was credential state rather than sustained network outage.

## 5-Why Analysis

### Problem Statement
`FINBRIDGE\bwalker` was unable to access the machine over RDP during the incident window because the account became locked.

### Why 1
Why was the account locked?
- Because failed sign-in attempts reached lockout policy threshold (`4740` at 14:05:34).

### Why 2
Why did failed attempts reach threshold?
- Because multiple RemoteInteractive logons failed with bad credentials (`4625` at 14:01:04, 14:03:18, 14:05:33).

### Why 3
Why were bad credentials repeatedly submitted?
- The same source IP (`10.10.5.44`) kept attempting RDP authentication, indicating repeated user retries and/or cached saved credentials using an outdated password.

### Why 4
Why did retries continue until lockout?
- No effective interruption occurred after early failures (no user stop rule, no pre-lockout alerting, and likely no immediate correction of credential source).

### Why 5
Why was this operationally impactful?
- Recovery depended on waiting for lockout expiry or administrative unlock/reset workflow, causing avoidable access downtime.

## Root Cause and Contributing Factors

### Root Cause
Incorrect credentials were repeatedly presented during RDP logon attempts from `10.10.5.44`, triggering AD/account lockout policy.

### Contributing Factors
- Repeated rapid retries from one client.
- Potential stale saved credentials in RDP client/session manager.
- Lack of early intervention after first failure(s).
- Security policy functioned as designed but reduced availability once threshold was reached.

## Corrective and Preventive Actions (CAPA)

### Immediate Corrective Actions
- Confirm account unlock status and verify successful sign-in path (supported by `4624` at 14:22:09).
- Clear cached credentials on client `10.10.5.44` (Credential Manager, saved RDP entries).
- Validate username format and keyboard/Caps Lock state during sign-in.

### Preventive Actions
1. User behavior control
- Introduce guidance: stop after 1 to 2 failed attempts and verify credentials before retrying.

2. Credential hygiene
- Periodically clean stale RDP saved credentials on managed endpoints.

3. Monitoring and alerting
- Alert SOC/Service Desk on repeated `4625` type 10 from same source before `4740` occurs.

4. Service desk playbook
- Standardize lockout triage checklist: source IP review, cached credential check, unlock confirmation, and post-incident user coaching.

5. Policy validation
- Review lockout threshold/window balance for security vs. usability while keeping compliance requirements.

## Validation Plan
- Monitor `FINBRIDGE\bwalker` and source `10.10.5.44` for 7 days for repeat `4625` bursts.
- Confirm no new `4740` events for this user after credential cleanup.
- Track MTTR for future lockout events and target reduction via faster first-response playbook.

## Evidence Table

| Time     | Log | Source/Event | Outcome | Key Detail |
|----------|-----|--------------|---------|------------|
| 14:01:02 | System | TermDD 56 | Error | Protocol/security stream issue; client `10.10.5.44` disconnected |
| 14:01:02 | System | RdpCoreTS 140 | Warning | RDP auth failed: incorrect username/password from `10.10.5.44` |
| 14:01:04 | Security | 4625 | Failure | `FINBRIDGE\bwalker`, type 10, bad credentials, source `10.10.5.44` |
| 14:03:18 | Security | 4625 | Failure | Repeat type 10 bad credentials, same source IP |
| 14:05:33 | Security | 4625 | Failure | Third type 10 bad-credential failure in sequence |
| 14:05:34 | Security | 4740 | Failure | Account locked out; caller computer `10.10.5.44` |
| 14:22:07 | System | RdpCoreTS 131 | Info | New TCP RDP connection accepted from `10.10.5.44` |
| 14:22:09 | Security | 4624 | Success | Successful type 10 logon for `FINBRIDGE\bwalker` |

## Analyst Conclusion
The lockout was caused by repeated failed RDP credential attempts from `10.10.5.44`, not by persistent network loss. System-layer events (TermDD 56 and RdpCoreTS 140) align with the start of failed authentication activity, while Security events provide definitive lockout causality (`4625` sequence followed by `4740`). Successful later logon (`4624`) supports that correcting account state/credentials resolved access.
