# Root Cause Analysis — Autopilot Enrolment Failure
## DESKTOP-FB099 | FINBRIDGE\rthomas | 2024-03-15

---

| Field | Detail |
|-------|--------|
| **Incident reference** | INC-FINBRIDGE-20240315-001 |
| **Device** | DESKTOP-FB099 |
| **Assigned user** | FINBRIDGE\rthomas |
| **Date / time of failure** | 2024-03-15 09:18:44 |
| **OS build** | Windows 11 22621.2861 |
| **Autopilot profile** | FinBridge-Autopilot-Standard |
| **Severity** | High — device unmanaged, zero policy applied, compliance unknown |
| **Status** | Resolved (remediation steps confirmed) |
| **Document author** | AI-assisted analysis — DWP Day 6 exercise |
| **Document date** | 2024-03-15 |

---

## 1. Executive Summary

During a planned Autopilot migration for the FinBridge programme, device DESKTOP-FB099 failed to enrol. The Autopilot flow was triggered against a device that still carried an active legacy manual MDM enrolment from November 2023. Microsoft's MDM stack does not permit a second enrolment over an existing one — the enrolment was immediately rejected with error `0x80180014`. As a result, zero of four mandatory security and configuration profiles were applied, the device remained in an unknown compliance state, and the user was unable to receive the managed desktop experience.

The root cause is a process gap: no pre-migration check was in place to verify and remove existing MDM enrolment records before Autopilot was triggered. This is a repeatable risk for any device in the estate that was previously managed via legacy manual MDM.

---

## 2. Supporting Evidence

### 2.1 MDM Diagnostic Export — raw data

```
=== MDM Diagnostic Export ===
Device     : DESKTOP-FB099
User       : FINBRIDGE\rthomas
Date       : 2024-03-15 09:22
OS build   : 22621.2861

--- EnrollmentStatus ---
EnrollmentType    : Autopilot
EnrollmentState   : Failed
ErrorCode         : 0x80180014
ErrorDescription  : The device is already enrolled in MDM.
Timestamp         : 2024-03-15 09:18:44

--- PolicyManager ---
ProfilesAttempted : 4
ProfilesApplied   : 0
LastError         : 0x80070005 (Access denied)
FailedProfile     : FinBridge-Win11-Security-Baseline
Timestamp         : 2024-03-15 09:19:01

--- ComplianceEngine ---
EvaluationResult  : Could not evaluate
Reason            : Enrolment not complete
Timestamp         : 2024-03-15 09:19:45

--- DeviceInfo ---
AzureADJoined     : Yes
MDMEnrolled       : Yes (previous enrolment)
EnrolmentSource   : Legacy (manual MDM enrolment, 2023-11-04)
AutopilotProfile  : FinBridge-Autopilot-Standard
TPMVersion        : 2.0
TPMStatus         : Ready
SecureBoot        : Enabled

--- NetworkCheck ---
EndpointReach     : login.microsoftonline.com          : OK
EndpointReach     : enrollment.manage.microsoft.com    : OK
EndpointReach     : enterpriseregistration.windows.net : OK
ProxyDetected     : No

--- Licensing ---
M365LicenseFound  : Yes
IntuneP1License   : Yes
AutopilotLicense  : Yes
```

### 2.2 Scope facts extracted from export

| Fact | Value |
|------|-------|
| Enrolment result | **Failed** |
| Primary error code | `0x80180014` — device already enrolled in MDM |
| Secondary error code | `0x80070005` — Access Denied (policy push) |
| Existing MDM enrolment | **Yes** — legacy manual, 2023-11-04 |
| Azure AD joined | Yes |
| Profiles applied | 0 of 4 |
| Failing profile | FinBridge-Win11-Security-Baseline |
| Compliance state | Could not evaluate |
| Licensing | All licences present and correct |
| Network | All endpoints reachable, no proxy |
| TPM | Version 2.0, Ready |
| Secure Boot | Enabled |

### 2.3 Error code reference

| Code | Meaning | Source |
|------|---------|--------|
| `0x80180014` | MDM enrolment blocked — device already enrolled | Microsoft documented MDM error |
| `0x80070005` | Access Denied | Standard Windows HRESULT — system could not write policy under existing authority |

### 2.4 What the evidence rules out

| Factor | Evidence | Conclusion |
|--------|----------|------------|
| Licensing problem | M365, Intune P1, Autopilot licences all confirmed present | Eliminated |
| Network / proxy block | All four Microsoft endpoints reachable, no proxy | Eliminated |
| TPM or Secure Boot fault | TPM 2.0 Ready, Secure Boot Enabled | Eliminated |
| Azure AD join failure | AzureADJoined: Yes | Eliminated |
| Autopilot profile missing | FinBridge-Autopilot-Standard present and associated | Eliminated |

All infrastructure prerequisites were met. The sole blocking condition was the pre-existing MDM enrolment.

