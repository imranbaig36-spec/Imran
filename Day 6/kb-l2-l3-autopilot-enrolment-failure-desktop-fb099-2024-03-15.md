# KB Article — Autopilot Enrolment Failure (Legacy MDM Record Blocking Re-Enrolment)

| Field | Value |
|---|---|
| **KB Reference** | KB-L2-L3-AUTOPILOT-ENROL-001 |
| **Version** | v1.0 |
| **Date** | 11/08/2026 |
| **Status** | Draft |
| **Author** | DWP Engineer |
| **Incident Reference** | INC-FINBRIDGE-20240315-001 |
| **Applies To** | Any device in the FinBridge migration programme failing Autopilot enrolment with error `0x80180014`; Windows 11 devices with pre-existing legacy manual MDM enrolment |

---

## 1. Background

### What the System Does

The FinBridge migration programme moves endpoint devices from legacy manual MDM management to Windows Autopilot. During Autopilot, a device contacts the Microsoft MDM service during OOBE (Out-of-Box Experience), downloads an Autopilot deployment profile, and automatically receives configuration policies, security baselines, and compliance settings — all without a technician touching the device directly.

This process requires the device to have no existing active MDM enrolment. Microsoft's MDM stack enforces a one-enrolment-per-device rule: if the device already holds an active enrolment record in Intune, the new Autopilot enrolment is immediately rejected.

### Why It Matters

A failed Autopilot enrolment means the assigned user cannot receive a managed desktop. Zero configuration profiles are applied, the security baseline is absent, and the device sits in an unknown compliance state. For the FinBridge migration programme, any device with a legacy manual MDM enrolment (enrolled before the Autopilot programme began) is at risk of this failure if it enters the migration queue without a pre-flight check.

### The Legacy Enrolment Risk Context

Devices that were provisioned manually into MDM before the Autopilot programme have an active enrolment record in Intune. Unless this record is explicitly deleted before Autopilot is triggered, the MDM service will reject the new enrolment. The rejection is deterministic — the same device will fail on every Autopilot attempt until the legacy record is removed.

| Scenario | What It Means |
|---|---|
| Single device fails, others in batch succeed | Isolated legacy record on one device — use this KB article |
| Multiple devices in the same batch fail with `0x80180014` | Batch was not pre-screened for legacy records — run estate audit before continuing |
| Device fails with a different error code | Different failure class — do not use this KB article as primary path |

---

## 2. Symptoms

### What the User or Technician Reports

- Device is stuck at the OOBE setup screen and does not progress past "Setting up your device."
- OOBE displays an error or the setup completes but the device is not managed (no policies applied).
- Autopilot enrolment shows as failed in Intune Admin Center.
- The assigned user cannot log in to a configured managed desktop.

### What the Engineer Observes

- Intune Admin Center: **Devices → Monitor → Autopilot deployments** shows `Failed` for the device.
- MDM diagnostic export on the device shows `EnrolmentState: Failed` and `ErrorCode: 0x80180014`.
- A second device record exists in **Devices → All devices** with an older enrolment date and source `Manual` or `Legacy`.
- `DeviceInfo` in the MDM export shows `MDMEnrolled: Yes (previous enrolment)` and `EnrolmentSource: Legacy`.
- `PolicyManager` shows `ProfilesAttempted: 4`, `ProfilesApplied: 0`, `LastError: 0x80070005`.
- `ComplianceEngine` shows `EvaluationResult: Could not evaluate`.
- Licensing, network, TPM, Secure Boot, and Azure AD join are all confirmed healthy.

> **Key diagnostic signal:** Error `0x80180014` is deterministic. If you see it, the fix is always to remove the existing enrolment record first. Do not attempt to reimage, repair, or re-trigger Autopilot without clearing the legacy record — it will fail again.

---

## 3. Root Cause

### Technical Root Cause

The device was manually enrolled in MDM at an earlier date and that enrolment record was never retired from Intune before the Autopilot migration was triggered. When Autopilot contacts the Microsoft MDM service, the service detects the existing active enrolment and immediately rejects the new enrolment with error `0x80180014`. Because the enrolment fails, the PolicyManager cannot obtain management authority and all profile pushes fail with `0x80070005` (Access Denied). The ComplianceEngine cannot evaluate compliance because enrolment is incomplete.

