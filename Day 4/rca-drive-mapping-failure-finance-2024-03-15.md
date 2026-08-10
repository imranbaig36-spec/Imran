# Root Cause Analysis — Drive Mapping Failure, Finance
**Incident Reference:** DRIVE-MAP-FIN-2024-03-15  
**Date of Incident:** 2024-03-15  
**Date of RCA:** 2024-03-15  
**Analyst:** DWP Engineer  
**Status:** Closed — resolved 09:09, 2024-03-15  
**Severity:** High — all Finance users on targeted devices lost mapped access to `S:` at sign-in

---

## Executive Summary

On the morning of 2024-03-15, all Finance users on `DESKTOP-FB*` devices in `OU=Finance` failed to receive mapped drive `S:`. The failure began at `08:00`, immediately after an overnight change that migrated `Map-FinBridgeDrives.ps1` from a GPO logon script running in user context to an Intune PowerShell script running as SYSTEM.

The Intune Management Extension log showed the script executed as SYSTEM and failed because `\\finbridge-fs01\Finance` was not accessible from SYSTEM context at execution time. The System log then showed the Workstation service entering running state only after the script had already failed, followed by Ntfs Event `98` confirming the drive letter was not assigned. The prior change record explicitly stated the script was not updated to handle SYSTEM context.

Resolution was achieved by applying the recommended correction: removing the failing SYSTEM-context approach and restoring the mapping through a user-context method. Service was confirmed restored at `09:09`, when user sign-in to the host was verified and no further issues were reported.

---

## Incident Timeline

| Time | Event |
|---|---|
| 2024-03-14 23:30 | Change implemented: `Map-FinBridgeDrives.ps1` migrated from GPO logon script (runs as user) to Intune PowerShell script (runs as SYSTEM). |
| 2024-03-14 23:30 | Change note records that the script was **not updated** to handle SYSTEM context and that UNC access plus mapped credentials are not available to SYSTEM at login time. |
| 2024-03-15 08:00:01 | Intune Management Extension ScriptRunner Info: `Executing: Map-FinBridgeDrives.ps1`. |
| 2024-03-15 08:00:02 | ScriptRunner Info: `Script context: SYSTEM account`. |
| 2024-03-15 08:00:03 | ScriptRunner Warning: `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time`. |
| 2024-03-15 08:00:03 | ScriptRunner Error: `Script Map-FinBridgeDrives.ps1 failed. Exit code: 1. Error: Network name cannot be found.` |
| 2024-03-15 08:00:04 | ScriptRunner Info: `No retry configured.` |
| 2024-03-15 08:00:05 | Service Control Manager Event `7036`: `Workstation service entered running state.` |
| 2024-03-15 08:00:06 | GroupPolicy Event `1500`: `Group Policy settings processed successfully.` This confirms Group Policy itself is healthy and not causal. |
| 2024-03-15 08:00:07 | Ntfs Event `98` Warning: `File system could not map drive letter S: Drive letter has not been assigned.` |
| 2024-03-15 ~08:10 | Incident reported to DWP engineering after Finance users observed missing `S:` mapping. |
| 2024-03-15 ~08:20 to 08:45 | Initial scope analysis ranked execution-context change as most likely cause; event review confirmed it. |
| 2024-03-15 ~08:45 | Corrective action applied: failing SYSTEM-context deployment removed/disabled and drive mapping restored through a user-context method. |
| 2024-03-15 ~08:55 | Pilot validation performed on affected Finance host. `S:` mapping restored in the interactive session and no repeat failure observed. |
| 2024-03-15 09:09 | Resolution confirmed. User logon to host verified successfully and no issues reported. Incident closed. |

---

## Scope and Impact

| Item | Detail |
|---|---|
| Symptom | `Map-FinBridgeDrives.ps1` failed; drive letter `S:` not assigned |
| Affected users | All Finance users |
| Affected devices | `DESKTOP-FB*` devices in `OU=Finance` |
| Unaffected area | Group Policy processing itself remained healthy |
| Start time | `08:00` on 2024-03-15 |
| Business impact | Finance users could not access the expected mapped share via `S:` at sign-in |
| Resolution time | `09:09` |

---

