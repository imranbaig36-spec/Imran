# KB Article — AVD Black Screen After Login (`POOL-FIN-01` Intel GPU Driver Fault)

| Field | Value |
|---|---|
| **KB Reference** | KB-AVD-BLACK-SCREEN-POOL-FIN-01-001 |
| **Version** | v1.0 |
| **Date** | 07/08/2026 |
| **Status** | Draft |
| **Author** | DWP Engineer |
| **Incident Reference** | AVD-POOL-FIN-01-2026-08-06 |
| **Applies To** | AVD host pool `POOL-FIN-01`; Finance users; Windows 11 session hosts with Intel GPU driver; Azure Virtual Desktop |

---

## 1. Background

### What the System Does

Azure Virtual Desktop (AVD) delivers virtual desktops to DWP Finance staff through a dedicated host pool named `POOL-FIN-01`. Users authenticate via the AVD desktop client, web client, or thin client and receive a Windows desktop session hosted on one of the session hosts in the pool.

The Desktop Window Manager (`dwm.exe`) is the Windows compositing engine responsible for rendering the user's desktop, taskbar, and windows after sign-in. If `dwm.exe` crashes immediately after a user session is established, the user sees a black screen instead of a desktop. The session may recover after approximately 30 seconds if `dwm.exe` restarts, or it may remain broken, requiring the user to disconnect and reconnect.

### Why It Matters

`POOL-FIN-01` is the primary AVD pool for Finance staff. A black screen at login means Finance users cannot access any desktop applications, files, or services delivered through that pool. An incident affecting the entire pool can prevent a full business unit from working. Because some users recover after a reconnect, the fault can appear intermittent and may be under-reported in its early stages before the true scope becomes clear.

### The Image and Driver Risk Context

This failure class is specifically introduced when a new session host image is deployed to `POOL-FIN-01` containing an updated or changed Intel GPU driver. The driver module `igdumd64.dll` is part of the Intel graphics driver stack. If this DLL contains a defect or is incompatible with the session host configuration, it causes `dwm.exe` to crash on every user session initialisation.

A companion pool `POOL-FIN-02` uses a separate image build and is the primary comparison baseline for isolating whether the fault is pool-specific (image-level) or platform-wide.

| Scenario | What It Means |
|---|---|
| `POOL-FIN-01` affected, `POOL-FIN-02` unaffected | Image-level fault — proceed with this KB article |
| Both `POOL-FIN-01` and `POOL-FIN-02` affected | Platform-wide or domain-wide fault — stop, do not use this KB article as the primary path |
| `POOL-FIN-02` affected, `POOL-FIN-01` unaffected | `POOL-FIN-02` has received the bad image — apply this KB article to `POOL-FIN-02` instead |

---

## 2. Symptoms

### What the User Reports

- After signing in to the AVD pool, the screen goes black instead of loading the desktop.
- Some users report the desktop appears after approximately 30 seconds and is then usable.
- Other users remain on a black screen and must disconnect and reconnect before the desktop loads.
- A small number of users may need to reconnect two or three times before getting a stable session.
- The issue occurs on every sign-in attempt, not just occasionally.
- Users on other AVD pools (such as `POOL-FIN-02`) are not affected.

### What the Engineer Observes

- All affected users are targeted at `POOL-FIN-01`, not other pools.
- The issue began immediately after an image update or deployment to `POOL-FIN-01`.
- `POOL-FIN-02` session hosts show normal availability and no matching user complaints.
- Azure Portal shows `POOL-FIN-01` session hosts as `Available` — the pool appears healthy from the outside.
- Intune or Azure deployment records show a recent image change to `POOL-FIN-01` hosts.
- Event logs on affected session hosts show `dwm.exe` application errors and Desktop Window Manager exit events timed to user sign-ins.

> **Key diagnostic signal:** If the session hosts show as `Available` in Azure Portal but users get black screens, the fault is in the image running on those hosts — not in AVD infrastructure, network, or identity. Focus immediately on the session host logs.

---

## 3. Root Cause

### Technical Root Cause

The `POOL-FIN-01` session host image was updated to a version containing an Intel GPU driver in which `igdumd64.dll` is defective or incompatible with the session host configuration. On every user sign-in, Windows initialises `dwm.exe` (Desktop Window Manager) to render the desktop. `igdumd64.dll` is loaded as part of the GPU driver stack during this initialisation. The defective DLL causes `dwm.exe` to crash immediately, leaving the user session with no rendered desktop — the black screen.

If `dwm.exe` restarts within approximately 30 seconds, the user may recover. If the DWM restart fails or is too slow, the session must be disconnected and re-established.

The last known good image is `build-20240313`, which predates the introduction of the defective driver.

### Confirming Evidence

| Evidence | What It Proves |
|---|---|
| Application log Event ID `1000`: `Faulting application name: dwm.exe` | Desktop Window Manager crashed |
| Application log Event ID `1000`: `Faulting module name: igdumd64.dll` | Intel GPU driver module is the specific crash cause |
| System log Event ID `9009`: Desktop Window Manager exit, timed to user sign-in | DWM exited at the moment the user session should have rendered a desktop |
| Timestamps: Event `1000` and `9009` match user reported sign-in time | Confirms the crash is directly caused by the sign-in, not a background event |
| `POOL-FIN-02` session hosts healthy, no matching events | Confirms the fault is isolated to `POOL-FIN-01`'s image, not the platform |
| Image change record: new image deployed to `POOL-FIN-01` hosts before incident started | Confirms the driver was introduced by the image update |