The root cause is a process gap: the migration runbook contained no pre-flight check requiring technicians to verify and remove existing MDM enrolment records before triggering Autopilot.

### Confirming Evidence

| Evidence | What It Proves |
|---|---|
| `EnrolmentState: Failed`, `ErrorCode: 0x80180014` in MDM export | MDM service rejected the Autopilot enrolment due to existing active record |
| `MDMEnrolled: Yes (previous enrolment)`, `EnrolmentSource: Legacy` in MDM export | A legacy manual enrolment is active on the device |
| `ProfilesApplied: 0 of 4`, `LastError: 0x80070005` | Zero policies applied — legacy enrolment holds the management authority lock |
| `EvaluationResult: Could not evaluate` | Compliance cannot be assessed with enrolment incomplete |
| Licensing, network, TPM, Secure Boot, Azure AD join all healthy | All infrastructure prerequisites met — sole blocking condition is the legacy record |
| Second device record in Intune with older enrolment date and source Manual/Legacy | The legacy record is visible and removable in Admin Center |

---

## 4. Detection

> Complete **all** detection steps before acting. Do not proceed to resolution until all conditions are confirmed.

---

### Step D1 — Locate the Device in Intune Admin Center

**Portal path:** `intune.microsoft.com` > **Devices** > **All devices**  
**What to do:** Search for the device name (e.g. `DESKTOP-FB099`).

**What to look for:**

| Finding | Meaning |
|---|---|
| Two records for the same device | Legacy record and Autopilot record coexist — this is the failure |
| One record, source `Manual` or `Legacy` | Legacy record was never removed — this is the failure |
| One record, source `Autopilot`, status `Failed` | Autopilot attempted but blocked — check MDM export in D2 |

Record the enrolment date and source of every record found. You need the legacy record's exact name to delete it in Resolution.

---

### Step D2 — Confirm Error Code `0x80180014` via MDM Diagnostic Export

**How to run the MDM diagnostic export on the affected device:**

**Option A — Device-side (if accessible):**
```
msdt.exe -id DeviceDiagnostic
```
Or:
```
mdmdiagnosticstool.exe -area Autopilot -cab C:\Temp\MDMDiag.cab
```
Extract the cab and open `MDMDiagReport.html`.

**Option B — PowerShell remote (if device is accessible on network):**
```powershell
Invoke-Command -ComputerName <device-name> -ScriptBlock {
    & "C:\Windows\System32\mdmdiagnosticstool.exe" -area Autopilot -cab "C:\Temp\MDMDiag.cab"
}
```

**What to confirm in the export:**

| Field | Required value |
|---|---|
| `EnrolmentState` | `Failed` |
| `ErrorCode` | `0x80180014` |
| `ErrorDescription` | `The device is already enrolled in MDM.` |
| `MDMEnrolled` | `Yes (previous enrolment)` |
| `EnrolmentSource` | `Legacy` |
| `ProfilesApplied` | `0` |

> If `ErrorCode` is **not** `0x80180014` — stop. A different failure class is present. Record the actual error code and escalate separately. Do not proceed with this KB article.

---

### Step D3 — Confirm Autopilot Profile Is Assigned

**Portal path:** `intune.microsoft.com` > **Devices** > **Enrolment** > **Windows** > **Autopilot deployment profiles**

Confirm the expected Autopilot profile (e.g. `FinBridge-Autopilot-Standard`) is assigned to a group that includes this device or user.

**Portal path:** `intune.microsoft.com` > **Devices** > **Enrolment** > **Windows** > **Autopilot devices**

Confirm the device serial number is registered.

**Azure CLI:**
```bash
az desktopvirtualization sessionhost list 2>/dev/null || \
az rest --method GET \
  --url "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities" \
  --query "value[?contains(serialNumber, '<serial>')]" \
  --output table
```

> If the device is not registered in Autopilot devices — stop. Register the device serial first before proceeding. The enrolment will not succeed without Autopilot registration regardless of the legacy record removal.

---

### Step D4 — Confirm Licensing and Network Are Not the Cause

Review the MDM diagnostic export sections:

| Section | Expected value |
|---|---|
| `M365LicenseFound` | `Yes` |
| `IntuneP1License` | `Yes` |
| `AutopilotLicense` | `Yes` |
| `EndpointReach: login.microsoftonline.com` | `OK` |
| `EndpointReach: enrollment.manage.microsoft.com` | `OK` |
| `EndpointReach: enterpriseregistration.windows.net` | `OK` |
| `ProxyDetected` | `No` |
| `AzureADJoined` | `Yes` |
| `TPMStatus` | `Ready` |
| `SecureBoot` | `Enabled` |

> If any licensing or network endpoint fails — stop. Resolve licensing or connectivity first before attempting enrolment again. Do not proceed with this KB article as the primary path.

---

### Step D5 — Confirm the Legacy Enrolment Record Is Deletable

**Portal path:** `intune.microsoft.com` > **Devices** > **All devices** > `[select legacy record]`

Confirm:
1. The record's enrolment source shows `Manual` or `Legacy`.
2. The enrolment date predates the Autopilot programme start.
3. The **Delete** action is available on the record (not greyed out).

> If Delete is greyed out — the record may be the primary Autopilot record or there may be a compliance hold. Do not attempt to delete without escalating to the Intune Administrator.

---

### Detection Summary — All Five Conditions Must Be True

| # | Condition | Confirmed by |
|---|---|---|
| D1 | Legacy MDM enrolment record found for the device in Intune | Intune Admin Center — All devices |
| D2 | MDM export confirms `ErrorCode: 0x80180014` and `EnrolmentSource: Legacy` | MDM diagnostic export on device |
| D3 | Autopilot profile assigned and device serial registered | Intune Admin Center — Autopilot profiles and devices |
| D4 | Licensing, network, TPM, and Azure AD all healthy — not the cause | MDM diagnostic export |
| D5 | Legacy record is deletable in Intune Admin Center | Intune Admin Center — Delete action available |

---

## 5. Resolution

> **Prerequisites before starting:**
> - Intune Admin Center access with **Intune Administrator** or **Help Desk Operator** RBAC role
> - Permission to delete device records from Intune *(elevated — confirm with your team lead)*
> - Permission to wipe a device remotely from Intune *(elevated)*
> - Physical or remote KVM access to the device for OOBE completion
> - Assigned user notified that their device will be wiped and re-provisioned
> - All detection steps (D1–D5) confirmed before starting

---

### Phase 1 — Notify the Assigned User

**Step R1.** Inform the assigned user (e.g. `FINBRIDGE\rthomas`) that their device will be wiped and re-provisioned. Confirm they have no unsaved local data. If the device never completed OOBE this step may not be needed, but verify before wiping.

*Expected result:* User is aware and has confirmed no local data is at risk.

---

### Phase 2 — Delete the Legacy MDM Enrolment Record

**Step R2.** Delete the legacy MDM enrolment record from Intune. *(Elevated)*

**Portal path:** `intune.microsoft.com` > **Devices** > **All devices** > search device name > open the record with the older enrolment date and source `Manual` or `Legacy` > **Delete** > confirm.

Wait 5–10 minutes after deletion before proceeding. The record must clear fully from the Intune service before a new enrolment can succeed.

**Verification — confirm the legacy record is gone:**

**Portal path:** `intune.microsoft.com` > **Devices** > **All devices** > search device name again.

*Expected result:* Only one record remains (or no record if the Autopilot failed record was also cleaned up). No record with source `Manual` or `Legacy` is present.

---

### Phase 3 — Verify Autopilot Profile Assignment

**Step R3.** Confirm the Autopilot profile is correctly assigned before triggering the wipe.

**Portal path:** `intune.microsoft.com` > **Devices** > **Enrolment** > **Windows** > **Autopilot deployment profiles** > open `FinBridge-Autopilot-Standard` > **Assignments**

Confirm the device or user is in an assigned group.

**Portal path:** `intune.microsoft.com` > **Devices** > **Enrolment** > **Windows** > **Autopilot devices**

Confirm the device serial is registered and the profile column shows `FinBridge-Autopilot-Standard`.

*Expected result:* Profile is assigned and device serial is registered. If not — resolve profile assignment before wiping.

---

### Phase 4 — Wipe the Device

**Step R4.** Wipe the device from Intune Admin Center. *(Elevated)*

**Portal path:** `intune.microsoft.com` > **Devices** > **All devices** > open the device record > **Wipe**

