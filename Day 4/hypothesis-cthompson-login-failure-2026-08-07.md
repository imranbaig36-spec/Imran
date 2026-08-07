# Login Failure Hypothesis - cthompson (2026-08-07)

## Scope Facts Used
- Symptom: user `cthompson` cannot log in
- Affected users: `cthompson` only (single-user impact)
- Started: approximately 08:40 this morning
- Reported change: none

## Ranked Most Likely Causes (Most Probable First)

### 1) Account lockout from bad password attempts
Why this fits scope facts:
- Single-user impact strongly matches a user-specific lockout.
- Sudden start time (~08:40) is consistent with a lockout threshold being hit at a specific moment.
- No change required for this to happen (can be triggered by mistyped password or stale cached credentials on a device/mobile app).

Single fastest check:
- Check Azure AD/Entra or AD sign-in status for `cthompson` immediately: is the account currently locked/temporarily blocked?

### 2) Expired or recently changed password not synchronized across all auth paths
Why this fits scope facts:
- Still isolated to one user.
- Can appear suddenly in the morning if password age threshold is reached overnight.
- "No change" can still be true from incident scope perspective if expiry was policy-driven and not a manual change.

Single fastest check:
- Verify `cthompson` password age/expiry state in identity directory and test if password is marked expired or must-change-at-next-logon.

### 3) Conditional Access / sign-in risk policy block specific to this user session
Why this fits scope facts:
- User-specific policy or risk event can block one user while others remain unaffected.
- Time-specific onset can align with sign-in risk recalculation, impossible travel flag, or session/location condition becoming non-compliant.
- No infrastructure change is needed for policy evaluation outcome to change.

Single fastest check:
- Open latest failed sign-in event for `cthompson` and read the exact failure reason + Conditional Access result (grant/deny + policy name).

### 4) Licensing or group-membership drift removing login entitlement path
Why this fits scope facts:
- Single-user impact is compatible with accidental group removal, stale dynamic group evaluation, or license assignment issue.
- Could begin at a precise time if directory processing/re-evaluation happened then.
- "No change" from user side remains possible.

Single fastest check:
- Compare current effective license + required auth/access groups for `cthompson` against a known-good peer in the same team/role.

### 5) Corrupt local credential cache/profile issue on the endpoint (not identity back-end)
Why this fits scope facts:
- One-user symptom can come from device-side token cache/profile corruption.
- Sudden morning onset is common after reboot, sleep resume, or token refresh.
- No known org change is needed.

Single fastest check:
- Attempt sign-in for `cthompson` on an alternate known-good device/browser profile; if success there, local device/profile issue becomes likely.

## Notes
- This is a hypothesis ranking only, based strictly on provided scope facts.
- No single root cause is committed at this stage.

## Evidence Assessment Against Incident Event Logs (08:44-09:12)

### Hypothesis 1: Account lockout from bad password attempts
Judgement: **Supports**

Why:
- Repeated bad-password failures occur first, then explicit lockout is logged.
- Sequence is exactly consistent with lockout-threshold behavior.

Determining events:
- `08:44:01` - Event `4776`, error `0xC000006A` (wrong password)
- `08:44:03`, `08:44:28`, `08:44:55` - Event `4625` (unknown user name or bad password)
- `08:44:56` - Event `4740` (user account locked out)
- `08:45:10` - Event `4625` (failure reason: account locked out)

### Hypothesis 2: Expired or recently changed password not synchronized across all auth paths
Judgement: **Contradicts**

Why:
- Logged failure reasons are wrong-password and lockout, not password-expired or must-change indicators.
- Event pattern points to invalid credential submission rather than expiry enforcement.

Determining events:
- `08:44:01` - Event `4776`, error `0xC000006A` (wrong password)
- `08:45:44`, `08:46:01`, `08:46:33` - Event `4771`, failure code `0x18` (wrong password)
- `08:44:56` - Event `4740` (account locked out after bad attempts)

### Hypothesis 3: Conditional Access / sign-in risk policy block specific to this user session
Judgement: **Contradicts**

Why:
- Security log shows credential validation failures and lockout, with no policy-deny signal.
- There are no events in the supplied set indicating a Conditional Access or risk-policy decision as failure cause.

Determining events:
- `08:44:01` - Event `4776` wrong-password code `0xC000006A`
- `08:44:56` - Event `4740` account lockout
- `08:45:10` - Event `4625` account locked out

