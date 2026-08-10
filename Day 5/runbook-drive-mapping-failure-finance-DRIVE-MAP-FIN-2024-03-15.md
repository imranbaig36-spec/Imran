# Runbook — Finance Mapped Drive Failure (`S:` Not Assigned at Sign-in)
**Runbook Reference:** DRIVE-MAP-FIN-2024-03-15  
**Derived From:** RCA DRIVE-MAP-FIN-2024-03-15  
**Scope:** Finance users on `DESKTOP-FB*` devices in `OU=Finance` missing mapped drive `S:` at sign-in  
**Last Updated:** 2026-08-10  

---

## 1. Prerequisites

Before starting, confirm you have the following in place:

| # | Requirement | Detail |
|---|---|---|
| 1 | **Intune RBAC role** — Policy and Profile Manager or higher | Required to view, disable, and reassign PowerShell script deployments. **Elevated permission required.** |
| 2 | **Azure AD / Entra ID access** — read access to device and group membership | Required to confirm device targeting and deployment scope. |
| 3 | **Local admin or remote admin on an affected Finance host** | Required to review logs and validate the fix on a representative device. **Elevated permission required.** |
| 4 | **Access to Intune portal** (`intune.microsoft.com`) | Used to inspect and modify the PowerShell script deployment. |
| 5 | **Access to affected device logs** — Event Viewer or remote log collection tool | You will need the System log and the Intune Management Extension log at `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`. |
| 6 | **Confirmation of the impacted script name** | Script involved in this incident: `Map-FinBridgeDrives.ps1`. Confirm this is the script currently deployed before making changes. |
| 7 | **A known-good delivery method ready** | You must have a user-context delivery method available (GPO logon script or Intune user-context assignment) before removing the failing SYSTEM-context deployment. Do not remove without a replacement ready. |

---

## 2. Procedure

### Phase 1 — Confirm the Failure

**Step 1.** On an affected `DESKTOP-FB*` device, open Event Viewer and navigate to `Windows Logs > System`.  
*Expected result:* You find Ntfs Event `98` Warning: `File system could not map drive letter S: Drive letter has not been assigned.`

**Step 2.** In the same System log, check the timestamp of Service Control Manager Event `7036` for the Workstation service.  
*Expected result:* The Workstation service entered running state **after** the Ntfs Event `98` (i.e., the mapping was attempted before the network stack was ready).

**Step 3.** Open the Intune Management Extension log at `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` on the affected device.  
*Expected result:* You find log entries confirming:
- `Executing: Map-FinBridgeDrives.ps1`
- `Script context: SYSTEM account`
- `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time`
- `Exit code: 1. Error: Network name cannot be found.`

**Step 4.** Check GroupPolicy Event `1500` in the System log.  
*Expected result:* Entry reads `Group Policy settings processed successfully.` — this rules out a Group Policy fault. If this event shows an error, stop and raise a separate GPO investigation; do not continue this runbook.

---

### Phase 2 — Identify and Disable the Failing Deployment

> **⚠ Elevated permission required for Steps 5–8.**

**Step 5.** Sign in to `intune.microsoft.com` with your Intune Policy and Profile Manager account.

**Step 6.** Navigate to: **Devices > Scripts and remediations > Platform scripts**, and locate `Map-FinBridgeDrives.ps1`.  
*Expected result:* The script is listed and targeted at a group containing `DESKTOP-FB*` devices or the `OU=Finance` equivalent Azure AD group.

**Step 7.** Open the script assignment properties and confirm the **Run this script using the logged on credentials** setting is set to **No** (i.e., it is running as SYSTEM).  
*Expected result:* You confirm the script is running as SYSTEM, matching the failure mode in the logs.

**Step 8.** Disable or remove the assignment of `Map-FinBridgeDrives.ps1` from the Finance device group.  
- To disable: set the assignment to **Unassigned** or remove the Finance group from the assignment.  
- Do **not** delete the script itself — retain it for audit purposes.  
*Expected result:* The Finance device group no longer has an active assignment for `Map-FinBridgeDrives.ps1` running as SYSTEM. No new executions will be triggered on next sign-in.

---

### Phase 3 — Restore the Drive Mapping via User Context

**Step 9.** Confirm your replacement delivery method before proceeding. Choose one of the following:
- **Option A — GPO logon script (preferred):** Re-enable or create a GPO logon script targeting `OU=Finance` that runs `Map-FinBridgeDrives.ps1` as the signed-in user.
- **Option B — Intune user-context script:** In Intune, re-upload or re-assign `Map-FinBridgeDrives.ps1` with **Run this script using the logged on credentials** set to **Yes**, assigned to the Finance user group (not device group).

**Step 10 (Option A).** Open Group Policy Management Console (`gpmc.msc`). **[Elevated permission required]**  
Navigate to the GPO linked to `OU=Finance`, or create a new GPO linked to that OU.  
Add `Map-FinBridgeDrives.ps1` as a **User Configuration > Windows Settings > Scripts (Logon/Logoff) > Logon** script.  
*Expected result:* The script appears as a logon script in the GPO for the Finance OU.

**Step 10 (Option B).** In the Intune portal, open the existing `Map-FinBridgeDrives.ps1` script or upload a new copy.  
Set **Run this script using the logged on credentials** to **Yes**.  
Assign it to the Finance **user** group.  
*Expected result:* The script is assigned in user context and will execute at the next user sign-in cycle.