---

## 4. Detection

> Complete **all** detection steps before acting. Do not proceed to resolution until all conditions are confirmed.  
> Target: all five steps should take under 3 minutes using the commands below — run them before opening any portal blade.

---

### Step D1 — Identify an Affected Session Host

**Portal path:** `https://portal.azure.com` > **Azure Virtual Desktop** > **Host pools** > **POOL-FIN-01** > **Session hosts**  
**What to look for:** A session host that has recently handled the affected users' sessions. Note the exact VM name (e.g., `fin01-sh-001`) — you need it for every command below.  

**Azure CLI — list `POOL-FIN-01` session hosts and status:**
```bash
az desktopvirtualization sessionhost list \
  --resource-group <rg-name> \
  --host-pool-name POOL-FIN-01 \
  --query "[].{Host:name, Status:status, AllowNewSessions:allowNewSession}" \
  --output table
```
*Expected finding:* One or more `POOL-FIN-01` session host names are returned. Record one host name to use in Steps D2–D3.

---

### Step D2 — Confirm `dwm.exe` Crash on the Affected Host

**Log:** Application log (`Windows Logs\Application`) on the affected session host  
**Event ID:** `1000`  
**Source:** `Application Error`  
**Fields to confirm:** `Faulting application name = dwm.exe` AND `Faulting module name = igdumd64.dll`

**PowerShell — run on the affected session host (or via `Invoke-Command` remotely):**
```powershell
# Replace <hostname> with the session host name from Step D1
Invoke-Command -ComputerName <hostname> -ScriptBlock {
    Get-WinEvent -FilterHashtable @{
        LogName   = 'Application'
        Id        = 1000
        StartTime = (Get-Date).AddHours(-4)
    } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'dwm\.exe' -and $_.Message -match 'igdumd64\.dll' } |
    Select-Object TimeCreated,
        @{N='FaultingApp';   E={ ($_.Message -split '\n' | Select-String 'Faulting application name').ToString().Trim() }},
        @{N='FaultingModule';E={ ($_.Message -split '\n' | Select-String 'Faulting module name').ToString().Trim() }} |
    Format-List
}
```

**What to look for in the output:**

| Field | Required value |
|---|---|
| `Faulting application name` | `dwm.exe` |
| `Faulting module name` | `igdumd64.dll` |

> If Event ID `1000` is present but `Faulting module name` is **not** `igdumd64.dll` — stop. A different module is causing the crash. Record the actual module name and reassess. Do not proceed with this KB article.  
> If no Event ID `1000` is returned — DWM did not crash. Consider other causes (FSLogix profile failure, network, identity). Do not proceed with this KB article.

---

### Step D3 — Confirm Desktop Window Manager Exit at Sign-in Time

**Log:** System log (`Windows Logs\System`) on the affected session host  
**Event ID:** `9009`  
**Source:** `Desktop Window Manager`  
**Meaning:** DWM exited abnormally. On a healthy host this event should not appear at login time.

**PowerShell — run on the affected session host:**
```powershell
Invoke-Command -ComputerName <hostname> -ScriptBlock {
    Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        Id        = 9009
        StartTime = (Get-Date).AddHours(-4)
    } -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Message |
    Format-List
}
```

**Comparison check — timestamp correlation between D2 and D3:**

| Event | Expected timestamp order |
|---|---|
| Application log Event ID `1000` (`dwm.exe` faults on `igdumd64.dll`) | Appears first — at or within seconds of the reported sign-in time |
| System log Event ID `9009` (DWM exit) | Appears within 1–2 seconds after Event ID `1000` |

> If Event ID `9009` timestamps do not align with sign-in times, the DWM exit may be unrelated to the login flow. Investigate separately before acting.

---

### Step D4 — Confirm `POOL-FIN-02` Is Healthy (Baseline Comparison)

A healthy session host running the unaffected image will show Event ID `9011` (Desktop Window Manager started successfully) in the System log at sign-in time — **not** Event ID `9009`. Use `POOL-FIN-02` as the control.

**PowerShell — compare DWM events on a `POOL-FIN-02` host:**
```powershell
# Replace <pool2-hostname> with a POOL-FIN-02 session host name
Invoke-Command -ComputerName <pool2-hostname> -ScriptBlock {
    Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        Id        = 9011   # DWM started successfully — healthy baseline
        StartTime = (Get-Date).AddHours(-4)
    } -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Message |
    Select-Object -First 5 |
    Format-List
}
```

**Expected comparison result:**

| Pool | System log at sign-in | Meaning |
|---|---|---|
| `POOL-FIN-01` (affected) | Event ID `9009` present — DWM exited | Image fault confirmed |
| `POOL-FIN-02` (healthy baseline) | Event ID `9011` present — DWM started successfully | Image is clean; fault is pool-specific |

> If `POOL-FIN-02` also shows Event ID `9009` and **no** `9011` — stop. This is a platform-wide fault. Escalate as a P1 incident and do not continue with this KB article.

---

### Step D5 — Confirm a Recent Image Change to `POOL-FIN-01`

**Azure CLI — retrieve the current image version on an affected session host VM:**
```bash
az vm show \
  --resource-group <rg-name> \
  --name <affected-vm-name> \
  --query "storageProfile.imageReference" \
  --output table
```

