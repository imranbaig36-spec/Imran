# KB Article — Finance Mapped Drive `S:` Not Assigned at Sign-in (Intune SYSTEM Context)

| Field | Value |
|---|---|
| **KB Reference** | KB-DRIVE-MAP-FIN-001 |
| **Version** | v1.0 |
| **Date** | 07/08/2026 |
| **Status** | Draft |
| **Author** | DWP Engineer |
| **Incident Reference** | DRIVE-MAP-FIN-2024-03-15 |
| **Applies To** | Finance users on `DESKTOP-FB*` devices in `OU=Finance`; Windows 11; Intune-managed endpoints |

---

## 1. Background

### What the System Does

Finance users at DWP require persistent access to a shared network drive mapped as `S:`, backed by the UNC path `\\finbridge-fs01\Finance`. This share holds financial data that Finance staff access during every working session. The drive is expected to appear automatically at sign-in on any Finance-provisioned device.

Drive mapping is delivered by a PowerShell script — `Map-FinBridgeDrives.ps1` — which runs at sign-in and calls `New-PSDrive` or `net use` to assign the `S:` letter to the Finance share.

### Why It Matters

Without `S:`, Finance users cannot access shared financial data, cannot perform their core duties, and must rely on manual UNC path navigation or engineer-applied workarounds. A failure affecting the entire Finance OU constitutes a High severity incident. This exact pattern caused a full Finance outage on 2024-03-15 from `08:00` to `09:09`.

### The Migration Risk Context

This failure class is specifically introduced when `Map-FinBridgeDrives.ps1` is migrated from a **GPO logon script (runs as the signed-in user)** to an **Intune PowerShell script (runs as SYSTEM by default)**. These two execution contexts have fundamentally different capabilities:

| Capability | GPO Logon Script (User Context) | Intune PowerShell Script (SYSTEM Context) |
|---|---|---|
| Access to UNC paths over SMB | Yes — uses the signed-in user's credentials | No — SYSTEM has no user credentials at sign-in time |
| Can create user-visible mapped drives | Yes | No — drives created by SYSTEM are not visible to the user session |
| Workstation service available at execution | Yes — logon scripts fire after user session initialises | Not guaranteed — SYSTEM scripts may fire before Workstation service is running |
| Access to mapped credentials | Yes | No |

If an engineer moves the script to Intune without changing this context setting, the failure described in this article will occur on every Finance user sign-in.

---

## 2. Symptoms

### What the User Reports

- Drive `S:` is missing from File Explorer under **This PC** after signing in.
- Attempting to navigate to `S:\` in File Explorer returns: `S:\ is not accessible` or the drive simply does not appear.
- The issue affects all Finance users simultaneously — it is not isolated to a single user or single machine.
- The issue began at the first sign-in after an overnight change window (typically following a script migration or Intune deployment change).
- Signing out and back in does not restore the drive.

### What the Engineer Observes

- All reports come from users in `OU=Finance` on `DESKTOP-FB*` devices.
- No users outside Finance are affected.
- Group Policy appears to be processing without errors (Finance desktops are receiving other GPO settings correctly).
- No file server or share outage is reported — `\\finbridge-fs01\Finance` is reachable from a correctly working device.
- Intune reports `Map-FinBridgeDrives.ps1` as **successfully deployed** (the script ran; it just ran in the wrong context).

> **Key diagnostic signal:** Intune reporting the script as "success" while users have no drive is a strong indicator of an execution context mismatch, not a deployment failure.

---

## 3. Root Cause

### Technical Root Cause

`Map-FinBridgeDrives.ps1` was executing as the **SYSTEM account** via an Intune PowerShell script deployment. The script was written to create a user-visible mapped drive using user-session SMB access. SYSTEM cannot:

1. Authenticate to `\\finbridge-fs01\Finance` with user credentials (none are available to SYSTEM at sign-in time).
2. Create a drive mapping visible in the signed-in user's interactive session (drives mapped by SYSTEM exist in session 0, not the user session).
3. Reliably reach SMB paths at the point of execution, because the Workstation service may not yet be running.

The script failed with exit code `1` before the Workstation service was confirmed running, and the drive letter `S:` was never assigned.

### Confirming Evidence

| Evidence | What It Proves |
|---|---|
| IME log: `Script context: SYSTEM account` | The script ran in the wrong execution context |
| IME log: `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time` | SYSTEM could not reach the Finance share |
| IME log: `Exit code: 1. Error: Network name cannot be found.` | The mapping attempt failed explicitly |
| System log Event `7036` (Workstation service) timestamp **after** IME failure | Network stack was not yet ready when the script ran |
| System log Event `98` (Ntfs): `Drive letter has not been assigned` | User-facing symptom is directly confirmed in logs |
| System log Event `1500` (GroupPolicy): `Group Policy settings processed successfully` | GPO is healthy — eliminates GPO as a cause |
| Change record 2024-03-14 23:30 | The migration to SYSTEM context was performed the night before the incident; the change note explicitly recorded the known risk |

---

## 4. Detection

> Complete **all** detection steps before acting. Do not proceed to resolution until all five conditions are confirmed.  
> **Target time:** Under 3 minutes using the PowerShell commands below. Event Viewer paths are provided as a fallback if remote PowerShell access is unavailable.

### Step D1 — Check the User-facing Event on the Affected Device

**Log location:** `Event Viewer > Windows Logs > System`  
**Event ID:** `98`  
**Source:** `Ntfs`  
**What to look for:** `File system could not map drive letter S: Drive letter has not been assigned.`

**PowerShell — run on the affected device or via a remote session:**

```powershell
Get-WinEvent -LogName System |
    Where-Object { $_.Id -eq 98 -and $_.ProviderName -eq 'Ntfs' } |
    Select-Object TimeCreated, Message |
    Format-List
