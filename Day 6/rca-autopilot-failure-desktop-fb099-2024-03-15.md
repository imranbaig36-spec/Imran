# RCA & Remediation — Autopilot Enrolment Failure
**Device:** DESKTOP-FB099
**User:** FINBRIDGE\rthomas
**Date of incident:** 2024-03-15 09:18
**OS build:** Windows 11 22621.2861
**Analyst:** AI-assisted analysis — DWP Day 6 exercise

---

## 1. Scope Facts (from MDM diagnostic export)

- **Enrolment result:** Failed — error `0x80180014` ("The device is already enrolled in MDM")
- **Existing MDM enrolment:** Yes — legacy manual enrolment recorded from 2023-11-04
- **Azure AD joined:** Yes
- **Policy application:** Failed — 0 of 4 profiles applied; last error `0x80070005` (Access denied); failing profile: `FinBridge-Win11-Security-Baseline`
- **Compliance evaluation:** Could not evaluate — blocked by incomplete enrolment
- **Licensing:** Correct — M365, Intune P1, and Autopilot licences all present
- **Network connectivity:** Healthy — all required endpoints reachable, no proxy detected

---

## 2. Root Cause

**Stale legacy MDM enrolment blocking Autopilot.**

Error code `0x80180014` is the Microsoft-documented MDM error meaning *"device is already enrolled in MDM"*. The device carries an active manual MDM enrolment from 2023-11-04 that was never retired or removed. Autopilot cannot claim MDM authority over a device already under management — the enrolment flow halts immediately.

The secondary error `0x80070005` (Access Denied) on policy push is a direct downstream consequence: the legacy enrolment holds management authority locks that the new Autopilot session cannot override, resulting in zero of four configuration profiles being applied.

The device was provisioned manually in 2023 and was never wiped or reprovisioned before Autopilot was triggered — Autopilot requires a clean OOBE state.

---

## 3. Ranked Hypotheses (considered during scoping)

| # | Hypothesis | Fit | Status |
|---|-----------|-----|--------|
| 1 | Stale legacy MDM enrolment (0x80180014) | Direct error code match, confirmed by export | **Confirmed — root cause** |
| 2 | Management authority conflict causing Access Denied (0x80070005) | Consistent with legacy lock blocking policy push | Downstream effect of #1 |
| 3 | Device not reset to OOBE before Autopilot triggered | Explains why legacy enrolment still present | Contributing procedural cause |

---

## 4. Remediation Steps

### Step 1 — Remove the stale MDM enrolment record
**Access required: Intune Admin Center only**

1. Sign in to [intune.microsoft.com](https://intune.microsoft.com)
2. Navigate to **Devices → All devices**
3. Search for `DESKTOP-FB099`
4. Open the legacy record (enrolment date 2023-11-04, source: Manual)
5. Select **Delete** to remove the management record and release the MDM authority lock
6. Confirm deletion when prompted
7. Wait 5–10 minutes for the record to fully clear from the portal

---

### Step 2 — Verify Autopilot profile assignment
**Access required: Intune Admin Center only**

1. Navigate to **Devices → Enrolment → Windows → Autopilot deployment profiles**
2. Confirm `FinBridge-Autopilot-Standard` is assigned to a group containing `DESKTOP-FB099` or `rthomas`
3. Navigate to **Devices → Enrolment → Windows → Autopilot devices**
4. Confirm the device serial number is registered in the Autopilot device list

---

### Step 3 — Wipe the device
**Access required: Intune Admin Center (triggers device-side action remotely)**
> Physical access required only if device is offline or powered off.

1. In **Devices → All devices**, open the remaining record for `DESKTOP-FB099`
2. Select **Wipe**
3. Leave **"Wipe device, but keep enrolment state and associated user account"** **unchecked** — a fully clean OOBE state is required
4. Confirm the wipe
5. The device will restart and begin wiping automatically if powered on and network-connected

---

### Step 4 — Allow Autopilot to run from OOBE
**Access required: Device-side (physical or remote KVM)**

1. At the OOBE screen, confirm the Autopilot profile `FinBridge-Autopilot-Standard` loads automatically
2. Sign in as `rthomas` (or the assigned user) when prompted
3. Allow the provisioning flow to complete without interruption

---

## 5. Verification Checks

### Admin Center (no device access needed)
- **Devices → All devices:** `DESKTOP-FB099` appears with enrolment source `Autopilot` and today's enrolment date
- **Devices → Monitor → Autopilot deployments:** record shows `Enrolled` with no error
- **Devices → Configuration profiles:** all 4 profiles (including `FinBridge-Win11-Security-Baseline`) show status `Succeeded`
- **Devices → Compliance policies:** device shows `Compliant`

### Device-side (physical or remote)
Run the following and confirm output:
```
dsregcmd /status
```
Expected values:
- `AzureAdJoined : YES`
- `MDMUrl : https://enrollment.manage.microsoft.com`
- `EnrollmentType : Autopilot`

---

## 6. Preventive Actions

### Immediate — identify other at-risk devices
**Access required: Intune Admin Center only**

1. Navigate to **Devices → All devices → Export**
2. Filter the export: `Enrolment source = Manual` and `Enrolment date < [Autopilot rollout start date]`
3. Use the resulting list to schedule pre-migration cleanup for each affected device (delete legacy record + wipe) before Autopilot is triggered

### Process control — pre-migration checklist
Add a mandatory verification step to the Autopilot migration runbook:

> *Before triggering Autopilot on any device, confirm no existing MDM enrolment record exists in Intune.*
> Check: **Devices → All devices → search device name → enrolment source must be blank or Autopilot, not Manual/Legacy.**

If a legacy record exists, retire and delete it, then wipe the device before proceeding.

### Structural guard — dynamic device group
Create an Azure AD dynamic device group to surface devices needing review:

- **Rule:** `(device.enrollmentProfileName -eq "") and (device.managementType -eq "MDM")`
- Use this group in a compliance policy or named report to flag legacy-enrolled devices before they enter the Autopilot migration queue

---

## 7. Timeline

| Time | Event |
|------|-------|
| 2023-11-04 | DESKTOP-FB099 manually enrolled in MDM (legacy) |
| 2024-03-15 09:18 | Autopilot enrolment attempted — fails immediately with `0x80180014` |
| 2024-03-15 09:19 | Policy manager attempts profile push — fails with `0x80070005` on all 4 profiles |
| 2024-03-15 09:19 | Compliance engine cannot evaluate — enrolment not complete |

---

## 8. References

- Microsoft error `0x80180014` — MDM enrolment blocked: device already enrolled
- Microsoft error `0x80070005` — Windows Access Denied (HRESULT)
- Intune Autopilot troubleshooting: [aka.ms/autopilottroubleshoot](https://aka.ms/autopilottroubleshoot)