### Hypothesis 4: Licensing or group-membership drift removing login entitlement path
Judgement: **Contradicts**

Why:
- Entitlement/group issues usually produce authorization failures; provided events indicate authentication failure due to wrong password followed by lockout.
- No event in provided data suggests token issuance blocked by missing license/group.

Determining events:
- `08:44:01` - Event `4776`, wrong-password code `0xC000006A`
- `08:44:03`, `08:44:28`, `08:44:55` - Event `4625`, bad password reason
- `08:44:56` - Event `4740`, account locked out

### Hypothesis 5: Corrupt local credential cache/profile issue on the endpoint (not identity back-end)
Judgement: **Supports**

Why:
- Initial interactive failures and lockout are sourced from `DESKTOP-FB022`, which is consistent with repeated bad credentials from one endpoint context.
- Additional wrong-password Kerberos pre-auth attempts continue from a different source IP, which is consistent with stale credentials on another device/service also trying old credentials.
- This does not prove local profile corruption by itself, but supports the broader stale-credential-source pattern.

Determining events:
- `08:44:03`, `08:44:28`, `08:44:55` - Event `4625`, logon type `2`, source `DESKTOP-FB022`
- `08:44:56` - Event `4740`, caller computer `DESKTOP-FB022`
- `08:45:44`, `08:46:01`, `08:46:33` - Event `4771`, wrong password from source IP `10.10.8.112` (different from `DESKTOP-FB022`)

## Assessment Boundary
- This section only scores evidence against each hypothesis.
- It intentionally does not select a final winning cause yet.

## Surviving Hypothesis After Elimination

### Most likely cause
Account lockout caused by repeated bad password submissions for `FINBRIDGE\cthompson`, with continued wrong-password attempts from at least one additional source.

Why this survives:
- Event `4776` at `08:44:01` shows wrong password (`0xC000006A`).
- Repeated Event `4625` bad-password failures occur at `08:44:03`, `08:44:28`, `08:44:55`.
- Event `4740` at `08:44:56` confirms account lockout.
- Event `4625` at `08:45:10` confirms subsequent login blocked specifically because account is locked.
- Event `4771` at `08:45:44`, `08:46:01`, `08:46:33` shows continued wrong-password attempts from `10.10.8.112`, indicating an additional stale credential source after lockout.

## Detailed Resolution Steps

### 1) Contain and restore user access quickly
1. Confirm account is currently locked in AD/Entra for `cthompson`.
2. Unlock the account.
3. Require immediate password reset (set a temporary strong password if service desk process requires, then force user change at next logon).
4. Ask user to sign in once interactively on `DESKTOP-FB022` with the new password only after step 2 is complete.

Expected result:
- User can complete interactive sign-in if lockout was the primary blocker.

### 2) Stop the repeated bad-credential source(s)
1. Identify owner of source IP `10.10.8.112` from DHCP/IPAM/CMDB.
2. On that device/session, remove or update stored credentials for `FINBRIDGE\cthompson` in:
	- Windows Credential Manager
	- Mapped drives / persistent SMB sessions
	- Outlook/Teams/OneDrive legacy prompts
	- Scheduled tasks and services running under the user context
	- Mobile mail profile if IP maps to mobile gateway/VPN path
3. On `DESKTOP-FB022`, clear stale cached creds for this identity and re-authenticate apps one by one with the new password.

Expected result:
- No new `4771`/`4776` wrong-password events after cleanup window.

### 3) Validate stabilization with event monitoring
1. Monitor Security logs for 15-30 minutes after reset/unlock:
	- Look for absence of new Event `4740` (no re-lockout).
	- Confirm no recurring Event `4771` (`0x18`) or Event `4776` (`0xC000006A`) for `cthompson`.
2. Confirm at least one successful sign-in event for user workflow (interactive and core apps).

Expected result:
- Clean authentication pattern and sustained access.

### 4) Prevent recurrence
1. Educate user to update password on all signed-in devices/apps immediately after change.
2. Remove legacy persistent mappings or old saved credentials discovered during cleanup.
3. If available, enable lockout investigation alerting for repeated bad-password attempts from multiple sources for same user.
4. Record incident note with offending source (`DESKTOP-FB022` and `10.10.8.112`) and remediation actions completed.

## Closure Criteria
- `cthompson` signs in successfully.
- No new lockout Event `4740` during monitoring period.
- No continuing wrong-password events from `DESKTOP-FB022` or `10.10.8.112`.