```

*Expected:* One or more entries containing `Drive letter has not been assigned`, timestamped at or just after the user sign-in time.

If Event `98` is not present, this KB article may not apply. Consider a different cause (e.g., GPO drive preference failure, DFS namespace issue).

---

### Step D2 — Confirm Execution Context in the Intune Management Extension Log

**Log location:** `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log`  
**Access:** Requires local admin or remote admin on the affected device.

**PowerShell — extract all relevant lines in one pass:**

```powershell
Select-String -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" `
    -Pattern "Map-FinBridgeDrives|Script context|Exit code|Network path"
```

*All four of the following lines must appear in the output:*

| Line to find | Field | Expected value for this issue |
|---|---|---|
| `Executing: Map-FinBridgeDrives.ps1` | Script name | Confirms this script ran |
| `Script context: SYSTEM account` | Context field | **Fault indicator** — wrong execution context |
| `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time` | Warning message | Confirms context-specific failure |
| `Exit code: 1. Error: Network name cannot be found.` | Exit code | Confirms the mapping attempt failed |

If the log shows `Script context: logged on user` instead of `SYSTEM account`, the context has already been corrected — investigate a different cause.

---

### Step D3 — Confirm Workstation Service Timing

**Log location:** `Event Viewer > Windows Logs > System`  
**Event ID:** `7036`  
**Source:** `Service Control Manager`  
**What to look for:** `Workstation service entered running state.` — the timestamp must be **after** the IME failure timestamp from Step D2.

**PowerShell:**

```powershell
Get-WinEvent -LogName System |
    Where-Object { $_.Id -eq 7036 -and $_.Message -match 'Workstation' } |
    Select-Object TimeCreated, Message |
    Sort-Object TimeCreated |
    Select-Object -Last 3
```

Compare the `TimeCreated` value against the IME log timestamp from Step D2:

| Event | Expected order |
|---|---|
| IME log: `Exit code: 1` | Earlier — script fails first |
| System Event `7036` (Workstation running) | Later — network stack ready after the script has already failed |

If `7036` precedes the IME failure, Workstation timing is not a contributing factor — the execution context failure alone is sufficient to explain the fault.

---

### Step D4 — Rule Out GPO as the Cause

**Log location:** `Event Viewer > Windows Logs > System`  
**Event ID:** `1500`  
**Source:** `GroupPolicy`  
**What to look for:** `Group Policy settings processed successfully.`

**PowerShell:**

```powershell
Get-WinEvent -LogName System |
    Where-Object { $_.Id -eq 1500 -and $_.ProviderName -eq 'GroupPolicy' } |
    Select-Object TimeCreated, Message |
    Select-Object -Last 1
