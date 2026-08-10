# Drive Mapping Failure Hypothesis - Finance (2024-03-15)

## Scope Facts Used
- Symptom: `Map-FinBridgeDrives.ps1` failed and drive letter `S:` was not assigned
- Affected users: all Finance users on `DESKTOP-FB*` devices in `OU=Finance`
- Started: `08:00` this morning
- Known change: `2024-03-14 23:30` migration from GPO logon script (runs as user) to Intune PowerShell script (runs as SYSTEM)

## Ranked Most Likely Causes (Most Probable First)

### 1) Script now runs as SYSTEM and cannot access the Finance UNC path in the required user context
Why this fits scope facts:
- The timing lines up exactly with the overnight migration from a user-context GPO logon script to an Intune script that runs as SYSTEM.
- The blast radius is broad but specific: all Finance users on the targeted Finance estate, which matches a centrally deployed script-context change.
- Drive mapping is a user-session activity. A script that worked when run as the signed-in user can fail when moved to SYSTEM if it depends on user security context, user token, or user-available SMB access.

Single fastest check:
- On one affected device, confirm the Intune execution context for `Map-FinBridgeDrives.ps1` and test whether `\\finbridge-fs01\Finance` is reachable from SYSTEM at execution time.

### 2) The Intune script is firing before the network/Workstation stack is ready, so the UNC path is unavailable at that moment
Why this fits scope facts:
- The failure started at the same time for all affected users, which is consistent with a startup or logon timing problem introduced by the new deployment method.
- A GPO logon script and an Intune PowerShell script do not run at the same point in the sign-in sequence; the migration could have moved execution earlier.
- If the script runs before SMB client services are ready, the share path can fail even if the share is healthy later.

Single fastest check:
- Compare the script execution timestamp with the Workstation service startup time on an affected device and rerun the UNC access test after the service is confirmed running.

### 3) The script still contains user-session drive-mapping logic that does not work when executed in SYSTEM
Why this fits scope facts:
- The symptom is specifically that `S:` is not assigned, which can happen if the script still relies on user-scoped mapping behavior.
- A script written for a GPO logon workflow may assume the interactive user session exists and that the mapped drive should appear in that session.
- The migration note says the script itself was not updated for the new context, which makes logic assumptions inside the script a plausible cause.

Single fastest check:
- Inspect `Map-FinBridgeDrives.ps1` for user-scoped commands or assumptions such as interactive-session drive mapping, user-profile paths, or persistence settings that only make sense in a user context.

### 4) The Intune deployment configuration is wrong for the Finance target set or is missing a recovery path after first failure
Why this fits scope facts:
- A broad OU-scoped impact can come from a deployment/configuration issue affecting all targeted Finance endpoints.
- If the deployment was moved centrally and no retry was designed, one bad execution window at first sign-in could leave all users without mappings.
- This is less likely than a context problem because the script name is reported as having run, but it remains a credible control-plane cause.

Single fastest check:
- Review the Intune assignment and execution settings for the script on a few affected devices to confirm it is targeted as intended and whether retry behavior is configured.

### 5) The Finance file share or name resolution path was genuinely unavailable at 08:00, independent of the context migration
Why this fits scope facts:
- All Finance users losing the same drive at the same time can also be explained by a shared backend outage on `\\finbridge-fs01\Finance`.
- The symptom mentions a specific script failure and missing drive letter, which could occur if the destination path was down.
- It ranks lowest because the only known change is the execution-context migration, which is a tighter fit to the start time and audience.

Single fastest check:
- From a normal user context on any unaffected or admin test machine, test access to `\\finbridge-fs01\Finance` at the incident time window or against current server/service logs.

## Notes
- This is a ranked hypothesis list only.
- No single cause is selected as the winner at this stage.

## Evidence Assessment Against Incident Logs

Affected estate evidence reviewed:
- Intune Management Extension log
- System log from `DESKTOP-FB041`
- Prior change note for the migration at `2024-03-14 23:30`

### Hypothesis 1: Script now runs as SYSTEM and cannot access the Finance UNC path in the required user context
Judgement: **Supports**