**Azure CLI — check the Activity log for recent image or scale set changes:**
```bash
az monitor activity-log list \
  --resource-group <rg-name> \
  --start-time $(date -u -d '48 hours ago' +%Y-%m-%dT%H:%MZ) \
  --query "[?contains(operationName.value, 'reimage') || contains(operationName.value, 'write')].{Time:eventTimestamp, Operation:operationName.value, Status:status.value}" \
  --output table
```

**What to look for:** A reimage, scale set update, or image version change to `POOL-FIN-01` session hosts within the 24 hours before the first failure report.  
**Record:** The currently deployed image version returned by the first command. This value is required for rollback.

---

### Detection Summary — All Five Conditions Must Be True

| # | Condition | Confirmed by |
|---|---|---|
| D1 | Affected `POOL-FIN-01` session host identified | Azure CLI session host list |
| D2 | Application log Event ID `1000`: `dwm.exe` faulting on `igdumd64.dll` | PowerShell `Get-WinEvent` on affected host |
| D3 | System log Event ID `9009` timestamps align with user sign-in times | PowerShell `Get-WinEvent` on affected host |
| D4 | `POOL-FIN-02` shows Event ID `9011` (healthy) — no `9009` | PowerShell `Get-WinEvent` on `POOL-FIN-02` host |
| D5 | Recent image change to `POOL-FIN-01` confirmed | Azure CLI activity log or VM image query |

---

## 5. Resolution

> **Prerequisites before starting:**
> - Azure Portal access to the correct subscription
> - Azure Virtual Desktop RBAC role with permission to modify host pools, session hosts, and VM/scale set image configuration *(elevated — confirm with your team lead)*
> - Permission to place hosts in drain mode (`Allow new sessions = No`) *(elevated)*
> - Permission to reimage or redeploy session hosts *(elevated)*
> - Known good rollback image: **`build-20240313`**
> - Currently deployed image version recorded (from Step D5) before any changes
> - User-impact notification sent to affected Finance users before drain mode starts
>
> **Variables used in all commands below — set these once before starting:**
> ```powershell
> $rg        = "<resource-group-name>"          # Resource group containing POOL-FIN-01
> $pool      = "POOL-FIN-01"
> $vmssName  = "<vmss-name>"                    # VM scale set backing POOL-FIN-01
> $goodImage = "<image-version-resource-id>"    # Full resource ID for build-20240313
> # Example image ID format:
> # /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Compute/galleries/<gallery>/images/<image-def>/versions/build-20240313
> ```

---

### Phase 1 — Notify Users and Drain Affected Hosts

**Step R1.** Send a user-impact notification to the Finance support channel or user group stating that `POOL-FIN-01` sessions may disconnect during remediation and users should save work before reconnecting.  
*Expected result:* Affected users have been warned before any session disruption occurs.

---

**Step R2.** Get the list of all session hosts in `POOL-FIN-01` and their current session counts.

**Portal path:** `portal.azure.com` > **Azure Virtual Desktop** > **Host pools** > **POOL-FIN-01** > **Session hosts**

**Azure CLI:**
```bash
az desktopvirtualization sessionhost list \
  --resource-group $rg \
  --host-pool-name POOL-FIN-01 \
  --query "[].{Host:name, Status:status, Sessions:sessions, AllowNew:allowNewSession}" \
  --output table
```
*Expected result:* All `POOL-FIN-01` session host names are listed. Record each host name — you need them for Steps R3 and R11.

---

**Step R3.** Drain all affected session hosts by setting **Allow new sessions** to **No** on each. *(Elevated)*

**Portal path:** `portal.azure.com` > **Azure Virtual Desktop** > **Host pools** > **POOL-FIN-01** > **Session hosts** > `[select each host]` > **Settings** > **Properties** > **Allow new sessions** > set to **No** > **Save**

**PowerShell — drain all hosts in the pool in one pass:**
```powershell
$hosts = az desktopvirtualization sessionhost list `
  --resource-group $rg `
  --host-pool-name POOL-FIN-01 `
  --query "[].name" --output tsv

foreach ($h in $hosts) {
    az desktopvirtualization sessionhost update `
      --resource-group $rg `
      --host-pool-name POOL-FIN-01 `
      --name $h `
      --allow-new-session false
    Write-Host "Drained: $h"
}
```
*Expected result:* Every host in `POOL-FIN-01` shows `AllowNew: false`. No new user sessions will land on any of them.

---

**Step R4.** Confirm drain mode is active and session counts are stable.

**Azure CLI:**
```bash
az desktopvirtualization sessionhost list \
  --resource-group $rg \
  --host-pool-name POOL-FIN-01 \
  --query "[].{Host:name, Sessions:sessions, AllowNew:allowNewSession}" \
  --output table
```
*Expected result:* All hosts show `AllowNew: false`. Session counts are not increasing.

---

### Phase 2 — Record the Current Image and Update to `build-20240313`

**Step R5.** Record the currently deployed image version before making any change. *(Elevated)*

**Portal path:** `portal.azure.com` > **Virtual machine scale sets** > `[POOL-FIN-01 scale set name]` > **Settings** > **Operating system** > **Image** field

**Azure CLI:**
```bash
az vmss show \
  --resource-group $rg \
  --name $vmssName \
  --query "virtualMachineProfile.storageProfile.imageReference" \
  --output table