```

If Event `1500` shows an **error**, stop. This is a different incident — raise a GPO processing fault and do not continue with this KB article.

If `1500` confirms success, GPO is healthy and not the cause.

---

### Detection Summary — All Four Conditions Must Be True

| # | Condition | Confirms | Command |
|---|---|---|---|
| D1 | Ntfs Event `98` present in System log | Drive letter `S:` was never assigned | `Get-WinEvent` |
| D2 | IME log shows `Script context: SYSTEM account` and `Exit code: 1` | Script ran in wrong context and failed | `Select-String` |
| D3 | `7036` timestamp is after IME failure timestamp | Network stack not ready at script execution time | `Get-WinEvent` |
| D4 | GroupPolicy Event `1500` shows success | GPO is not the cause | `Get-WinEvent` |

---

## 5. Resolution

> **Prerequisites before starting:**  
> - Intune RBAC role: **Policy and Profile Manager** or higher *(elevated — confirm with your team lead if unsure)*  
> - Local or remote admin access to an affected `DESKTOP-FB*` device  
> - A confirmed replacement delivery method (GPO or Intune user-context) ready before removing the failing deployment  
> - **Microsoft Graph PowerShell SDK** installed (`Install-Module Microsoft.Graph`) and authenticated before running any Graph commands below

---

### Phase 1 — Disable the Failing SYSTEM-Context Deployment

**Step R1.** Sign in to the Intune portal at `https://intune.microsoft.com` using your Policy and Profile Manager account.  
*Expected result:* Intune portal home dashboard loads.

**Alternatively — authenticate via PowerShell (do this once before Steps R2–R6):**

```powershell
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"
```

**Step R2.** Navigate to: **Devices** > **Scripts and remediations** > **Platform scripts**.  
*Expected result:* A list of all PowerShell scripts deployed via Intune is displayed.

**PowerShell — locate the script and confirm its execution context:**

```powershell
$script = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts" |
    Select-Object -ExpandProperty value |
    Where-Object { $_.displayName -eq 'Map-FinBridgeDrives.ps1' }

$script | Select-Object displayName, runAsAccount, id
# runAsAccount = 'system' confirms the fault; 'user' means context is already corrected
```

**Step R3.** Locate `Map-FinBridgeDrives.ps1` in the list and click to open its properties.  
*Expected result:* The script properties page opens showing assignments and settings.

**Step R4.** Select the **Assignments** tab. Confirm the script is assigned to a group containing `DESKTOP-FB*` Finance devices.  
*Expected result:* The Finance device group (e.g., `SG-Finance-Devices` or equivalent) is listed as an assignment target.

**PowerShell — list current assignments:**

```powershell
$scriptId = $script.id
Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$scriptId/assignments" |
    Select-Object -ExpandProperty value |
    Select-Object id, @{n='targetType';e={$_.target.'@odata.type'}}
```

**Step R5.** Select the **Settings** tab. Confirm **Run this script using the logged on credentials** is set to **No**.  
*Expected result:* The setting reads **No**, confirming the script is running as SYSTEM — this is the fault indicator.  
*(The `runAsAccount` field returned in Step R2 PowerShell output confirms this without opening the portal.)*

**Step R6.** Return to the **Assignments** tab. Click the assignment targeting the Finance device group and remove it (click the group row and select **Remove**, or set the assignment to **Unassigned**).  
Do **not** delete the script — retain it for audit and change management.  
Save the change.  
*Expected result:* The Finance device group no longer appears in the assignment list. The script will not execute at next sign-in for Finance devices.

**PowerShell — remove all assignments from the script:**

```powershell
$assignments = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$scriptId/assignments" |
    Select-Object -ExpandProperty value

foreach ($a in $assignments) {
    Invoke-MgGraphRequest -Method DELETE `
        -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$scriptId/assignments/$($a.id)"
    Write-Host "Removed assignment: $($a.id)"
}

# Confirm assignments are cleared
Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$scriptId/assignments" |
    Select-Object -ExpandProperty value