Why:
- The log explicitly states the script executed under SYSTEM.
- The failure message is not generic; it specifically says the network path was not accessible from SYSTEM context at execution time.
- The change note says the script was migrated without being updated to handle SYSTEM context.

Determining events:
- `08:00:02` - ScriptRunner Info: `Script context: SYSTEM account`
- `08:00:03` - ScriptRunner Warning: `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time`
- `08:00:03` - ScriptRunner Error: `Exit code: 1. Error: Network name cannot be found.`

### Hypothesis 2: The Intune script is firing before the network/Workstation stack is ready, so the UNC path is unavailable at that moment
Judgement: **Supports**

Why:
- The script fails before the Workstation service is logged as running.
- That timing matches a startup race where UNC access is attempted too early.
- The lack of retry keeps an early transient failure user-visible.

Determining events:
- `08:00:03` - ScriptRunner Error: script failed on UNC access before network client readiness is confirmed
- `08:00:04` - ScriptRunner Info: `No retry configured.`
- `08:00:05` - Service Control Manager Event `7036`: `Workstation service entered running state`

### Hypothesis 3: The script still contains user-session drive-mapping logic that does not work when executed in SYSTEM
Judgement: **Supports**

Why:
- The prior change note says the script was not updated for SYSTEM context after migration.
- That directly supports the possibility that the script logic still assumes user-context behavior.
- The resulting symptom, `S:` not assigned, is consistent with user-session mapping assumptions surviving the migration.

Determining events:
- `08:00:02` - ScriptRunner Info: `Script context: SYSTEM account`
- `08:00:07` - Ntfs Event `98`: `File system could not map drive letter S: Drive letter has not been assigned.`
- `2024-03-14 23:30` - Prior change note: `Script not updated to handle SYSTEM context`

### Hypothesis 4: The Intune deployment configuration is wrong for the Finance target set or is missing a recovery path after first failure
Judgement: **Neutral**

Why:
- The script definitely executed, so the evidence does not support a targeting failure or execution-policy block.
- The `No retry configured` entry does support the narrower point that failure recovery was not designed in.
- Overall, the logs point more directly to context and timing than to an Intune targeting/configuration mistake.

Determining events:
- `08:00:01` - ScriptRunner Info: `Executing: Map-FinBridgeDrives.ps1`
- `08:00:04` - ScriptRunner Info: `No retry configured.`

### Hypothesis 5: The Finance file share or name resolution path was genuinely unavailable at 08:00, independent of the context migration
Judgement: **Contradicts**

Why:
- The strongest log wording is context-specific: the path was not accessible from SYSTEM context, not universally unavailable.
- The prior change note explains that UNC access and mapped credentials are not available to SYSTEM at login time, which is a more specific fit than a backend outage.
- There is no supplied event showing a wider share outage, DFS issue, or server-side fault.

Determining events:
- `08:00:03` - ScriptRunner Warning: `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time`
- `08:00:03` - ScriptRunner Error: `Network name cannot be found.`
- `08:00:05` - Service Control Manager Event `7036`: network client readiness occurs after the script already failed

## Evidence Summary Table

| Rank | Hypothesis | Evidence judgement | Determining log reference |
|---|---|---|---|
| 1 | SYSTEM context cannot access required UNC path for drive mapping | Supports | ScriptRunner `08:00:02`, ScriptRunner `08:00:03` |
| 2 | Script fires before network/Workstation stack is ready | Supports | ScriptRunner `08:00:03`; Event `7036` at `08:00:05` |
| 3 | Script logic still assumes user-session mapping behavior | Supports | ScriptRunner `08:00:02`; Event `98` at `08:00:07`; change note `2024-03-14 23:30` |
| 4 | Intune deployment configuration/assignment issue | Neutral | ScriptRunner `08:00:01`; ScriptRunner `08:00:04` |
| 5 | Genuine backend share or name-resolution outage independent of context | Contradicts | ScriptRunner `08:00:03`; Event `7036` at `08:00:05` |

## Assessment Boundary
- This note ranks hypotheses and scores the supplied evidence against each one.
- It does not select a final root cause yet.

## Surviving Hypothesis After Elimination