## Supporting Evidence

### Intune Management Extension Evidence

| Time | Source | Level | Evidence |
|---|---|---|---|
| 08:00:01 | ScriptRunner | Info | `Executing: Map-FinBridgeDrives.ps1` |
| 08:00:02 | ScriptRunner | Info | `Script context: SYSTEM account` |
| 08:00:03 | ScriptRunner | Warning | `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time` |
| 08:00:03 | ScriptRunner | Error | `Exit code: 1. Error: Network name cannot be found.` |
| 08:00:04 | ScriptRunner | Info | `No retry configured.` |

Interpretation:
- The script did run.
- It ran in the wrong context for a user-visible drive mapping.
- The failure reason was explicit and context-specific, not a generic script crash.

### System Log Evidence — DESKTOP-FB041

| Time | Event ID | Source | Level | Evidence |
|---|---|---|---|---|
| 08:00:05 | 7036 | Service Control Manager | Information | `Workstation service entered running state.` |
| 08:00:06 | 1500 | GroupPolicy | Information | `Group Policy settings processed successfully.` |
| 08:00:07 | 98 | Ntfs | Warning | `File system could not map drive letter S: Drive letter has not been assigned.` |

Interpretation:
- The Workstation service became ready only after the mapping script had already failed.
- Group Policy success rules out a Group Policy processing fault.
- Event `98` confirms the user-facing symptom directly: `S:` was not assigned.

### Change Record Evidence

| Time | Evidence |
|---|---|
| 2024-03-14 23:30 | `Map-FinBridgeDrives.ps1` moved from GPO logon script (user) to Intune PowerShell script (SYSTEM) |
| 2024-03-14 23:30 | Change note: script not updated to handle SYSTEM context |
| 2024-03-14 23:30 | Change note: UNC access and mapped credentials are not available to SYSTEM at login time |

Interpretation:
- The known change matches the failure mode exactly.
- The change note already described the limitation later observed in the incident logs.

### Validation Evidence After Fix

| Time | Evidence |
|---|---|
| ~08:55 | Corrected user-context mapping validated on an affected Finance host |
| 09:09 | User logon to host verified successfully |
| 09:09 | No issues reported after sign-in |

---

## Root Cause

**`Map-FinBridgeDrives.ps1` was migrated from a GPO logon script that ran in the signed-in user's context to an Intune PowerShell script that ran as SYSTEM, but the script and delivery design were not reworked for that new execution context. As a result, the script attempted to access `\\finbridge-fs01\Finance` and create mapped drive `S:` without the required user-session context, user credentials, and session visibility. The mapping failed before the Workstation service was fully ready, and no retry path existed.**

### Contributing Factors

1. The migration changed execution context from user to SYSTEM for a workflow that is inherently user-session dependent.
2. The script was not updated to include context validation, readiness checks, or retry behavior.
3. The mapping attempt occurred before the Workstation service was confirmed running.
4. No rollback or pilot control appears to have stopped the broader Finance deployment before user impact.

---

## 5-Why Analysis

| Why | Finding |
|---|---|
| Why was `S:` missing for Finance users? | Because `Map-FinBridgeDrives.ps1` failed and the drive letter was never assigned. Evidence: ScriptRunner error at `08:00:03`; Ntfs Event `98` at `08:00:07`. |
| Why did `Map-FinBridgeDrives.ps1` fail? | Because it attempted to access `\\finbridge-fs01\Finance` from SYSTEM context and the path was not accessible in that context at execution time. Evidence: ScriptRunner Warning at `08:00:03`. |
| Why was the script running in SYSTEM context? | Because the mapping process had been migrated from a GPO user logon script to an Intune PowerShell script configured to run as SYSTEM. Evidence: change record `2024-03-14 23:30`; ScriptRunner Info `08:00:02`. |
| Why did the migration break the mapping instead of continuing to work? | Because the script and its deployment design were not updated for SYSTEM limitations and still depended on user-context SMB access and user-session drive mapping behavior. Evidence: change note explicitly states the script was not updated to handle SYSTEM context. |
| Why was this allowed into production? | Because the change process did not enforce a control to validate execution context, startup dependencies, and user-session side effects before deploying a GPO-to-Intune script migration to the Finance target group. |