---

## 3. Incident Timeline

```
2023-11-04          Device DESKTOP-FB099 provisioned via legacy manual MDM enrolment.
                    No record of decommission or retirement of this enrolment.

2024-03-15 09:18    Technician triggers Autopilot enrolment on DESKTOP-FB099 as part of
                    FinBridge programme migration. Device is NOT wiped beforehand.

2024-03-15 09:18:44 Autopilot enrolment flow contacts Microsoft MDM service.
                    MDM service detects existing active enrolment.
                    Enrolment rejected: ErrorCode 0x80180014.
                    EnrolmentState set to: Failed.

2024-03-15 09:19:01 PolicyManager attempts to push 4 configuration profiles regardless.
                    Legacy enrolment holds management authority lock.
                    All 4 profile pushes fail: 0x80070005 (Access Denied).
                    FailedProfile logged: FinBridge-Win11-Security-Baseline.

2024-03-15 09:19:45 ComplianceEngine attempts evaluation.
                    Enrolment not complete — evaluation aborted.
                    EvaluationResult: Could not evaluate.

2024-03-15 09:22    MDM diagnostic export captured. Incident identified and escalated.
```

---

## 4. Five Whys Analysis

The Five Whys is applied to the direct failure: *Autopilot enrolment failed on DESKTOP-FB099.*

---

**Why 1 — Why did Autopilot enrolment fail?**

Because the MDM service detected an existing active enrolment on the device and rejected the new Autopilot enrolment with error `0x80180014`. A device cannot hold two concurrent MDM enrolments.

---

**Why 2 — Why was there an existing active MDM enrolment on the device?**

Because the device was manually enrolled in MDM on 2023-11-04 and that enrolment was never retired, deleted, or offboarded from Intune before the Autopilot migration was attempted. The legacy record remained active in both Intune and on the device.

---

**Why 3 — Why was the legacy enrolment never removed before migration?**

Because there was no pre-migration checklist step requiring technicians to verify and clear existing MDM enrolment records before triggering Autopilot. The Autopilot migration runbook did not include this check. The technician proceeded directly to triggering Autopilot on the live, previously-enrolled OS.

---

**Why 4 — Why did the migration runbook not include this check?**

Because the runbook was written for devices that were assumed to be either new/unboxed or previously unenrolled. Legacy manually-enrolled devices were not identified as a distinct device class requiring different handling during the migration planning phase. No audit of existing enrolment states was performed before the migration programme began.

---

**Why 5 — Why were legacy-enrolled devices not identified as a distinct class requiring different handling?**

Because no pre-migration device estate audit was conducted to categorise devices by enrolment source and age. Devices enrolled via legacy manual MDM (pre-Autopilot programme) were mixed into the same migration queue as clean devices without differentiation. The absence of a baseline estate report meant the scope of legacy enrolments across the fleet was unknown.

---

**Root cause statement:**

> The migration programme launched without a pre-migration audit to identify devices carrying legacy MDM enrolments. The absence of this audit meant the runbook contained no step to remove stale enrolment records, leading directly to Autopilot being triggered on an actively-enrolled device and the enrolment being rejected.

---

## 5. Impact Assessment

| Area | Impact |
|------|--------|
| User experience | rthomas unable to receive managed desktop at device setup |
| Security posture | Zero security baseline policies applied — device unmanaged |
| Compliance | Compliance state unknown — device not evaluable in Intune |
| Migration programme | One device requiring rework; risk of recurrence for all legacy-enrolled devices in queue |
| Blast radius | Unknown until estate audit completed — all devices with legacy enrolment dates pre-dating Autopilot rollout are at risk |

---

## 6. Remediation

### Order of operations

| Step | Action | Access required |
|------|--------|----------------|
| 1 | Delete legacy MDM enrolment record from Intune | Admin Center only |
| 2 | Verify Autopilot profile assignment | Admin Center only |
| 3 | Wipe device | Admin Center (remote) — physical if device offline |
| 4 | Complete Autopilot OOBE | Device-side (physical or remote KVM) |
| 5 | Verify enrolment and policy compliance | Admin Center + device-side |

### Step 1 — Delete the legacy MDM enrolment record
**Admin Center only**