### Most likely cause
The drive mapping script was migrated from a user-context GPO logon script to an Intune PowerShell script running as SYSTEM, and the script was not redesigned for that execution context.

Why this survives:
- `08:00:02` explicitly records `Script context: SYSTEM account`.
- `08:00:03` explicitly records `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time`.
- The change note states the migration occurred at `2024-03-14 23:30` and that the script was not updated to handle SYSTEM context.
- The other supported observations fit as contributing mechanics of the same root cause, not separate competing causes:
  - the script ran before the Workstation service was fully ready
  - the script still behaved like a user-session drive-mapping script

## Detailed Resolution Steps

### 1) Immediate containment: restore Finance access quickly
1. Remove or disable the failing Intune PowerShell deployment for `Map-FinBridgeDrives.ps1` for the Finance target group so repeated SYSTEM-context failures stop.
2. Restore a working user-context mapping method for Finance users:
	- either temporarily re-enable the previous GPO logon script
	- or deploy the mapping as a user-context mechanism such as a user logon script, user-targeted scheduled task, or Intune-delivered user-context remediation
3. Force one affected device to sign out and sign back in after the temporary restoration.

Expected result:
- `S:` is assigned in the signed-in user's session and Finance users regain access without waiting for a code rewrite.

### 2) Correct the implementation: redesign the script for the right execution model
1. Decide the intended delivery model:
	- if the goal is a visible mapped drive letter in Explorer, keep the action in user context
	- do not use SYSTEM to create a user-session drive letter unless there is an explicit handoff into the interactive user session
2. Update `Map-FinBridgeDrives.ps1` so it no longer assumes SYSTEM can directly map the user's `S:` drive.
3. If Intune must remain the delivery channel, convert the design to one of these supported patterns:
	- deploy a scheduled task that runs at user logon in the user's security context
	- deploy a user-context script/remediation package
	- replace drive-letter mapping with a solution that does not depend on user-session mapped drives, if the business workflow allows it
4. Add explicit pre-checks in the script before mapping:
	- confirm the current security context is the intended one
	- confirm the Workstation service is running
	- confirm `\\finbridge-fs01\Finance` is reachable
	- log a clear failure reason and exit cleanly if prerequisites are missing

Expected result:
- The mapping process runs in the correct context and no longer depends on unsupported SYSTEM behavior.

### 3) Fix the timing weakness
1. Ensure the mapping action runs after the user's session and SMB client stack are ready.
2. If using a scheduled task, trigger it `At log on` for the user and add a short startup delay or a readiness check for the Workstation service.
3. Add a bounded retry mechanism in the script for transient early-logon failures:
	- test the UNC path
	- retry a small number of times with short intervals
	- stop with a clear log message if the path never becomes available

Expected result:
- Short-lived network initialization races no longer cause permanent missing-drive symptoms for the day.

### 4) Validate on one pilot device before broad redeployment
1. Choose one affected Finance workstation such as `DESKTOP-FB041`.
2. Run a controlled test sign-in with the corrected delivery method.
3. Confirm all of the following:
	- `S:` appears in File Explorer for the user
	- `Test-Path \\finbridge-fs01\Finance` succeeds in the user session
	- no new ScriptRunner failure is logged for the old SYSTEM-context path
	- no Ntfs Event `98` is generated for missing drive-letter assignment
4. Repeat on at least one second Finance device to rule out machine-specific variance.

Expected result:
- The corrected approach proves stable on representative Finance endpoints before wider rollout.

### 5) Redeploy safely and monitor
1. Roll out the corrected user-context mapping method to the Finance target set.
2. Keep the old SYSTEM-context script disabled or removed so both methods do not compete.
3. Monitor the first post-deployment sign-ins for:
	- absence of ScriptRunner failure entries around `08:00`
	- absence of Ntfs Event `98`
	- successful user access to `S:`
4. Capture a short validation sample across several Finance endpoints before closing the incident.

Expected result:
- Finance users consistently receive the mapped drive at sign-in and the incident does not recur on the next business day.