```
*Expected result:* The current image version is returned and recorded in the incident notes. This is your rollback target if the fix fails.

---

**Step R6.** Update the scale set image reference to `build-20240313`. *(Elevated)*

**Portal path:** `portal.azure.com` > **Virtual machine scale sets** > `[POOL-FIN-01 scale set name]` > **Settings** > **Operating system** > **Image** > change image version to `build-20240313` > **Save**

**Azure CLI:**
```bash
az vmss update \
  --resource-group $rg \
  --name $vmssName \
  --set virtualMachineProfile.storageProfile.imageReference.id=$goodImage
```
*Expected result:* The scale set image reference now points to `build-20240313`. Azure returns the updated VMSS object. The change applies to new or reimaged instances only — existing VMs are not automatically rebuilt yet.

---

### Phase 3 — Canary Reimage and Validation

**Step R7.** Select one drained host as the canary and reimage it. *(Elevated)*

Set `$canary` to one host name from Step R2 (e.g., `fin01-sh-001.POOL-FIN-01`).

**Portal path:** `portal.azure.com` > **Azure Virtual Desktop** > **Host pools** > **POOL-FIN-01** > **Session hosts** > `[select canary host]` > **Reimage** (or the equivalent action available in your environment)

**Azure CLI — reimage a specific VMSS instance:**
```bash
# Get the VMSS instance ID for the canary host
az vmss list-instances \
  --resource-group $rg \
  --name $vmssName \
  --query "[?computerName=='<canary-vm-name>'].instanceId" \
  --output tsv

# Reimage that instance (replace <instance-id> with the value above)
az vmss reimage \
  --resource-group $rg \
  --name $vmssName \
  --instance-id <instance-id>
```
*Expected result:* The canary host begins rebuilding on `build-20240313`.

---

**Step R8.** Poll the canary host until it returns to a healthy registered state.

**Azure CLI:**
```bash
az desktopvirtualization sessionhost show \
  --resource-group $rg \
  --host-pool-name POOL-FIN-01 \
  --name $canary \
  --query "{Status:status, AgentVersion:agentVersion, AllowNew:allowNewSession}" \
  --output table
```
*Expected result:* Status shows `Available`. Re-run every 60 seconds until this is true. Typical reimage time is 5–10 minutes.

---

**Step R9.** Connect to the canary host using a test account and confirm no black screen. Immediately check logs.

**PowerShell — verify no new dwm.exe crash on the canary after rebuild:**
```powershell
$rebuildTime = (Get-Date).AddMinutes(-15)  # adjust to when reimage completed

Invoke-Command -ComputerName <canary-vm-name> -ScriptBlock {
    param($since)
    # Check for dwm.exe crash (should be absent)
    $crashes = Get-WinEvent -FilterHashtable @{
        LogName='Application'; Id=1000; StartTime=$since
    } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'dwm\.exe' -and $_.Message -match 'igdumd64\.dll' }

    # Check for DWM exit (should be absent)
    $exits = Get-WinEvent -FilterHashtable @{
        LogName='System'; Id=9009; StartTime=$since
    } -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        DWMCrashes_1000 = $crashes.Count
        DWMExits_9009   = $exits.Count
        Result          = if ($crashes.Count -eq 0 -and $exits.Count -eq 0) { "PASS - safe to proceed" } else { "FAIL - do not proceed" }
    }
} -ArgumentList $rebuildTime
```
*Expected result:* `DWMCrashes_1000 = 0`, `DWMExits_9009 = 0`, `Result = PASS - safe to proceed`.

> **Do not proceed to Step R10 unless the canary returns PASS.**  
> If the canary fails, go to Section 7 (Rollback) immediately.

---

### Phase 4 — Reimage Remaining Hosts

**Step R10.** Reimage all remaining drained `POOL-FIN-01` hosts. *(Elevated)*

**PowerShell — reimage all remaining instances in the scale set:**
```powershell
# Get all instance IDs in the POOL-FIN-01 scale set except the canary
$instances = az vmss list-instances `
  --resource-group $rg `
  --name $vmssName `
  --query "[?computerName!='<canary-vm-name>'].instanceId" `
  --output tsv