**Root cause statement:** A user-context drive mapping workflow was moved to a SYSTEM-context deployment model without redesign or pre-production validation for context and startup dependencies.

---

## Hypothesis Elimination Record

| Hypothesis | Verdict | Eliminated or Confirmed By |
|---|---|---|
| Script now runs as SYSTEM and cannot access the Finance UNC path in the required user context | Confirmed root cause | ScriptRunner `08:00:02` and `08:00:03`; change note `2024-03-14 23:30` |
| Intune script fires before network/Workstation stack is ready | Confirmed contributing factor | Script fails at `08:00:03`; Workstation service starts at `08:00:05` |
| Script still contains user-session mapping logic that does not work in SYSTEM | Confirmed contributing factor | Change note `2024-03-14 23:30`; Ntfs Event `98` at `08:00:07` |
| Intune deployment configuration or targeting fault | Not supported as primary cause | ScriptRunner shows the script executed successfully as a deployment action |
| Genuine backend share outage independent of migration | Eliminated | Failure text is context-specific; no supplied share or server outage evidence |

---

## Corrective Actions Taken

| Step | Action | Outcome |
|---|---|---|
| 1 | Identified that the deployed script was running as SYSTEM and failing on the Finance UNC path | Root cause confirmed |
| 2 | Disabled or removed the failing SYSTEM-context Intune deployment for the Finance target | Repeated failure path stopped |
| 3 | Restored the mapping through a user-context method appropriate for interactive user sessions | Mapping could occur in the correct security/session context |
| 4 | Validated sign-in and drive mapping on an affected Finance host | `S:` restored in user session |
| 5 | Verified user logon to host at `09:09` with no issues reported | Incident closed |

---

## Recovery Validation

The fix was considered successful based on the following closure evidence:

1. Affected user logon to the host was verified successfully at `09:09`.
2. No issues were reported after sign-in.
3. The user-context mapping method restored the expected access path.
4. The prior SYSTEM-context failure mode was removed from active use for the Finance target.

---

## Preventive Actions

| # | Action | Owner | Priority | Due |
|---|---|---|---|---|
| PA-1 | Update the GPO-to-Intune migration runbook to require an explicit execution-context review for every migrated script. | Endpoint Engineering | Critical | Before next migration |
| PA-2 | Classify mapped drives, printers, and other user-visible session artifacts as user-context actions by default unless a supported exception is documented. | Endpoint Engineering | Critical | Before next migration |
| PA-3 | Add a mandatory pilot stage for script migrations affecting business-unit-wide login behavior, with at least one representative user/device validation before broad rollout. | Change Manager | High | Next change cycle |
| PA-4 | Require startup dependency validation in script design: verify Workstation/network readiness before accessing UNC paths. | Engineering Standards Owner | High | Next sprint |
| PA-5 | Add bounded retry and clear failure logging to any mapping/remediation script that depends on early sign-in services. | Endpoint Engineering | Medium | Next sprint |
| PA-6 | Add a rollback checkpoint to change records for context-changing script migrations so the previous working delivery method can be restored quickly. | Change Manager | High | Next change cycle |
| PA-7 | Review current Intune PowerShell deployments for other user-session tasks that may have been moved to SYSTEM without redesign. | DWP Engineer / Endpoint Team | High | Within 10 business days |

---

## Lessons Learned

1. Execution context is part of the design, not just a deployment setting. A script that works in a user logon workflow cannot be assumed to work under SYSTEM.
2. User-visible mapped drives are session-bound artifacts and should normally be created in user context.
3. Startup timing matters. Even a correct script can fail if it depends on SMB before the Workstation service is ready.
4. The change note already contained the key risk. That risk was not converted into a deployment gate or pilot control.
5. Explicit retry and prerequisite checks would have reduced user impact even if the design flaw still existed.

---

## Final Status

- Status: **Resolved**
- Resolution confirmed: **09:09 AM, 2024-03-15**
- Closure evidence: **Verified user logon to host; no issues reported**
- Confidence in root cause: **High**

---

*RCA prepared by DWP Engineer | 2024-03-15 | Incident closed 09:09*