### 6) Prevent recurrence in change control
1. Update the migration runbook to mark drive-letter mapping as a user-context function unless explicitly engineered otherwise.
2. Add a pre-deployment gate for any GPO-to-Intune script migration:
	- verify execution context
	- verify service/network readiness dependencies
	- verify whether the script creates user-visible artifacts such as mapped drives, printers, or profile content
3. Require pilot validation on at least one affected business unit before full assignment.
4. Require rollback instructions to be documented before cutover.

Expected result:
- Future script migrations do not fail by moving user-session actions into SYSTEM without redesign.

---

## Appended Analysis Addendum

### Event Details - Incident Window

#### Intune Management Extension Log
- `08:00:01` - ScriptRunner Info: `Executing: Map-FinBridgeDrives.ps1`
- `08:00:02` - ScriptRunner Info: `Script context: SYSTEM account`
- `08:00:03` - ScriptRunner Warning: `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time`
- `08:00:03` - ScriptRunner Error: `Script Map-FinBridgeDrives.ps1 failed. Exit code: 1. Error: Network name cannot be found.`
- `08:00:04` - ScriptRunner Info: `No retry configured.`

#### System Log - DESKTOP-FB041
- `08:00:05` - Service Control Manager Event `7036`: `Workstation service entered running state.`
- `08:00:06` - GroupPolicy Event `1500`: `Group Policy settings processed successfully.`
- `08:00:07` - Ntfs Event `98` Warning: `File system could not map drive letter S: Drive letter has not been assigned.`

#### Prior Change Record
- `2024-03-14 23:30` - `Map-FinBridgeDrives.ps1` migrated from GPO logon script running as user to Intune PowerShell script running as SYSTEM.
- Change note states the script was not updated to handle SYSTEM context and that UNC access plus mapped credentials are not available to SYSTEM at login time.

### Surviving Hypothesis

The surviving hypothesis is that the Finance drive mapping failed because `Map-FinBridgeDrives.ps1` was moved from a user-context GPO logon script to a SYSTEM-context Intune script, and the script was left dependent on user-context SMB access and user-session drive mapping behavior.

Why this survives elimination:
- The evidence is direct rather than inferred: `08:00:02` confirms SYSTEM context.
- The failure reason is explicit: `08:00:03` states the UNC path was not accessible from SYSTEM context.
- The timing strengthens the same hypothesis: Workstation service readiness is logged only at `08:00:05`, after the script had already failed.
- The user-visible symptom matches the same failure chain: Event `98` at `08:00:07` confirms `S:` was never assigned.
- No supplied evidence shows a wider server-side outage, Intune targeting failure, or Group Policy fault.

### Resolution Addendum

#### Immediate recovery
1. Disable or unassign the current Intune SYSTEM-context deployment for `Map-FinBridgeDrives.ps1` for the Finance target.
2. Restore drive mapping through a user-context method so Finance users can work immediately:
	- re-enable the former GPO logon script temporarily, or
	- deploy a user-context scheduled task or user-context Intune remediation at logon.
3. Have one affected Finance user sign out and back in to confirm `S:` returns in the interactive session.

#### Permanent correction
1. Redesign the mapping process so the drive letter is created in the signed-in user's session, not by SYSTEM.
2. If Intune remains the delivery mechanism, use a user-context execution pattern rather than a device-context PowerShell script.
3. Add prerequisite checks before mapping:
	- confirm intended execution context
	- confirm Workstation service is running
	- confirm `\\finbridge-fs01\Finance` is reachable
4. Add bounded retry logic so a short startup timing miss does not leave the user without the drive for the rest of the session.

#### Validation after fix
1. Test on one affected device such as `DESKTOP-FB041`.
2. Confirm `S:` appears in File Explorer for the Finance user after sign-in.
3. Confirm there are no new ScriptRunner failures for `Map-FinBridgeDrives.ps1`.
4. Confirm no new Ntfs Event `98` for missing drive assignment is logged.
5. Roll out to the remaining Finance devices only after the pilot passes.

#### Prevention
1. Add a migration control requiring review of execution context whenever moving scripts from GPO to Intune.
2. Flag mapped drives, printers, and profile-affecting actions as user-context activities by default.
3. Require pilot validation and rollback steps before broad deployment of any context-changing script migration.