**Step 11.** Force a Group Policy update or Intune sync on the pilot device before broader validation:
- For GPO: on the pilot device, run `gpupdate /force` in an elevated Command Prompt.
- For Intune: in the Intune portal, select the target device and choose **Sync**, or run `%windir%\system32\deviceenrollment\dmclient.exe` to trigger a manual sync.  
*Expected result:* Policy or script assignment is refreshed on the pilot device.

---

## 3. Verification

Perform all verification steps on at least one representative `DESKTOP-FB*` Finance device before confirming the fix is complete.

**Step 12.** Sign a Finance test user out of the pilot device, then sign them back in.  
*Expected result:* The user's desktop loads without error.

**Step 13.** Open File Explorer on the pilot device after sign-in.  
*Expected result:* Drive `S:` appears under **This PC** and is accessible. Double-click `S:` to confirm it opens the `\\finbridge-fs01\Finance` share content.

**Step 14.** Open Event Viewer on the pilot device. Check `Windows Logs > System` for Ntfs Event `98`.  
*Expected result:* No new Ntfs Event `98` entries are present after the sign-in performed in Step 12.

**Step 15.** Check the Intune Management Extension log (if Option B was used) for a new execution of `Map-FinBridgeDrives.ps1`.  
*Expected result:* Log shows `Script context: logged on user` (not SYSTEM) and exit code `0`.

**Step 16.** Contact the Finance user who performed the test sign-in (or the reporting user) and confirm `S:` is accessible and no issues are reported.  
*Expected result:* User confirms drive is present and working. Document the confirmation time for the incident record.

---

## 4. Rollback

Use this section if the procedure in Phase 3 makes the situation worse, or if verification in Section 3 fails.

**Rollback Step R1.** If Option B (Intune user-context) was applied and the sign-in now fails entirely or produces new errors, immediately remove the Intune script assignment from the Finance user group in the Intune portal. **[Elevated permission required]**  
*Expected result:* The script no longer runs at sign-in. Users may still lack `S:`, but no new breakage is introduced.

**Rollback Step R2.** If Option A (GPO logon script) was applied and sign-in now fails, open GPMC, locate the GPO modified in Step 10, and remove `Map-FinBridgeDrives.ps1` from the Logon scripts list. Run `gpupdate /force` on the affected device. **[Elevated permission required]**  
*Expected result:* The GPO logon script is no longer active. Users may still lack `S:`, but the new failure mode is stopped.

**Rollback Step R3.** Confirm that the SYSTEM-context Intune assignment (disabled in Step 8) remains disabled. Do **not** re-enable it — this is the confirmed root cause and reinstating it will reproduce the incident.

**Rollback Step R4.** If `S:` is still missing after rollback and users are in production, apply a temporary manual workaround:  
- Ask the affected user to run the following from an elevated Command Prompt while signed in:  
  `net use S: \\finbridge-fs01\Finance /persistent:no`  
- This maps the drive for the current session only. It is a stop-gap, not a fix.

**Rollback Step R5.** Raise a P1/P2 incident ticket if the situation cannot be stabilised within 30 minutes of starting the rollback. Escalate to Endpoint Engineering with the log extracts collected in Steps 1–3.

---

## 5. Notes

### Edge Cases

- **Workstation service timing:** Even with a corrected user-context script, if the script fires before the Workstation service is running, the UNC path may still be unreachable. If this recurs, add a readiness check to the script (e.g., loop with `Test-Path \\finbridge-fs01\Finance` before attempting the mapping, with a bounded retry of 5 attempts at 5-second intervals).
- **Hybrid devices (Azure AD Joined + GPO):** If `DESKTOP-FB*` devices are Azure AD Joined only (not hybrid-joined), GPO logon scripts may not apply. Confirm join type before selecting Option A in Step 9.
- **VPN or off-network devices:** Finance users working remotely may not have UNC path access to `\\finbridge-fs01\Finance` even in user context. This runbook assumes on-network or VPN-connected devices.
- **Cached credentials / first sign-in:** On newly provisioned devices, the SYSTEM script may fire before the user has ever signed in and cached credentials are not available. This runbook does not cover first-time provisioning — treat those separately.

### Warnings

> **Do not re-enable the SYSTEM-context Intune deployment under any circumstances without a full redesign of the script.** The script as written does not validate execution context, does not check Workstation service readiness, and has no retry logic. Re-enabling it will reproduce the incident.

> **Do not delete `Map-FinBridgeDrives.ps1` from Intune.** Retain it for audit trail and change management review.

### Related Incidents and References

| Reference | Detail |
|---|---|
| DRIVE-MAP-FIN-2024-03-15 | Source RCA for this runbook |
| Closure Note DRIVE-MAP-FIN-2024-03-15 | Closure communication for Finance stakeholders |
| Preventive Action PA-1 | Update GPO-to-Intune migration runbook — execution context review required for every migrated script |
| Preventive Action PA-7 | Review all Intune PowerShell deployments for other user-session tasks running as SYSTEM without redesign |
| Change record 2024-03-14 23:30 | Original change that migrated `Map-FinBridgeDrives.ps1` to SYSTEM context — the change note explicitly recorded the risk that was not acted on |

---

*Runbook prepared by DWP Engineer | Derived from RCA DRIVE-MAP-FIN-2024-03-15 | 2026-08-10*