foreach ($id in $instances) {
    az vmss reimage `
      --resource-group $rg `
      --name $vmssName `
      --instance-id $id
    Write-Host "Reimaging instance: $id"
}
```
*Expected result:* All remaining hosts begin rebuilding on `build-20240313`.

---

**Step R11.** Poll until all hosts are back to `Available`, then re-enable new sessions. *(Elevated)*

**Azure CLI — check all host statuses:**
```bash
az desktopvirtualization sessionhost list \
  --resource-group $rg \
  --host-pool-name POOL-FIN-01 \
  --query "[].{Host:name, Status:status, AllowNew:allowNewSession}" \
  --output table
```

**PowerShell — re-enable new sessions on all hosts once Available:**
```powershell
$hosts = az desktopvirtualization sessionhost list `
  --resource-group $rg `
  --host-pool-name POOL-FIN-01 `
  --query "[].name" --output tsv

foreach ($h in $hosts) {
    az desktopvirtualization sessionhost update `
      --resource-group $rg `
      --host-pool-name POOL-FIN-01 `
      --name $h `
      --allow-new-session true
    Write-Host "Enabled: $h"
}
```

**Portal path (if doing manually):** `portal.azure.com` > **Azure Virtual Desktop** > **Host pools** > **POOL-FIN-01** > **Session hosts** > `[select each host]` > **Settings** > **Properties** > **Allow new sessions** > set to **Yes** > **Save**

*Expected result:* All rebuilt hosts show `Status: Available` and `AllowNew: true`.

---

**Step R12.** Ask at least two previously affected Finance users to sign in to `POOL-FIN-01` via the normal AVD client. Record their sign-in times in the incident notes.  
*Expected result:* Both users reach a usable desktop on the first attempt. No black screen.

---

## 6. Verification

> Do not close the incident until every step in this section passes.

**Step V1.** Confirm all hosts are available and accepting sessions.

**Azure CLI:**
```bash
az desktopvirtualization sessionhost list \
  --resource-group $rg \
  --host-pool-name POOL-FIN-01 \
  --query "[].{Host:name, Status:status, Sessions:sessions, AllowNew:allowNewSession}" \
  --output table
```

**Portal path:** `portal.azure.com` > **Azure Virtual Desktop** > **Host pools** > **POOL-FIN-01** > **Session hosts**

*Expected result:* Every host shows `Status: Available` and `AllowNew: true`. Session counts are increasing as users sign in.

---

**Step V2.** Confirm the deployed image version is now `build-20240313` across all hosts.

**Azure CLI:**
```bash
az vmss show \
  --resource-group $rg \
  --name $vmssName \
  --query "virtualMachineProfile.storageProfile.imageReference.{Publisher:publisher, Offer:offer, Version:exactVersion}" \
  --output table
```

**Portal path:** `portal.azure.com` > **Virtual machine scale sets** > `[POOL-FIN-01 scale set name]` > **Settings** > **Operating system** > **Image** field

*Expected result:* Image version returned is `build-20240313`, not the previous defective build.

---

**Step V3.** Confirm no new `dwm.exe` crashes or DWM exits on rebuilt hosts after user sign-ins.

**PowerShell — run against one or more restored hosts:**
```powershell
$validationStart = (Get-Date).AddMinutes(-30)  # from when first host was restored

Invoke-Command -ComputerName <restored-host-name> -ScriptBlock {
    param($since)
    $crashes = Get-WinEvent -FilterHashtable @{
        LogName='Application'; Id=1000; StartTime=$since
    } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'dwm\.exe' -and $_.Message -match 'igdumd64\.dll' }

    $exits = Get-WinEvent -FilterHashtable @{
        LogName='System'; Id=9009; StartTime=$since
    } -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        DWMCrashes_1000 = $crashes.Count
        DWMExits_9009   = $exits.Count
        Result          = if ($crashes.Count -eq 0 -and $exits.Count -eq 0) { "PASS" } else { "FAIL" }
    }
} -ArgumentList $validationStart
```
*Expected result:* `DWMCrashes_1000 = 0`, `DWMExits_9009 = 0`, `Result = PASS`.

---

**Step V4.** Confirm `POOL-FIN-02` remains unaffected.

**Azure CLI:**
```bash
az desktopvirtualization sessionhost list \
  --resource-group $rg \
  --host-pool-name POOL-FIN-02 \
  --query "[].{Host:name, Status:status, AllowNew:allowNewSession}" \
  --output table
```

**Portal path:** `portal.azure.com` > **Azure Virtual Desktop** > **Host pools** > **POOL-FIN-02** > **Session hosts**

*Expected result:* All `POOL-FIN-02` hosts show `Status: Available`. No new Finance user complaints related to `POOL-FIN-02` in the incident channel.

---

**Step V5.** Record the following in the incident notes and mark the incident resolved:
- Final image version deployed: `build-20240313`
- All host statuses: `Available`
- User validation: two Finance users confirmed desktop loaded without black screen
- Clean log confirmation: Event ID `1000` (`igdumd64.dll`) and `9009` absent post-remediation
- Timestamp of resolution

---

## 7. Rollback

Use this section immediately if any step in Phase 3 or Phase 4 of Resolution produces new registration failures, broader login errors, or if canary validation (Step R9) returns `FAIL`.

---

**Step RB1.** Drain any host showing black-screen behaviour or failed validation immediately. *(Elevated)*

**PowerShell — drain a specific failing host:**
```powershell
az desktopvirtualization sessionhost update `
  --resource-group $rg `
  --host-pool-name POOL-FIN-01 `
  --name <failing-host-name> `
  --allow-new-session false
```

**Portal path:** `portal.azure.com` > **Azure Virtual Desktop** > **Host pools** > **POOL-FIN-01** > **Session hosts** > `[select failing host]` > **Settings** > **Properties** > **Allow new sessions** > **No** > **Save**

*Expected result:* Failing hosts are drained. Hosts that passed canary validation remain on `AllowNew: true` and continue serving users.

---

**Step RB2.** Revert the scale set image reference to the pre-remediation version recorded in Step R5. *(Elevated)*

**Portal path:** `portal.azure.com` > **Virtual machine scale sets** > `[POOL-FIN-01 scale set name]` > **Settings** > **Operating system** > **Image** > change back to the version recorded in Step R5 > **Save**

**Azure CLI:**
```bash
# Replace $previousImage with the image resource ID recorded in Step R5
az vmss update \
  --resource-group $rg \
  --name $vmssName \
  --set virtualMachineProfile.storageProfile.imageReference.id=$previousImage
```
*Expected result:* Scale set image reference is restored to the pre-remediation version. Azure confirms the update.

---

**Step RB3.** Reimage one failed host only (single-host rollback validation). *(Elevated)*

**Azure CLI:**
```bash
az vmss reimage \
  --resource-group $rg \
  --name $vmssName \
  --instance-id <failing-instance-id>
