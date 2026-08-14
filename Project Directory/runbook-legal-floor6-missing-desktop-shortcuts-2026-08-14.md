# Runbook: Legal Floor 6 Missing Desktop Shortcuts Resolution

**Version:** 1.0  
**Created:** 2026-08-14  
**Source RCA:** rca-legal-floor6-missing-shortcuts-incident-2026-08-14.md  
**Incident Type:** Deployment-Related Shortcut Loss  
**Confidence Level:** Provisional (based on ranked diagnostics; final confirmation pending)

---

## Prerequisites

Before beginning this procedure, confirm the following:

- **User device access:** You have physical or remote access to the affected Floor 6 endpoint and user credentials with local admin rights (or Intune device management permissions).
- **Network connectivity:** Device has stable network connectivity to Intune management plane and internal resources.
- **Time window:** Allow 15–20 minutes for completion and verification.
- **Backup state:** Optional but recommended—have the user take a screenshot of their current desktop state before starting.
- **Deployment context:** Confirm the device received the document management app deployment in the 48–72 hours prior to symptom report.

---

## Procedure

### Step 1: Clear Windows Explorer Cache and Restart Shell
**Purpose:** Clears potentially stale shortcut cache that may prevent icon refresh.

1. Press `Win + R`, type `taskkill /f /im explorer.exe`, and press Enter.
2. Wait 3 seconds, then press `Win + R`, type `explorer.exe`, and press Enter.
3. **Expected Result:** Windows Explorer restarts; desktop briefly goes blank, then returns with the same view (or updated if cache was stale). No errors appear in Event Viewer.

### Step 2: Force Intune Sync to Reapply Deployment Configuration
**Purpose:** Triggers re-evaluation of deployment-related policies and post-install scripts on the endpoint.

1. Press `Win + I` to open Settings.
2. Navigate to **Accounts > Access work or school**.
3. Select the Intune enrollment entry, then click **Info** > **Sync**.
4. Wait 2–3 minutes for sync to complete (you may see "Syncing…" briefly in Settings).
5. **Expected Result:** No errors appear; device shows "Last sync" timestamp updated within the last 3 minutes in the Info pane. Event Viewer shows successful Intune client activity (not errors) in **Applications and Services Logs > Microsoft > Windows > DeviceManagement-Enterprise-Diagnostics-Provider**.

### Step 3: Verify Shortcut Files Exist in Desktop Profile Path
**Purpose:** Confirms shortcut files are physically present on disk.

1. Press `Win + E` to open File Explorer.
2. In the address bar, type `%USERPROFILE%\Desktop` and press Enter.
3. **Expected Result:** Desktop shortcuts appear in this directory. File count should match user's expectation (for example, if the user expected 5 shortcuts, 5 `.lnk` files are visible). If no shortcuts appear, proceed to Step 4.

### Step 4: Restore Shortcuts via Redeployment Remediation
**Purpose:** Forces re-execution of deployment remediation script to restore missing shortcuts.

1. Contact the Service Desk and provide the incident reference and your Floor 6 device name (found in **Settings > System > About > Device name**).
2. Provide this context: *"Deployed document management app, desktop shortcuts missing after 48–72 hours, user confirmed device received deployment on [Friday afternoon]."*
3. Service Desk will trigger an Intune remediation script or resend the deployment assignment to your device.
4. Wait 5–10 minutes, then check the desktop.
5. **Expected Result:** Desktop shortcuts reappear. If using Intune, you should see a notification that a remediation script ran; check Event Viewer under **Applications and Services Logs > Microsoft > Windows > AppMan** for confirmation (look for entry showing successful deployment/remediation action).

---

## Verification

After completing all steps, confirm the following:

1. **Visual Check:** All expected desktop shortcuts are visible (compare to a known-good reference or user's prior documentation).
2. **Functional Check:** Click one or two shortcuts to confirm they launch correctly (for example, the document management app should open to the expected interface).
3. **Persistence Check:** Restart the device (optional but recommended) and confirm shortcuts persist after reboot. **Expected Result:** Shortcuts remain after restart with no reappearance of the symptom.
4. **Event Log Check (Optional but Recommended):** Open Event Viewer, navigate to **Applications and Services Logs > Microsoft > Windows > AppMan**, and confirm the most recent entry shows a successful deployment/remediation action with no errors.

If all four checks pass, the issue is resolved.

---

## Rollback

If shortcuts are incorrectly restored (for example, unwanted shortcuts appear or wrong shortcuts are restored):

1. **Contact Service Desk immediately** and provide:
   - The list of incorrect shortcuts that appeared
   - Your device name and the incident reference number
   - A screenshot of the desktop showing the unexpected state

2. Service Desk will:
   - Revert the remediation assignment in Intune
   - Manually remove incorrect shortcut files via remote management (if needed)
   - Re-sync your device and restore the correct shortcut set

3. **Do not manually delete shortcuts** from your desktop during rollback; let Service Desk manage the removal to ensure no unintended side effects occur.

---

## Troubleshooting

| Symptom | Likely Cause | Next Step |
|---|---|---|
| Step 1: Explorer does not restart or freezes | Hung explorer.exe process; system may be under resource strain | Wait 30 seconds, retry Step 1. If it fails again, contact Service Desk. |
| Step 2: Sync fails or shows an error | Device not enrolled in Intune or network issue | Check **Settings > Accounts > Access work or school** to confirm enrollment. Restart network adapter or move to a different network. Contact Service Desk if unresolved. |
| Step 3: Shortcuts folder is empty | Post-install script removed shortcuts or desktop profile is corrupted | Proceed to Step 4 (redeployment) to restore. |
| Step 4: Remediation does not complete or shows error | Intune remediation package may be corrupted or deployment assignment may be missing | Contact Service Desk with the device name and full error message from Event Viewer. |
| After Step 4: Shortcuts still missing | Deployment configuration may be silently blocking shortcut creation | Contact Service Desk. Escalate to deployment/Intune administration team with the incident reference. |

---

## Closure Criteria

Close this ticket/case as resolved when:
- User confirms all expected desktop shortcuts are visible and functional.
- Shortcuts persist through at least one device restart.
- No errors appear in subsequent Intune syncs or AppMan event logs.
- Escalation not required.

If the issue persists after Step 4 or any troubleshooting step fails, escalate to the deployment engineering team with a full copy of this runbook, the device's Intune history, and a screenshot of the current state.
