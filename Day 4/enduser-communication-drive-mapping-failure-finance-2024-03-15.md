# End-User Communication — Drive Mapping Failure, Finance (2024-03-15)

## Audience 1 - Non-technical executive
Your access has been restored and your data is safe. From 08:00, Finance users on affected Finance PCs did not receive the Finance shared drive (S:) after an overnight change moved that connection step out of the normal sign-in process, so the Finance folder was not reached. We reversed that change and restored the normal sign-in method. Access was verified at 09:09 with no further issues reported. No action is required unless the issue returns.

## Audience 2 - Affected end-user team (10 people, non-technical)
Your access is restored and your data is safe. This morning from 08:00, Finance users on affected Finance PCs did not get the Finance shared drive (S:) because an overnight change made that connection run at the wrong point during sign-in, so the Finance folder was not reached. We restored the normal sign-in method, and access was verified at 09:09 with no further issues reported. If you see the same issue again, contact the DWP Service Desk and tell them your device name and the time it happened.

## Audience 3 - Engineer-to-engineer internal note
Access restored; no data loss.

Incident facts:
- Scope: All Finance users on `DESKTOP-FB*` devices in `OU=Finance`.
- Symptom: `Map-FinBridgeDrives.ps1` failed and `S:` was not assigned.
- Start: `08:00` on 2024-03-15.
- Change: `2024-03-14 23:30` migration from GPO logon script (runs as user) to Intune PowerShell script (runs as SYSTEM).
- Resolution confirmed: `09:09`; verified user logging in to host, no issues reported.

Root cause:
- User-context drive mapping workflow was moved to SYSTEM context without redesign.
- Script attempted access to `\\finbridge-fs01\Finance` from SYSTEM context and could not create a user-visible `S:` mapping.
- Timing contributed: script failed before Workstation service readiness was logged.

Supporting evidence:
- `08:00:01` ScriptRunner Info: `Executing: Map-FinBridgeDrives.ps1`
- `08:00:02` ScriptRunner Info: `Script context: SYSTEM account`
- `08:00:03` ScriptRunner Warning: `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time`
- `08:00:03` ScriptRunner Error: `Exit code: 1. Error: Network name cannot be found.`
- `08:00:04` ScriptRunner Info: `No retry configured.`
- `08:00:05` SCM Event `7036`: `Workstation service entered running state.`
- `08:00:06` GroupPolicy Event `1500`: GP processed successfully; not a GP fault.
- `08:00:07` Ntfs Event `98`: `File system could not map drive letter S: Drive letter has not been assigned.`
- Change note `2024-03-14 23:30`: script not updated to handle SYSTEM context; UNC access and mapped credentials not available to SYSTEM at login time.

Exact action taken:
1. Identified the failing SYSTEM-context Intune deployment as the causal path.
2. Disabled or removed the SYSTEM-context deployment for `Map-FinBridgeDrives.ps1` for the Finance target.
3. Restored drive mapping through a user-context method.
4. Validated on an affected Finance host.
5. Verified user logon to host at `09:09`; no further issues reported.

Config detail:
- Previous working model: GPO logon script, user context.
- Failing model: Intune PowerShell script, SYSTEM context.
- Target path: `\\finbridge-fs01\Finance`
- Drive letter: `S:`
- Affected target set: `DESKTOP-FB*`, `OU=Finance`

Verification step:
- Confirmed successful user logon after corrective action at `09:09`.
- Confirmed no issues reported after sign-in.
- Confirmed corrected method restored expected access path in user context.

Preventive action needed:
1. Add mandatory execution-context review to every GPO-to-Intune script migration.
2. Treat mapped drives, printers, and other user-session artifacts as user-context actions by default.
3. Require pilot validation before wide deployment of any context-changing script migration.
4. Add startup dependency checks and bounded retry logic for scripts that touch UNC resources during sign-in.
5. Keep rollback steps in the change record before cutover.

User direction:
- If the same symptom recurs, collect device name, affected user, and incident time, then check ScriptRunner entries around sign-in plus Event `7036`, Event `1500`, and Ntfs Event `98` on the host.