```

**Portal path:** `portal.azure.com` > **Azure Virtual Desktop** > **Host pools** > **POOL-FIN-01** > **Session hosts** > `[select one failed host]` > **Reimage**

*Expected result:* One host rebuilds against the restored image reference.

---

**Step RB4.** Poll the rollback host until it returns to `Available`, then test sign-in.

**Azure CLI:**
```bash
az desktopvirtualization sessionhost show \
  --resource-group $rg \
  --host-pool-name POOL-FIN-01 \
  --name <rollback-host-name> \
  --query "{Status:status, AllowNew:allowNewSession}" \
  --output table
```
*Expected result:* Status returns `Available`. Then ask a test user to sign in via the AVD client.

---

**Step RB5.** Immediately check rollback host logs for `dwm.exe` crashes.

**PowerShell:**
```powershell
$rbStart = (Get-Date).AddMinutes(-10)

Invoke-Command -ComputerName <rollback-host-name> -ScriptBlock {
    param($since)
    $crashes = Get-WinEvent -FilterHashtable @{
        LogName='Application'; Id=1000; StartTime=$since
    } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'dwm\.exe' -and $_.Message -match 'igdumd64\.dll' }

    [PSCustomObject]@{
        DWMCrashes_1000 = $crashes.Count
        Verdict = if ($crashes.Count -eq 0) { "ROLLBACK CLEAN - proceed to reimage remaining hosts" }
                  else { "ROLLBACK ALSO DEFECTIVE - escalate immediately" }
    }
} -ArgumentList $rbStart
```

| Verdict | Action |
|---|---|
| `ROLLBACK CLEAN` | Re-enable sessions on this host and reimage remaining failed hosts against the restored image |
| `ROLLBACK ALSO DEFECTIVE` | The pre-remediation image also has the defect — stop all reimaging, escalate to image engineering |

---

**Step RB6.** If rollback is also defective — escalate immediately.

Keep one failing host in drain mode without further reimage attempts (evidence host). Apply the session-level workaround for Finance users in the interim:

```powershell
# Run on a working host or ask user to run in their AVD session once desktop loads
# This disables GPU compositing temporarily to allow DWM to start without the driver
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Terminal Server Client" `
  -Name "DisableHWAcceleration" -Value 1 -Type DWORD