# Expected: empty result
```

---

### Phase 2 — Restore Drive Mapping in User Context

Choose **Option A** (preferred for hybrid-joined or domain-joined devices) or **Option B** (for Azure AD Join-only devices).

---

#### Option A — Restore via GPO Logon Script (Preferred)

**Step R7a.** On a domain controller or management workstation, open **Group Policy Management Console**: Start > Run > `gpmc.msc`. *(Elevated — requires Domain Admin or GPO Editor delegation.)*  
*Expected result:* GPMC opens showing the domain and OU structure.

**Step R8a.** In the left pane, expand the domain and navigate to the GPO linked to `OU=Finance`. Right-click the GPO and select **Edit**.  
*Expected result:* Group Policy Management Editor opens for the Finance GPO.

**Step R9a.** Navigate within the editor to: **User Configuration** > **Windows Settings** > **Scripts (Logon/Logoff)** > **Logon**.  
Double-click **Logon** to open the Logon Properties dialog.  
*Expected result:* The Logon Properties dialog opens showing any currently configured logon scripts.

**Step R10a.** Click **Add**. In the **Script Name** field, browse to or enter the path to `Map-FinBridgeDrives.ps1`. Leave **Script Parameters** blank unless previously documented. Click **OK**, then **OK** again to close Logon Properties.  
*Expected result:* `Map-FinBridgeDrives.ps1` appears as a logon script in the GPO. It will run as the signed-in user at next logon.

**Step R11a.** On the pilot Finance device, open an elevated Command Prompt and run:  
`gpupdate /force`  
*Expected result:* Output reads `Computer Policy update has completed successfully` and `User Policy update has completed successfully`.

---

#### Option B — Restore via Intune User-Context Script

**Step R7b.** In the Intune portal, navigate to: **Devices** > **Scripts and remediations** > **Platform scripts**.  
Click the `Map-FinBridgeDrives.ps1` script (the one retained from Step R6).  
*Expected result:* The script properties page opens.

**Step R8b.** Select the **Settings** tab. Change **Run this script using the logged on credentials** from **No** to **Yes**.  
Save the change.  
*Expected result:* The setting now reads **Yes** — the script will execute as the signed-in user, not SYSTEM.

**PowerShell — change execution context to user:**

```powershell
$body = '{"runAsAccount": "user"}'
Invoke-MgGraphRequest -Method PATCH `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$scriptId" `
    -Body $body -ContentType "application/json"

