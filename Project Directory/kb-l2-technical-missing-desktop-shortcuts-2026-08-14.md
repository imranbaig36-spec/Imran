# Technical KB: Desktop Shortcut Loss After Deployment—Root Cause and Resolution

**Version:** 1.0  
**Created:** 2026-08-14  
**Severity:** Medium  
**For:** IT Engineers & Service Desk Technical Tier  
**Derived from:** runbook-legal-floor6-missing-desktop-shortcuts-2026-08-14.md  
**Related RCA:** rca-legal-floor6-missing-shortcuts-incident-2026-08-14.md (Provisional findings)

**Runbook Traceability (single source assurance):**
- This article operationalizes the same runbook and must be maintained as a re-expression, not an independent playbook.
- Runbook Step 1-3 -> Phase 1 immediate user-facing steps.
- Runbook Step 4 -> Phase 2 Intune remediation path.
- Runbook troubleshooting/escalation guidance -> Phase 3 escalation and known-issues handling.
- Runbook completion checks -> Verification and escalation standards in this article.

---

## Technical Overview

### Root Cause (Provisional)
Deployment-related post-install script or policy action altered or removed shortcut artifacts in the user's desktop profile directory (`%USERPROFILE%\Desktop\` and/or shell link cache) between Friday afternoon (deployment window) and Monday morning (symptom report). Temporal correlation indicates causation; final proof (exact script/policy action) pending completion of log correlation evidence review.

### Affected Systems
- **OS:** Windows 11 (recent migration)
- **Management:** Intune-enrolled devices
- **Trigger:** Document management app deployment to Floor 6 cohort
- **Timing:** 48–72-hour latency between deployment execution and symptom report

### Confidence Level
Medium—ranked diagnostics strongly support deployment-related hypothesis, but endpoint execution logs and management-plane action history must be correlated to confirm exact causation point.

---

## Technical Diagnosis

### Evidence Checklist

Before escalating, confirm the following artifacts on the affected device:

| Check | Command / Path | Expected Finding | Diagnostic Value |
|---|---|---|---|
| **Shortcut file presence** | `dir %USERPROFILE%\Desktop\*.lnk` | No `.lnk` files or count mismatch vs. user baseline | Confirms symptom location |
| **Shell link cache** | `%APPDATA%\Microsoft\Windows\Recent\*` and `%APPDATA%\Microsoft\Internet Explorer\Quick Launch\*` | Verify recent documents and taskbar link count; compare to unaffected device | Indicates cache-level removal or corruption |
| **Deployment execution log** | Event Viewer > **Applications and Services > Microsoft > Windows > AppMan > Operational** | Entry showing app deployment/remediation timestamp; look for post-install script execution success/failure | Correlates deployment action to timing |
| **Policy application log** | Event Viewer > **Applications and Services > Microsoft > Windows > GroupPolicy > Operational** | Policy application events during or immediately after deployment window | Rules out/in GPO side effects on desktop paths |
| **User profile state** | `%USERPROFILE%\NTUSER.DAT` registry hive check; `dir %USERPROFILE%\Desktop` listing | Profile not corrupted; desktop folder exists and has expected permissions (full control for user) | Eliminates profile damage or permission regression |
| **Intune client status** | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` | Successful device check-in and remediation action records around incident window | Confirms Intune management continuity |

### Escalation Decision Tree

1. **Do shortcuts exist on disk at `%USERPROFILE%\Desktop\`?**
   - **No** → Proceed to Step 4 (Redeployment Remediation)
   - **Yes** → Check if shortcuts are launching correctly. If yes, issue is icon cache only; run Step 1 (Explorer restart) first, then Step 2 (Intune sync).

2. **Does AppMan log show deployment/remediation success on the incident date/time?**
   - **Yes** → Remediation available via redeployment; proceed to Step 4.
   - **No** → Check if deployment assignment was removed or conditional targeting failed. Escalate to deployment engineering if assignment is confirmed but logs show no execution.

3. **Does the Intune remediation log show an error after redeployment attempt?**
   - **Yes** → Collect full error text, device hardware/driver info, and Intune compliance status. Escalate to Intune administration with error details and device serial number.
   - **No** → Verify shortcuts appear 5–10 minutes post-sync. If still missing, escalate with full diagnostic bundle.

---

## Resolution Procedure (Technical Tier)

### Phase 1: Immediate User-Facing Steps

Execute Steps 1–3 of the runbook. These are safe, non-destructive, and often resolve the symptom without backend action:

1. **Explorer cache clear** (taskkill/restart explorer.exe)
2. **Intune sync** (trigger device check-in via Settings > Access work or school > Sync)
3. **Desktop profile verification** (inspect `%USERPROFILE%\Desktop\` for file presence)

### Phase 2: Service Desk / Tier 2 Escalation

If Phase 1 does not resolve, initiate Intune remediation:

1. **In Intune admin center:**
   - Navigate to **Devices > Compliance > Manage devices > [device name]**
   - Confirm device enrollment status is "Compliant" or "Non-compliant (remediation available)"
   - Locate the deployment assignment for document management app (check **Apps > Assignments > [app name]**)

2. **Trigger remediation:**
   - If app assignment shows "Conflict" or "Unavailable," edit and reassign to the device/group.
   - If assignment is active, proceed to step 3.

3. **Force redeployment:**
   - Use Intune's **Remediation Script** feature or **Immediate device actions > Sync** command.
   - Alternatively, unenroll and re-enroll the device in Intune (if policy allows and time is available).
   - Monitor AppMan log in real time: `Get-WinEvent -LogName "Microsoft-Windows-AppMan/Operational" -MaxEvents 50 | Where-Object {$_.TimeCreated -gt (Get-Date).AddMinutes(-15)}`

4. **Verify post-remediation:**
   - Wait 5–10 minutes for remediation action to execute on device.
   - Confirm shortcut files reappear at `%USERPROFILE%\Desktop\`.
   - Request user to test shortcut launch and report success/failure.

### Phase 3: Escalation to Deployment Engineering

If Phase 2 remediation succeeds but shortcuts do not reappear, or if remediation fails with errors:

1. **Collect full diagnostic bundle:**
   - AppMan operational logs (last 48 hours) from affected device
   - Intune management extension logs from `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\`
   - GroupPolicy operational logs (verify no conflicting desktop/profile policies)
   - Before/after shortcut inventory comparison (affected vs. reference device)
   - Device hardware, OS build, and Intune client version details

2. **Escalate to deployment engineering with:**
   - Full diagnostic bundle (above)
   - Screenshot of current state
   - Timeline of user's initial report and each resolution attempt
   - This runbook and related RCA documentation

3. **Deployment engineering actions:**
   - Correlate Intune deployment history with event logs to identify exact post-install action that removed shortcuts.
   - Review deployment package/script for side effects on desktop/profile paths.
   - Develop targeted remediation or policy reversal for affected cohort.

---

## Troubleshooting & Known Issues

### Issue: Explorer Restart Fails or Hangs

**Diagnosis:**
- Check Task Manager for hung explorer.exe process or high resource usage.
- Verify system has >500 MB free RAM.

**Resolution:**
- Wait 30 seconds and retry taskkill.
- If taskkill is blocked by UAC or permission error, run as SYSTEM via `psexec -s taskkill /f /im explorer.exe`.
- If system is out of memory, request user restart device and contact Service Desk if issue recurs.

### Issue: Intune Sync Does Not Trigger Remediation

**Diagnosis:**
- Check device compliance status in Intune; if "Non-compliant," remediation scripts may be pending.
- Verify network connectivity to Intune management endpoints (test with `Test-NetConnection -ComputerName enterpriseregistration.windows.net -Port 443`).

**Resolution:**
- If non-compliant, wait 5–10 minutes for automatic remediation cycle.
- If network issues are detected, troubleshoot network connectivity before retry.
- Manually invoke Intune remediation: Open `C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe` (GUI) or trigger via PowerShell using Intune management APIs.

### Issue: AppMan Log Shows Deployment/Remediation Error

**Common Errors:**
- **0x87d1041c** (app installation failed, post-install script error) → Check post-install script syntax and permissions; script may be attempting to modify desktop paths without proper error handling.
- **0x80070005** (access denied during post-install) → Confirm deployment script runs in system context and has write permissions to `%USERPROFILE%\Desktop\` and `%APPDATA%\` for the target user.
- **Timeout (remediation took >30 minutes)** → Post-install script may contain unintended delays (e.g., unoptimized copy operations or network waits); escalate to deployment engineering for script optimization.

**Resolution:**
- Collect full error text (including hex code and description).
- Review post-install script in deployment package for syntax errors or permission issues.
- Test post-install script in controlled environment (lab VM with equivalent Windows 11 + Intune enrollment state).
- If script is correct but error persists on user device, device-specific state (e.g., corrupted registry, stale app cache) may be the cause; consider reimaging or full Intune device reset.

### Issue: Shortcuts Restored, But Wrong Shortcuts Appear

**Diagnosis:**
- User baseline unclear or device received shortcuts intended for a different role/floor.
- Deployment assignment may have targeted wrong group.

**Resolution:**
- Collect list of incorrect shortcuts from user.
- Verify device's Intune group membership and deployment targeting rules.
- If targeting is wrong, correct assignment and resync device.
- If shortcut set is correct for device but user expects different shortcuts, document user's expected baseline and update deployment/remediation package for future deployments.

---

## Prevention & Hardening

### Recommended Post-Incident Actions

1. **Pre-deployment validation gate:** Before rolling out to floor-wide cohorts, pilot the deployment on 2–3 devices and verify shortcut integrity before/after using a standard shortcut baseline inventory script.

2. **Post-install script governance:** Require explicit review of any post-install script that modifies desktop, start menu, or user profile paths. Script must include error handling and logging for all file/registry modifications.

3. **Deployment phasing:** Enforce small pilot cohorts (5–10 devices) with explicit hold point before floor-wide rollout. Monitor AppMan and policy logs during pilot window.

4. **Evidence capture automation:** On first report of any deployment-related symptom, automatically capture read-only diagnostic snapshot from one affected and one unaffected device for immediate differential analysis.

5. **Ring-based rollout controls:** Implement deployment rings (pilot, early production, general production) with defined hold points, user feedback validation, and log review before ring advancement.

6. **Closure evidence standard:** Do not close incident as "root cause confirmed" until log correlation (Intune history + endpoint event logs) and restoration proof (before/after shortcut inventory) are attached to incident record.

---

## Service Desk Escalation Path

| Stage | Condition | Next Step | Owner |
|---|---|---|---|
| **L1 (User-Facing)** | User reports missing shortcuts | Execute runbook Steps 1–3; collect device name and screenshot | Service Desk |
| **Tier 2 (Technical)** | Phase 1 does not resolve | Execute runbook Steps 4; trigger Intune remediation; monitor logs | Service Desk + Intune Admin |
| **Escalation** | Phase 2 remediation fails or errors | Collect diagnostic bundle; escalate with this KB and RCA | Deployment Engineering |
| **Post-Incident** | Any follow-on reports of same symptom | Document case reference and timestamp; if 2+ reports in 7 days, escalate to preventive action review | Incident Management |

---

## References

- **Related RCA:** [rca-legal-floor6-missing-shortcuts-incident-2026-08-14.md](rca-legal-floor6-missing-shortcuts-incident-2026-08-14.md) (Provisional; confirmation pending)
- **Runbook:** [runbook-legal-floor6-missing-desktop-shortcuts-2026-08-14.md](runbook-legal-floor6-missing-desktop-shortcuts-2026-08-14.md)
- **Event Log Interpretation:** Microsoft Documentation on AppMan and GroupPolicy operational logs
- **Intune Troubleshooting:** Microsoft Intune Remediation Scripts and Compliance Documentation

---

## Change Log

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-08-14 | Initial publication; derived from provisional RCA findings |