```

Escalate to image engineering with:
- Output of Step R5 (original image ID)
- Output of Step RB2 (rollback image ID)
- PowerShell output from Step RB5 showing crashes on both images
- Current host list status from `az desktopvirtualization sessionhost list`

---

## 8. Preventive Actions

The following controls prevent this class of failure from recurring. Each control states who owns it, when it fires, what the pass/fail signal is, and what happens on failure. Controls are strengthened from the original RCA — do not remove any entry.

---

### PA-1 — Known-Defective-Driver Registry
**Timing:** Pre-deployment | **Mode:** Manual *(automatable — see note)* | **Owner:** Image Owner

Before any new image build is submitted for change approval, the Image Owner must extract the `igdumd64.dll` file version from the build artefact and search it against the known-defective-driver registry.

**Pass criteria:** The driver version is not listed in the registry. The Image Owner records `Driver version checked: [version] — not listed` in the change record.  
**Fail action:** If the version is listed as defective, the build is rejected at change approval. The Image Owner must update the driver to a clean version and re-run the check before resubmitting.  
**Automation note:** Extract `igdumd64.dll` version automatically during image build pipeline using `Get-Item` and compare against the registry via a CI script. Flag as a build-blocking error if matched.  
**[REQUIRES: Known-defective-driver registry — SharePoint list or ITSM knowledge article to be created by Image Owner before next image release]**

---

### PA-2 — Mandatory GPU Driver Smoke Test in Build Pipeline
**Timing:** Pre-deployment | **Mode:** Manual *(automatable — see note)* | **Owner:** Image Owner

After building the image but before promoting it to the image gallery, the Image Owner must sign in to a single test session host using the new image and observe the session for 10 minutes.

**Pass criteria:** Zero occurrences of Event ID `1000` (source: `Application Error`, faulting app: `dwm.exe`, faulting module: `igdumd64.dll`) AND zero occurrences of Event ID `9009` (source: `Desktop Window Manager`) in the Application and System logs during the 10-minute window. The Image Owner records the log check result and `igdumd64.dll` version in the build artefacts.  
**Fail action:** If either event appears, the build is blocked from gallery promotion. The Image Owner raises a defect, identifies the driver version causing the crash, adds it to the PA-1 registry, and rebuilds with a clean driver before retesting.  
**Automation note:** Run `Get-WinEvent` for Event IDs `1000` and `9009` as a post-provision pipeline step on the test host; return non-zero exit code to block gallery publish if either count > 0.

---

### PA-3 — Mandatory Canary Deployment Stage for `POOL-FIN-01` Image Updates
**Timing:** In-flight (during deployment) | **Mode:** Manual | **Owner:** Release Engineer

The `POOL-FIN-01` change record template must include a mandatory canary field. Before reimaging all hosts, one session host is reimaged and a test or Finance user performs a sign-in.

**Pass criteria:** The canary host returns `Status: Available`; the test user reaches the desktop on the first attempt without a black screen; and the PowerShell check from Resolution Step R9 returns `DWMCrashes_1000 = 0`, `DWMExits_9009 = 0`, `Result = PASS`. The Release Engineer records these values in the change record.  
**Fail action:** If the canary returns `FAIL`, the Release Engineer halts the deployment immediately, drains the canary host, and initiates the rollback procedure (Section 7 of this article) before any further hosts are reimaged. The change record is updated with `Canary: FAIL — rollback initiated`.  
**Automation note:** The `Invoke-Command` PowerShell block from Resolution Step R9 can be wrapped as a deployment pipeline validation task that auto-fails the deployment if the verdict is not `PASS`.

---

### PA-4 — `POOL-FIN-02` as Mandatory Pre-Production Validation Pool
**Timing:** Pre-deployment | **Mode:** Manual | **Owner:** Endpoint Engineering

Before submitting a change to deploy a new image to `POOL-FIN-01`, Endpoint Engineering must deploy the same image to `POOL-FIN-02` and observe it for a minimum of one full business day (8 hours of active Finance user sign-ins).

**Pass criteria:** Zero reports of black-screen behaviour from `POOL-FIN-02` users during the observation window AND zero Event ID `1000` (`igdumd64.dll`) entries on any `POOL-FIN-02` session host during that period. The count must be confirmed using `Get-WinEvent` and recorded in the change record.  
**Fail action:** If any Event ID `1000` (`igdumd64.dll`) or black-screen report is observed on `POOL-FIN-02`, the `POOL-FIN-01` change is blocked. Endpoint Engineering raises a defect against the image version and notifies the Image Owner to identify a clean driver build before rescheduling.  
**Automation note:** Schedule a daily `Get-WinEvent` query against `POOL-FIN-02` hosts via Azure Monitor or a Scheduled Task; output a pass/fail count to the change record.

---

### PA-5 — Rollback Checkpoint Required in Every `POOL-FIN-01` Image Change Record
**Timing:** Pre-deployment | **Mode:** Manual | **Owner:** Change Manager

The Change Manager must not approve a `POOL-FIN-01` image deployment change record unless the following three fields are completed: (1) the exact rollback image version name and gallery resource ID, (2) confirmation the rollback image is accessible in the Azure Compute Gallery, and (3) the estimated time to complete a full pool rollback in minutes.

**Pass criteria:** All three fields are present and the rollback image accessibility is verified by the Release Engineer running `az sig image-version show` and recording the HTTP 200 response in the change record.  
**Fail action:** Change is rejected by the Change Manager. The Release Engineer must complete all three fields and re-confirm gallery accessibility before resubmission.  
**Automation note:** Add a Change Advisory Board (CAB) form validation rule that blocks submission if the rollback image ID field is empty.  
**[REQUIRES: CAB tooling supports mandatory field validation — verify with Change Manager]**

---

### PA-6 — Azure Monitor Alert for `dwm.exe` Crashes on `POOL-FIN-01` Hosts
**Timing:** In-flight (continuous, active during and after deployment) | **Mode:** Automated | **Owner:** Azure Platform / Monitoring Team

A Log Analytics workspace alert rule must fire a P2 incident ticket automatically when two or more `POOL-FIN-01` session hosts log Event ID `1000` with `dwm.exe` as the faulting application within any 5-minute window.

**Pass criteria (alert is working):** A test event injection or synthetic log entry triggers the alert within 5 minutes. The Monitoring Team confirms the alert is active and linked to the ITSM ticketing system before the next deployment window.  
**Fail action (alert fires during deployment):** The auto-raised P2 ticket is assigned to the on-call DWP Engineer. The engineer drains all hosts immediately and initiates the rollback procedure without waiting for user reports. The deployment change record is updated with the alert trigger time.  
**[REQUIRES: Log Analytics workspace with POOL-FIN-01 Windows Event data onboarded — confirm with Azure Platform Team before next deployment]**

---

### PA-7 — Post-Deployment Health Check Before Change Closure
**Timing:** Post-deployment | **Mode:** Manual | **Owner:** Release Engineer

Within 30 minutes of completing a `POOL-FIN-01` image deployment, the Release Engineer must run the following check against at least two restored session hosts and record the output in the change record before marking the change as closed.

```powershell
# Run on each restored host — both must return PASS
$since = (Get-Date).AddMinutes(-30)
Invoke-Command -ComputerName <hostname> -ScriptBlock {
    param($s)
    $c1 = (Get-WinEvent -FilterHashtable @{LogName='Application';Id=1000;StartTime=$s} `
           -EA SilentlyContinue | Where-Object {$_.Message -match 'dwm\.exe'}).Count
    $c2 = (Get-WinEvent -FilterHashtable @{LogName='System';Id=9009;StartTime=$s} `
           -EA SilentlyContinue).Count
    [PSCustomObject]@{ Event1000=$c1; Event9009=$c2; Result=if($c1+$c2 -eq 0){"PASS"}else{"FAIL"} }
} -ArgumentList $since
```

**Pass criteria:** Both hosts return `Event1000 = 0`, `Event9009 = 0`, `Result = PASS`. Output is pasted into the change record and the change is marked closed.  
**Fail action (rollback trigger):** If either host returns `FAIL`, the Release Engineer must not close the change. The rollback procedure (Section 7) is initiated immediately. The change record is updated with `Post-deployment check: FAIL — rollback initiated at [timestamp]`. The PA-6 alert threshold also serves as an automated trigger — if the alert fires before this manual check is complete, treat it as an automatic rollback trigger.

---

### PA-8 — Pre-Deployment Smoke Test Gate (New Control — Gap: Pre-release automated test)
**Timing:** Pre-deployment | **Mode:** Automated | **Owner:** Image Owner  
**Gap addressed:** No automated test gate existed before image promotion to gallery.

After a new image version is built, a CI pipeline step must provision a temporary test session host from the new image, run a synthetic sign-in, and execute the `Get-WinEvent` check for Event IDs `1000` and `9009`. The host is destroyed after the test regardless of outcome.

**Pass criteria:** Zero Event ID `1000` (`igdumd64.dll`) and zero Event ID `9009` events in the 5-minute post-sign-in window. The pipeline records `SMOKE_TEST=PASS` in the build artefact metadata.  
**Fail action:** Pipeline marks the image version as `BLOCKED`, prevents gallery publish, and creates a defect ticket assigned to the Image Owner. No manual override is permitted without Change Manager approval.  
**[REQUIRES: AVD image CI/CD pipeline capable of provisioning and destroying test hosts — assess with Image Owner and Azure Platform Team]**

---

### PA-9 — In-Flight Deployment Monitoring Window (New Control — Gap: Active alert during rollout)
**Timing:** In-flight | **Mode:** Manual with automated signal | **Owner:** Release Engineer  
**Gap addressed:** No defined monitoring window existed during the rollout itself.

During any `POOL-FIN-01` image deployment, the Release Engineer must keep the PA-6 Azure Monitor alert dashboard open for the duration of the rollout plus 30 minutes post-completion. The deployment change record must log a monitoring start time and end time.

**Pass criteria:** PA-6 alert does not fire during the monitoring window. Session counts on restored hosts increase normally. The Release Engineer records `Monitoring window: [start] to [end] — no alerts fired` in the change record.  
**Fail action:** If PA-6 fires at any point during the window, the Release Engineer treats it as an immediate rollback trigger — drain all hosts and initiate Section 7 without escalation delay.

---

### PA-10 — Rollback Trigger Threshold Definition (New Control — Gap: Explicit rollback trigger)
**Timing:** In-flight / Post-deployment | **Mode:** Manual decision backed by automated signal | **Owner:** Release Engineer  
**Gap addressed:** No explicit numeric threshold defined for when to trigger rollback vs. investigate further.

The following thresholds must be documented in the `POOL-FIN-01` deployment runbook and change record. Any single threshold being hit is sufficient to trigger immediate rollback without further investigation.

| Threshold | Value | Source |
|---|---|---|
| Event ID `1000` (`igdumd64.dll`) on any single host within 10 minutes of reimage | ≥ 1 occurrence | PowerShell check / PA-6 alert |
| Event ID `9009` on any single host within 10 minutes of reimage | ≥ 1 occurrence | PowerShell check / PA-6 alert |
| PA-6 Azure Monitor alert fires | Any trigger | Automated |
| Users reporting black screen after canary validation passed | ≥ 2 reports within 15 minutes | Service Desk |

**Pass criteria:** All thresholds remain at zero during and after deployment. Release Engineer records threshold check outcome in change record.  
**Fail action:** Release Engineer initiates rollback (Section 7) the moment any threshold is hit. Does not wait for additional confirmation.

---

### PA-11 — Knowledge and Runbook Update After Each `POOL-FIN-01` Image Incident (New Control — Gap: Knowledge update)
**Timing:** Post-incident | **Mode:** Manual | **Owner:** DWP Engineer (incident owner)

Within five business days of any `POOL-FIN-01` image-related incident being closed, the DWP Engineer who owned the incident must review this KB article and the associated runbook against the actual steps taken during the incident.

**Pass criteria:** Any step that was incorrect, missing, or unclear during the incident is updated. The KB article version number is incremented (e.g., v1.0 → v1.1), the date is updated, and the change is committed to the repository. The updated article reference is added to the closed incident record.  
**Fail action:** If the review is not completed within five business days, the Service Desk Lead escalates to the DWP Engineer's line manager. The incident cannot be marked as fully closed in the ITSM system until the KB version field is updated.  
**[REQUIRES: ITSM system supports a KB version field linked to the incident — verify with Service Desk Lead]**

---

## 9. Related Incidents and KB Articles

| Reference | Type | Summary |
|---|---|---|
| AVD-POOL-FIN-01-2026-08-06 | Incident | Source incident for this KB article — black screen on all `POOL-FIN-01` sign-ins after image update containing defective `igdumd64.dll` |
| RCA-AVD-POOL-FIN-01-2026-08-06 | RCA Document | Full root cause analysis for the black screen incident — 5-Why, hypothesis elimination, corrective actions |
| Runbook-AVD-POOL-FIN-01 | Runbook | Step-by-step engineer runbook for active remediation of this incident pattern |
| KB-DRIVE-MAP-FIN-001 | KB Article | Finance endpoint KB — `S:` drive not assigned at sign-in after Intune context change; related Finance infrastructure |
| AVD Image Deployment Runbook | Process Document | Must be updated per PA-3, PA-4, and PA-7 above |
| Known-Defective-Driver Registry | Process Artefact | To be created per PA-1 above — tracks GPU driver versions confirmed defective on session hosts |

---

*KB Article prepared by DWP Engineer | Derived from Runbook AVD-POOL-FIN-01 and RCA AVD-POOL-FIN-01-2026-08-06 | v1.0 | 07/08/2026 | Status: Draft*