1. Sign in to [intune.microsoft.com](https://intune.microsoft.com)
2. Navigate to **Devices → All devices**
3. Search `DESKTOP-FB099`
4. Open the record with enrolment date 2023-11-04 and source Manual/Legacy
5. Select **Delete** → confirm
6. Wait 5–10 minutes for the record to clear fully

### Step 2 — Verify Autopilot profile assignment
**Admin Center only**

1. **Devices → Enrolment → Windows → Autopilot deployment profiles**
2. Confirm `FinBridge-Autopilot-Standard` is assigned to a group containing `DESKTOP-FB099` or `rthomas`
3. **Devices → Enrolment → Windows → Autopilot devices** — confirm the device serial is registered

### Step 3 — Wipe the device
**Admin Center (triggers device-side action remotely)**
> Physical access required only if device is offline or powered off.

1. **Devices → All devices** → open `DESKTOP-FB099`
2. Select **Wipe**
3. Leave **"Wipe device, but keep enrolment state and associated user account"** **unchecked** — clean OOBE state required
4. Confirm the wipe

### Step 4 — Complete Autopilot OOBE
**Device-side — physical or remote KVM required**

1. At the OOBE screen confirm `FinBridge-Autopilot-Standard` profile loads automatically
2. Sign in as `rthomas` when prompted
3. Allow provisioning to complete without interruption — do not close the provisioning screen

### Step 5 — Verification
**Admin Center**
- **Devices → All devices:** `DESKTOP-FB099` — enrolment source = Autopilot, enrolment date = today
- **Devices → Monitor → Autopilot deployments:** status = `Enrolled`, no error
- **Devices → Configuration profiles:** all 4 profiles show `Succeeded`
- **Devices → Compliance policies:** device shows `Compliant`

**Device-side**
```
dsregcmd /status
```
Expected:
- `AzureAdJoined : YES`
- `MDMUrl : https://enrollment.manage.microsoft.com`

---

## 7. Preventive Actions

### PA-1 — Pre-migration estate audit (immediate)
**Owner: Intune Administrator | Priority: High | Due: Before next migration batch**

1. **Devices → All devices → Export**
2. Filter: `Enrolment source = Manual` AND `Enrolment date < [Autopilot programme start date]`
3. Cross-reference against the migration queue
4. For every matched device: schedule a maintenance window — delete legacy record and wipe before Autopilot is triggered

---

### PA-2 — Update Autopilot migration runbook (immediate)
**Owner: Migration Programme Lead | Priority: High | Due: Before next migration batch**

Insert as a mandatory Gate 0 check before any Autopilot trigger:

> **Pre-flight check — existing MDM enrolment**
> In Intune: Devices → All devices → search device name.
> Enrolment source must be blank or Autopilot — not Manual or Legacy.
> If a legacy record exists: delete the record, wipe the device, then proceed.

---

### PA-3 — Dynamic Azure AD group to surface legacy-enrolled devices
**Owner: Intune Administrator | Priority: Medium | Due: Within 5 working days**

Create a dynamic device group:
- **Rule:** `(device.enrollmentProfileName -eq "") and (device.managementType -eq "MDM")`
- Assign a compliance policy to this group flagging devices as non-compliant pending review
- Use the group membership report as a standing pre-migration filter

---

### PA-4 — Post-migration enrolment source validation (process)
**Owner: Migration Programme Lead | Priority: Medium | Due: Embed in programme closure checklist**

After each migration batch, export the Intune device list and verify every migrated device shows:
- `Enrolment source = Autopilot`
- `Enrolment date = migration date`

Any device showing Manual/Legacy source after migration is an incomplete migration requiring rework.

---

### PA-5 — Knowledge article for service desk (awareness)
**Owner: Service Desk Lead | Priority: Low | Due: Within 10 working days**

Publish an internal knowledge article describing:
- Symptom: Autopilot fails with `0x80180014`
- Cause: pre-existing MDM enrolment
- Immediate triage: check Intune for duplicate device records
- Escalation path: Intune Administrator to delete legacy record and arrange wipe

---

## 8. Lessons Learned

| # | Lesson | Applies to |
|---|--------|-----------|
| 1 | Migration programmes must include a device estate audit phase before any device is touched | All future migration programmes |
| 2 | Autopilot is designed for clean OOBE — never trigger it on a running, previously-enrolled OS without a wipe | All Autopilot deployments |
| 3 | Error `0x80180014` is deterministic — if seen, the fix is always to remove the existing enrolment first | Service desk and migration engineers |
| 4 | Downstream errors (0x80070005 on policy push) caused by a failed enrolment are symptoms, not independent root causes — fix the enrolment first | All MDM troubleshooting |
| 5 | Compliance "could not evaluate" is not a compliance failure — it signals an incomplete enrolment and should trigger an enrolment investigation, not a compliance remediation | Compliance monitoring teams |

---

## 9. References

- Microsoft error `0x80180014` — MDM enrolment blocked: device already enrolled
- Microsoft error `0x80070005` — Windows Access Denied (HRESULT E_ACCESSDENIED)
- Microsoft Docs — Autopilot troubleshooting: [aka.ms/autopilottroubleshoot](https://aka.ms/autopilottroubleshoot)
- Microsoft Docs — Windows Autopilot requirements: [aka.ms/autopilotreqs](https://aka.ms/autopilotreqs)
- Microsoft Docs — Retire, wipe, delete devices in Intune: [aka.ms/intuneretire](https://aka.ms/intuneretire)