> Leave **"Wipe device, but keep enrolment state and associated user account"** **unchecked**. A clean OOBE state is required.

Confirm the wipe.

*Expected result:* Device receives the wipe command and begins resetting. If the device is offline, physical access is required to initiate the wipe manually (Settings > System > Recovery > Reset this PC).

---

### Phase 5 — Complete Autopilot OOBE

**Step R5.** Once the device has finished wiping and restarts to OOBE, complete the Autopilot setup. Physical or remote KVM access is required.

1. At the OOBE welcome screen, confirm the `FinBridge-Autopilot-Standard` Autopilot profile loads automatically (device should display the organisation branding/customisation set in the profile).
2. Sign in as `FINBRIDGE\rthomas` when prompted.
3. Allow provisioning to complete without interruption — do not close the provisioning screen or power off the device.

*Expected result:* Provisioning completes. Device proceeds to the Windows desktop with all policies applied.

---

### Phase 6 — Verify Enrolment and Policy Compliance

**Step R6.** Verify the enrolment was successful.

**Portal path — Admin Center checks:**

| Check | Portal path | Expected result |
|---|---|---|
| Enrolment source | Devices → All devices → open device | `Autopilot` |
| Enrolment date | Devices → All devices → open device | Today's date |
| Autopilot deployment status | Devices → Monitor → Autopilot deployments | `Enrolled`, no error |
| Configuration profiles | Devices → open device → Configuration profiles | All profiles show `Succeeded` |
| Compliance | Devices → open device → Compliance policies | `Compliant` |

**Device-side verification:**
```cmd
dsregcmd /status
```
Expected:
- `AzureAdJoined : YES`
- `MDMUrl : https://enrollment.manage.microsoft.com`

*Expected result:* All checks pass. Record results in the incident ticket.

---

## 6. Verification

> Do not close the incident until every step in this section passes.

**Step V1.** Confirm no legacy MDM record remains in Intune for the device.

**Portal path:** `intune.microsoft.com` > **Devices** > **All devices** > search device name.

*Expected result:* Single record present, source = `Autopilot`, enrolment date = today.

---

**Step V2.** Confirm all configuration profiles applied successfully.

**Portal path:** `intune.microsoft.com` > **Devices** > **All devices** > open device > **Configuration profiles**

*Expected result:* All profiles (including `FinBridge-Win11-Security-Baseline`) show `Succeeded`.

---

**Step V3.** Confirm device is compliant.

**Portal path:** `intune.microsoft.com` > **Devices** > **All devices** > open device > **Compliance policies**

*Expected result:* Device shows `Compliant`.

---

**Step V4.** Confirm with the assigned user that they can sign in and use the device normally.

*Expected result:* User confirms successful sign-in and normal desktop experience. Record confirmation in the ticket.

---

**Step V5.** Record the following in the incident notes and mark the incident resolved:
- Legacy MDM record deleted: confirmed
- Autopilot profile assigned and device registered: confirmed
- Final enrolment source: `Autopilot`
- All profiles applied: `Succeeded`
- Compliance state: `Compliant`
- User confirmation: received
- Timestamp of resolution

---

## 7. Rollback

Use this section if the wipe completes but Autopilot OOBE fails again with `0x80180014` or a new error code, or if the device cannot be wiped remotely.

---

**Step RB1.** If Autopilot OOBE fails again after the wipe with `0x80180014` — check whether a new legacy record has appeared in Intune.

**Portal path:** `intune.microsoft.com` > **Devices** > **All devices** > search device name.

| Finding | Action |
|---|---|
| A new legacy record has appeared | Delete it again and wait 10 minutes before retrying OOBE |
| No legacy record present | A different failure class — run a fresh MDM diagnostic export and escalate with the new error code |

---

**Step RB2.** If the device cannot be wiped remotely (device offline or wipe command not received):

1. Arrange physical access to the device.
2. On the device: **Settings** > **System** > **Recovery** > **Reset this PC** > **Remove everything**.
3. Allow the reset to complete before triggering OOBE.

---

**Step RB3.** If OOBE fails with a different error code after the legacy record has been removed:

Run the MDM diagnostic export again:
```
mdmdiagnosticstool.exe -area Autopilot -cab C:\Temp\MDMDiag2.cab
```