# Confirm the change
(Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$scriptId").runAsAccount
# Expected: 'user'
```

**Step R9b.** Select the **Assignments** tab. Click **Add groups** and add the Finance **user** group (not the device group).  
Save the assignment.  
*Expected result:* The Finance user group appears in the assignment list. The script is now targeted at users and will run in their context.

**Step R10b.** In the Intune portal, navigate to **Devices** > **All devices**. Search for the pilot `DESKTOP-FB*` device. Select it and click **Sync**.  
*Expected result:* A notification confirms the sync request was sent. The device will check in and receive the updated script assignment.

**PowerShell — trigger device sync on the pilot device:**

```powershell
# Replace DESKTOP-FB01 with the actual pilot device name
$deviceId = (Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=deviceName eq 'DESKTOP-FB01'").value[0].id

Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$deviceId/syncDevice"

Write-Host "Sync request sent to device ID: $deviceId"
```

---

## 6. Verification

Perform all verification steps on at least one representative `DESKTOP-FB*` Finance device before closing the incident.

**Step V1.** Sign a Finance test user out of the pilot device, then sign them back in.  
*Expected result:* Sign-in completes without errors or unusual delays.

**Step V2.** Open **File Explorer** on the pilot device. Look under **This PC**.  
*Expected result:* Drive `S:` is visible in the drive list.

**Step V3.** Double-click drive `S:` in File Explorer.  
*Expected result:* The share opens and displays the contents of `\\finbridge-fs01\Finance`. No access denied or path not found errors.

**Step V4.** Open **Event Viewer** > `Windows Logs > System`. Filter for Event ID `98` from source `Ntfs` with a timestamp after the test sign-in in Step V1.  
*Expected result:* No new Event `98` entries. If a new Event `98` appears, the fix has not taken effect — return to Resolution.

**PowerShell — check for any new Event 98 since sign-in (replace the timestamp):**

```powershell
$signInTime = (Get-Date).AddMinutes(-10)  # adjust to actual sign-in time
Get-WinEvent -LogName System |
    Where-Object { $_.Id -eq 98 -and $_.ProviderName -eq 'Ntfs' -and $_.TimeCreated -gt $signInTime } |
    Select-Object TimeCreated, Message |
    Format-List
# Expected: no output — absence of results confirms the fix is working
```

**Step V5 (Option B only).** Open `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log` on the pilot device. Find the most recent execution entry for `Map-FinBridgeDrives.ps1`.  
**Field to check:** `Script context`  
*Expected result:* Log reads `Script context: logged on user` (not `SYSTEM account`) and `Exit code: 0`.

**PowerShell — extract the most recent execution block for the script:**

```powershell
Select-String -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log" `
    -Pattern "Map-FinBridgeDrives|Script context|Exit code" |
    Select-Object -Last 10
# Expected: 'Script context: logged on user' and 'Exit code: 0' in the most recent entries
```

**Step V6.** Confirm with the Finance test user (or the original reporter) verbally or via ticket update that `S:` is accessible and no further issues are observed.  
Document the confirmation time in the incident record. This time becomes the resolution timestamp.

---

## 7. Rollback

Use this section if the steps in Section 5 cause new failures or if verification in Section 6 fails after two sign-in attempts.

**Step RB1 (Option B rollback).** If the Intune user-context script assignment (Step R9b) causes sign-in failures or new errors:  
Navigate to: **Intune portal** > **Devices** > **Scripts and remediations** > **Platform scripts** > `Map-FinBridgeDrives.ps1` > **Assignments**.  
Remove the Finance user group assignment. Save.  
*Expected result:* The script no longer runs at sign-in. Users may still lack `S:`, but no new errors are introduced.

**PowerShell — remove the user group assignment quickly:**

```powershell
# $scriptId must already be set from Phase 1 — re-run the lookup if needed
$assignments = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$scriptId/assignments" |
    Select-Object -ExpandProperty value

foreach ($a in $assignments) {
    Invoke-MgGraphRequest -Method DELETE `
        -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$scriptId/assignments/$($a.id)"
    Write-Host "Removed assignment: $($a.id)"
}
# Expected: script has no active assignments — will not run at next sign-in
```

**Step RB2 (Option A rollback).** If the GPO logon script (Step R10a) causes sign-in failures:  
Open `gpmc.msc` > edit the Finance GPO > navigate to **User Configuration** > **Windows Settings** > **Scripts (Logon/Logoff)** > **Logon**.  
Remove `Map-FinBridgeDrives.ps1` from the logon script list. Click **OK** and close the editor.  
On the affected device, run `gpupdate /force` in an elevated Command Prompt.  
*Expected result:* The GPO logon script is removed. Sign-in no longer triggers the script.

**Step RB3.** Confirm the SYSTEM-context Intune assignment (removed in Step R6) remains unassigned.  
Do **not** reinstate it. Reinstating the SYSTEM-context assignment will immediately reproduce the original incident on next sign-in.

**Step RB4.** If `S:` is still missing after rollback and Finance users are in active production hours, apply the following session-only workaround. Ask the user to open an elevated Command Prompt while signed in and run:  
`net use S: \\finbridge-fs01\Finance /persistent:no`  
*Expected result:* `S:` is mapped for the current session only. This is a stop-gap only — the user will need to repeat this after every sign-in until a permanent fix is in place.

**Step RB5.** If the situation cannot be stabilised within 30 minutes of beginning rollback, raise a P1/P2 incident ticket. Escalate to Endpoint Engineering with the following artefacts:
- Exported IME log from the affected device
- Screenshot of the Ntfs Event `98` and `7036` entries from Event Viewer
- Confirmation of which resolution option was attempted (A or B)
- Timestamp of each step taken

---

## 8. Preventive Actions

The following are the specific process and tooling changes required to prevent recurrence. Each control names who owns it, when it fires in the release process, the pass/fail signal, and whether it is manual or automated.

---

**PA-1 — Add execution context field to the GPO-to-Intune migration checklist**  
**Who:** Endpoint Engineering | **When:** Pre-deployment — must be complete before the change record is submitted for approval | **Mode:** Manual — automate by enforcing as a required non-null field in the change management system [REQUIRES: ServiceNow custom field or equivalent]  
Add a mandatory field to the migration runbook: *"Does this script create user-visible artefacts (mapped drives, printers, user-session registry keys)?"* A `Yes` answer blocks SYSTEM-context deployment and requires a user-context design sign-off before submission.  
**Pass:** Field completed and signed off by Endpoint Engineering lead, present in the change record. **Fail:** Change Manager rejects the change record and blocks deployment until the field is complete.

---

**PA-2 — Classify mapped drives and printers as user-context-only by default**  
**Who:** Endpoint Engineering | **When:** Pre-deployment — policy document must be updated before any new script deployment is submitted | **Mode:** Manual — automate by adding a pre-deployment Graph query that checks `runAsAccount` and fails the pipeline if `system` is returned for a user-artefact script [REQUIRES: CI/CD pipeline or deployment automation]  
Add a standing policy statement to the Intune deployment standards: any script mapping drives, connecting printers, or modifying the user registry hive must have `Run this script using the logged on credentials` set to `Yes`.  
**Pass:** Policy document updated, version-controlled, and linked in the migration checklist. **Fail:** Any deployment found non-compliant triggers a remediation ticket; further deployments from the submitting team are blocked until resolved.

---

**PA-3 — Mandate a single-device pilot before broad OU deployment**  
**Who:** Change Manager (gate owner); Endpoint Engineering (pilot executor) | **When:** Pre-deployment — pilot must pass before broad rollout is approved | **Mode:** Manual — automate pass/fail signal via an Intune Remediation detection script reporting `S:` mapped state [REQUIRES: Intune Proactive Remediations]  
One representative `DESKTOP-FB*` device must complete a full sign-in cycle with the new delivery method. Pass criteria must be documented in writing in the change record before the change is approved.  
**Pass:** IME log shows `Script context: logged on user` + `Exit code: 0`; Ntfs Event `98` absent post-sign-in; `S:` visible in File Explorer. **Fail:** Change Manager blocks broad rollout until all three pass criteria are met.

---

**PA-4 — Add a Workstation service readiness check to `Map-FinBridgeDrives.ps1`**  
**Who:** Endpoint Engineering (developer) | **When:** Pre-deployment — code review and test must pass before the updated script is uploaded to Intune | **Mode:** Manual to implement; the retry mechanism is automated once deployed  
Add a startup dependency loop: `Test-Path \\finbridge-fs01\Finance` up to 5 attempts at 5-second intervals before `New-PSDrive` / `net use`. Log each attempt. Exit non-zero if all retries fail.  
**Pass:** Script exits `0` and IME log contains no retry entries under normal conditions; exits non-zero and logs the specific error on failure. **Fail:** Code review finds the check absent — deployment is blocked until the check is present and tested.

---

**PA-5 — Add bounded retry and explicit failure logging to all drive-mapping scripts**  
**Who:** Endpoint Engineering | **When:** Pre-deployment — applies to all `Platform scripts` that map drives or connect to UNC paths, before their next deployment | **Mode:** Manual to implement — automate detection by adding a PSScriptAnalyzer custom rule to flag scripts missing exit code handling [REQUIRES: PSScriptAnalyzer in the deployment pipeline]  
Every such script must include: (a) a retry loop with a configurable max attempt count, (b) a structured log entry per failure with the specific error message, and (c) an exit code that accurately reflects success or failure.  
**Pass:** Code review confirms all three elements present; IME log emits a non-zero exit code on failure — never `0`. **Fail:** Script deployment is blocked until code review passes.

---

**PA-6 — Add a rollback checkpoint to context-changing change records**  
**Who:** Change Manager (gate owner) | **When:** Pre-deployment — field must be present and approved before the change is scheduled | **Mode:** Manual — enforce as a required field in the change management system [REQUIRES: ServiceNow custom field or equivalent]  
Any change record moving a script between user context and SYSTEM must name the prior delivery method, the restoration steps, and a target restore time of ≤15 minutes, referencing the specific runbook section.  
**Pass:** Rollback procedure field completed, referencing this runbook, and present in the approved change record. **Fail:** Change Manager rejects the change record — it cannot proceed to scheduled deployment.

---

**PA-7 — Audit all existing Intune PowerShell deployments for misplaced user-session scripts**  
**Who:** DWP Engineer (executor); Endpoint Engineering Lead (sign-off) | **When:** Post-incident — within 10 business days of this KB article being approved | **Mode:** Manual review; discovery automated via PowerShell:

```powershell
Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts" |
    Select-Object -ExpandProperty value |
    Where-Object { $_.runAsAccount -eq 'system' } |
    Select-Object displayName, runAsAccount, id
```

**Pass:** All SYSTEM-context scripts reviewed; count of non-compliant scripts documented; zero unresolved remediation tickets at 10-day mark. **Fail:** Any unreviewed script after 10 days is escalated to Endpoint Engineering Lead with a mandatory completion date.

---

**PA-8 — Pre-deployment smoke test gate** *(gap control)*  
**Who:** Release Engineer / Endpoint Engineering | **When:** Pre-deployment — must pass before the change is deployed beyond the pilot device | **Mode:** Manual — automate as an Intune Remediation detection script returning `Compliant` only when `S:` is accessible [REQUIRES: Intune Proactive Remediations]  
On the pilot device, trigger a sign-in after applying the change and verify: (1) `S:` visible in File Explorer, (2) no Ntfs Event `98` in System log, (3) IME log `Exit code: 0`. All three must pass and be recorded in the change record.  
**Pass:** All three checks confirmed in writing. **Fail:** Deployment to remaining Finance devices is blocked until all three pass.

---

**PA-9 — In-flight monitoring during rollout window** *(gap control)*  
**Who:** DWP Engineer (on-call during change window) | **When:** During deployment — active throughout the rollout window until all Finance devices have synced | **Mode:** Manual monitoring — automate via Azure Monitor alert on Log Analytics for `EventID = 98 AND Source = Ntfs` from `DESKTOP-FB*` devices [REQUIRES: Azure Monitor / Log Analytics with Windows event forwarding]  
Monitor for new Ntfs Event `98` entries on any `DESKTOP-FB*` device. A single new Event `98` after the change is applied is the pause trigger.  
**Pass:** Zero new Event `98` entries across Finance devices during rollout. **Fail:** Any new Event `98` triggers immediate rollout pause and escalation per Section 7.

---

**PA-10 — Post-deployment validation gate** *(gap control)*  
**Who:** Endpoint Engineering (validator); Change Manager (gate owner) | **When:** Post-deployment — must complete before the change record is closed | **Mode:** Manual  
After all Finance devices have synced, validate at least one `DESKTOP-FB*` device per Finance sub-team: sign in, confirm `S:` present, confirm Ntfs Event `98` absent. Document results in the change record.  
**Pass:** All sampled devices show `S:` accessible and zero Event `98` — change record is closed. **Fail:** Any failure reopens the change record and triggers Section 7 (Rollback).

---

**PA-11 — Rollback trigger threshold** *(gap control)*  
**Who:** DWP Engineer (on-call); Change Manager | **When:** During and immediately after deployment — active for 2 hours post-change | **Mode:** Manual trigger based on PA-9 monitoring — automate notification via Azure Monitor alert + Logic App [REQUIRES: Azure Monitor alert + Logic App or equivalent]  
Define an explicit rollback trigger: ≥3 Finance users reporting missing `S:`, OR ≥1 Ntfs Event `98` on any `DESKTOP-FB*` device within 30 minutes of the change. If either condition is met, the on-call engineer must initiate rollback per Section 7 immediately — no further investigation required before acting.  
**Pass:** Zero trigger conditions met during the 2-hour window. **Fail:** Trigger condition met — on-call engineer executes rollback and notifies Change Manager within 5 minutes.

---

**PA-12 — Knowledge update: update runbook and checklist from this incident** *(gap control)*  
**Who:** DWP Engineer (author); Endpoint Engineering Lead (reviewer) | **When:** Post-incident — within 5 business days of this KB article being approved | **Mode:** Manual  
Update the GPO-to-Intune migration runbook to include the execution context check from PA-1; update the migration checklist template with the pilot gate from PA-3; version-control both documents and link them in the change management system.  
**Pass:** Runbook version incremented, checklist template updated, both documents linked in the next migration change record. **Fail:** This KB article cannot move from Draft to Approved status until the update is confirmed.

---

## 9. Related Incidents and KB Articles

| Reference | Type | Summary |
|---|---|---|
| DRIVE-MAP-FIN-2024-03-15 | Incident | Source incident for this KB article — full Finance outage, `S:` missing, 2024-03-15 08:00–09:09 |
| RCA-DRIVE-MAP-FIN-2024-03-15 | RCA Document | Full root cause analysis including 5-Why, hypothesis elimination, and corrective actions |
| Runbook-DRIVE-MAP-FIN-2024-03-15 | Runbook | Step-by-step engineer runbook derived from this incident — use for active remediation |
| KB-AVD-BLACK-SCREEN-POOL-FIN-01 | KB Article | Related Finance endpoint KB — AVD black screen at login on `pool-fin-01` |
| GPO-TO-INTUNE-MIGRATION-RUNBOOK | Process Document | Runbook for GPO-to-Intune migrations — must be updated per PA-1 above |
| Change record 2024-03-14 23:30 | Change Record | Original change that introduced the SYSTEM context — retained for audit |

---

*KB Article prepared by DWP Engineer | Derived from RCA DRIVE-MAP-FIN-2024-03-15 and Runbook DRIVE-MAP-FIN-2024-03-15 | v1.0 | 07/08/2026 | Status: Draft*