Record the new error code and escalate to the Intune Administrator with:
- Original incident ticket reference
- New error code and description from the export
- Confirmation that the legacy record was deleted (timestamp)
- Confirmation device was wiped (timestamp)
- Screenshot of the current device record in Intune

---

## 8. Preventive Actions

The following controls prevent this failure from recurring across the migration programme.

---

### PA-1 — Pre-Migration Estate Audit
**Owner: Intune Administrator | Priority: High | Due: Before next migration batch**

Export all devices from Intune filtered by `Enrolment source = Manual` AND `Enrolment date < [Autopilot programme start date]`. Cross-reference against the migration queue. For every matched device, schedule a maintenance window — delete the legacy record and wipe before Autopilot is triggered.

**Pass criteria:** Every device in the next migration batch has been checked and any legacy records are removed before the batch starts.

---

### PA-2 — Mandatory Gate 0 Pre-Flight Check in Migration Runbook
**Owner: Migration Programme Lead | Priority: High | Due: Before next migration batch**

Insert as a mandatory check before any Autopilot trigger in the migration runbook:

> In Intune: Devices → All devices → search device name.  
> Enrolment source must be blank or Autopilot — not Manual or Legacy.  
> If a legacy record exists: delete the record, wipe the device, then proceed.

**Pass criteria:** Every technician confirms in the migration ticket that the Gate 0 check was completed and the result before triggering Autopilot.

---

### PA-3 — Dynamic Azure AD Group for Legacy-Enrolled Devices
**Owner: Intune Administrator | Priority: Medium | Due: Within 5 working days**

Create a dynamic device group:
- **Rule:** `(device.enrollmentProfileName -eq "") and (device.managementType -eq "MDM")`
- Assign a compliance policy to this group flagging devices as non-compliant pending review.
- Use the group membership report as a standing pre-migration filter for all future batches.

---

### PA-4 — Post-Migration Enrolment Source Validation
**Owner: Migration Programme Lead | Priority: Medium | Due: Embed in programme closure checklist**

After each migration batch, export the Intune device list and verify every migrated device shows enrolment source = `Autopilot` and enrolment date = migration date. Any device showing Manual/Legacy source after migration requires rework before the batch is closed.

---

### PA-5 — Knowledge Article for Service Desk
**Owner: Service Desk Lead | Priority: Low | Due: Within 10 working days**

Publish an internal L1 knowledge article (KB-L1-AUTOPILOT-ENROL-001) covering:
- Symptom: Autopilot fails with `0x80180014`
- Cause: pre-existing MDM enrolment record
- Immediate triage: check Intune for duplicate device records
- Escalation path: Intune Administrator to delete legacy record and arrange wipe

---

## 9. Related Incidents and KB Articles

| Reference | Type | Summary |
|---|---|---|
| INC-FINBRIDGE-20240315-001 | Incident | Source incident — Autopilot enrolment failure on DESKTOP-FB099 (FINBRIDGE\rthomas) |
| RCA-FULL-AUTOPILOT-FAILURE-DESKTOP-FB099-2024-03-15 | RCA Document | Full root cause analysis — Five Whys, evidence chain, corrective actions |
| KB-L1-AUTOPILOT-ENROL-001 | L1 KB Article | L1 service desk triage and escalation guide for this failure pattern |
| KNOWN-ERROR-AUTOPILOT-FAILURE-DESKTOP-FB099-2024-03-15 | Known Error Record | Known error record — symptom, cause, workaround, permanent fix, and detection signals |
| CLOSURE-NOTE-AUTOPILOT-FAILURE-DESKTOP-FB099-2024-03-15 | Closure Note | Incident closure summary |
| Microsoft error `0x80180014` | Reference | MDM enrolment blocked: device already enrolled |
| Microsoft error `0x80070005` | Reference | Windows Access Denied (HRESULT E_ACCESSDENIED) |
| aka.ms/autopilottroubleshoot | Microsoft Docs | Autopilot troubleshooting guide |
| aka.ms/intuneretire | Microsoft Docs | Retire, wipe, delete devices in Intune |

---

*KB Article prepared by DWP Engineer | Derived from RCA INC-FINBRIDGE-20240315-001 | v1.0 | 11/08/2026 | Status: Draft*
