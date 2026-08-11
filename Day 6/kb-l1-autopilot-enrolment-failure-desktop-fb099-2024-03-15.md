# L1 KB Article — Autopilot Enrolment Failure (Device Already Enrolled in MDM)

| Field | Value |
|---|---|
| **KB Reference** | KB-L1-AUTOPILOT-ENROL-001 |
| **Version** | v1.0 |
| **Date** | 11/08/2026 |
| **Status** | Draft |
| **Audience** | L1 Service Desk Engineers |
| **Incident Reference** | INC-FINBRIDGE-20240315-001 |
| **Escalation Target** | L2 Endpoint Engineering / Intune Administrator |
| **Applies To** | Any device failing to complete Autopilot enrolment during the FinBridge migration programme |

---

## 1. What Is This Issue?

During the FinBridge migration programme, devices are being moved to Windows Autopilot. When Autopilot is triggered on a device that still has an old MDM enrolment record from a previous IT management system, the enrolment is immediately rejected. The device cannot set itself up, zero configuration policies are applied, and the user cannot use the device as a managed desktop.

**This is a known failure pattern.** The error code associated with this failure is `0x80180014` — "The device is already enrolled in MDM." If the symptoms below match what is being reported, follow this article in order.

---

## 2. Is This the Right Article?

Before starting, confirm **all three** of the following match the report:

| # | Check | Expected |
|---|---|---|
| 1 | Is the device being migrated as part of the **FinBridge Autopilot migration programme**? | Yes |
| 2 | Did the device **fail to complete Autopilot setup** — stuck at OOBE, error screen, or device is unmanaged after setup? | Yes |
| 3 | Does the device have a **previous IT management history** (i.e., it was not brand new out of the box)? | Yes — e.g. previously used device being re-provisioned |

If all three match — continue with this article.  
If any do not match — this article may not apply. Raise a general Autopilot fault ticket and escalate with as much detail as possible.

---

## 3. Initial Questions — Ask the User or Reporting Technician

Collect the following before doing anything else. Record every answer in the ticket.

| # | Question to Ask | Why You Need It |
|---|---|---|
| 1 | What is the device name? (e.g. `DESKTOP-FB099`) | Required to look up the device record in Intune |
| 2 | What is the assigned user's full name and username? (e.g. `FINBRIDGE\rthomas`) | Confirms who the device is assigned to |
| 3 | At what point did the failure occur — during OOBE setup, after sign-in, or when checking Intune? | Helps identify how far into the Autopilot flow it got before failing |
| 4 | Was the device wiped before Autopilot was triggered? | A device not wiped beforehand is the most common cause of this failure |
| 5 | Was this device previously managed by IT before this migration? | Confirms whether a legacy MDM record may exist |
| 6 | Is the user able to use the device at all, or is it completely unusable? | Determines urgency and whether a temporary workaround is needed |
| 7 | Has the Autopilot enrolment been attempted more than once? | Repeated attempts on the same device will keep failing until the root cause is resolved |

> **Key signal:** If the device was NOT wiped before Autopilot was triggered, and it was previously managed by IT, this is almost certainly the known `0x80180014` failure. Escalate to L2 immediately after collecting all information.

---

## 4. Triage Checks — What to Do Next

Work through these steps in order. Record what you find in the ticket at each step.

---

### Check 1 — Look Up the Device in Intune Admin Center

> You need read access to **Microsoft Intune Admin Center** (intune.microsoft.com). If you do not have this access, **skip to Section 5** and note in the ticket that Intune access was not available.

1. Sign in to [intune.microsoft.com](https://intune.microsoft.com).
2. Go to **Devices → All devices**.
3. Search for the device name (e.g. `DESKTOP-FB099`).

**What to look for:**

| Finding | What It Means |
|---|---|
| **Two records** exist for the same device name | A legacy MDM record and an Autopilot record both exist — this is the known failure. Note both enrolment dates and sources. |
| **One record** exists with enrolment source **Manual** or **Legacy** | A legacy record was never removed before Autopilot was triggered. This is the failure. |
| **One record** exists with enrolment source **Autopilot** and status **Failed** | Autopilot was attempted but failed. Note the error code shown if visible. |
| **No record** found | The device may not have been registered for Autopilot. Note this and escalate. |

**Record in the ticket:**
- How many device records were found for this device name?
- Enrolment date and source of each record found.

---

### Check 2 — Check the Autopilot Device Registration

1. In Intune Admin Center, go to **Devices → Enrolment → Windows → Autopilot devices**.
2. Search for the device serial number or name.

| Finding | What It Means |
|---|---|
| Device serial is listed and assigned to `FinBridge-Autopilot-Standard` profile | Autopilot registration is in place — the failure is the legacy MDM record |
| Device serial is **not listed** | The device was never registered for Autopilot — different issue, escalate separately |

**Record in the ticket:** Is the device registered in the Autopilot devices list? Yes / No.

---

### Check 3 — Check If the User Is Currently Unable to Work

Ask: *"Can you use the device at all, or are you completely blocked?"*

| Result | Action |
|---|---|
| User is completely blocked — device unusable | Apply the workaround in Section 5 if possible, then escalate as High priority |
| User can use another device in the meantime | Escalate as Medium priority — user is not fully blocked |

---

## 5. Temporary Workaround — L1 Scope

> **There is no end-user workaround for this failure** — the device cannot be used until the legacy MDM record is removed and Autopilot is re-run. L1 cannot perform this fix (see Section 6).

**What L1 can do:**

- If the user needs a device immediately, ask their line manager or IT coordinator whether a temporary loan device is available.
- Advise the user **not** to attempt to re-run Autopilot setup on the same device — repeated attempts without resolving the root cause will continue to fail and may make diagnosis harder for L2.
- Inform the user: *"Your device needs a specific fix by our engineering team. We are escalating this now as a priority. You will be contacted once the device is ready."*

---

## 6. What L1 Cannot Do — Escalation Boundary

The permanent fix for this issue requires access and permissions that are **outside L1 scope**:

| Action Required | Why L1 Cannot Do It |
|---|---|
| Delete the legacy MDM enrolment record from Intune | Requires Intune RBAC role: **Intune Administrator** or **Help Desk Operator (full)** — L1 does not hold this role |
| Wipe the device remotely from Intune | Requires **Remote tasks — Wipe** permission in Intune — L1 does not hold this |
| Re-run Autopilot OOBE on device | Requires physical or remote KVM access to the device plus Intune admin confirmation |
| Verify Autopilot profile assignment | Requires Intune read access — escalate if not available to L1 |

**If any of the above is needed to resolve the issue permanently — escalate to L2 Endpoint Engineering / Intune Administrator.**

---

## 7. Mandatory Information to Collect Before Escalating

Do not escalate until all of the following has been recorded in the ticket. L2 engineers cannot work without this information.

### 7.1 — Affected Device and User

| Field | Value (fill in) |
|---|---|
| Device name | |
| Assigned user (username and full name) | |
| OS build (if visible at OOBE or in Intune) | |
| Was the device wiped before Autopilot was triggered? | Yes / No / Unknown |
| Was the device previously managed by IT before this migration? | Yes / No / Unknown |

### 7.2 — Incident Timeline

| Field | Value (fill in) |
|---|---|
| When did the failure occur? | Date and time |
| How many Autopilot attempts have been made? | Number |
| Was the device part of the current migration batch? | Yes / No |

### 7.3 — Intune Device Records (if access was available)

| Field | Value (fill in) |
|---|---|
| Number of device records found in Intune for this device name | |
| Enrolment date(s) and source(s) of each record | |
| Is the device registered in Autopilot devices list? | Yes / No / Not checked |
| Autopilot profile shown (if listed) | |

### 7.4 — User Impact

| Field | Value (fill in) |
|---|---|
| Is the user completely blocked? | Yes / No |
| Has a temporary loan device been arranged? | Yes / No / Not needed |
| Has the user been advised not to reattempt Autopilot setup? | Yes / No |

### 7.5 — Steps Already Taken by L1

List every action taken, in order, with the result. Example format:

> - Searched Intune for DESKTOP-FB099 — found two records: one with enrolment date 2023-11-04 source Legacy, one showing Autopilot Failed.
> - Confirmed device is registered in Autopilot devices list with FinBridge-Autopilot-Standard profile.
> - Advised user not to reattempt Autopilot. User is using a loan device in the meantime.
> - Intune wipe/delete access not available at L1 — escalating to L2.

---

## 8. Escalation — How to Hand Over to L2

### When to Escalate

Escalate to L2 Endpoint Engineering / Intune Administrator if **any** of the following are true:

| Condition | Action |
|---|---|
| Device has a legacy MDM enrolment record in Intune (source: Manual or Legacy) | Escalate immediately — this is the known `0x80180014` failure |
| Device was not wiped before Autopilot was triggered | Escalate — wipe and re-enrolment required |
| Multiple devices in the same migration batch are failing with the same pattern | Escalate as High — programme-wide risk |
| Autopilot has been attempted more than once and keeps failing | Escalate — repeated attempts will not resolve without root cause fix |
| You cannot access Intune to check device records | Escalate with all other information collected |

### Escalation Priority

| Situation | Priority |
|---|---|
| Multiple devices failing across the migration batch | **High** — programme impact |
| Single device, user completely blocked with no loan device | **High** |
| Single device, user has a temporary loan device | **Medium** |

### What to Include in the Escalation Ticket

Copy the following into the escalation ticket body — fill in every field:

```
ESCALATION — Autopilot Enrolment Failure (0x80180014 / Legacy MDM Record)
==========================================================================
Ticket Reference: [your ticket number]
Escalating Engineer: [your name]
Escalation Time: [date and time]

AFFECTED DEVICE AND USER:
- Device name:
- Assigned user:
- OS build (if known):
- Device wiped before Autopilot triggered: Yes / No / Unknown
- Device previously MDM managed: Yes / No / Unknown

INCIDENT TIMELINE:
- Failure occurred:
- Number of Autopilot attempts made:
- Part of current migration batch: Yes / No

INTUNE CHECKS:
- Legacy MDM record found in Intune: Yes / No / Not checked
- Enrolment date(s) and source(s) of records found:
- Device registered in Autopilot devices list: Yes / No / Not checked
- Autopilot profile (if shown):

USER IMPACT:
- User completely blocked: Yes / No
- Loan device arranged: Yes / No

STEPS TAKEN BY L1:
1.
2.
3.

REASON FOR ESCALATION:
[State clearly: legacy MDM record found / wipe required / no Intune access / programme-wide risk]

L2 KB REFERENCE: KB-L2-L3-AUTOPILOT-ENROL-001
RCA REFERENCE: INC-FINBRIDGE-20240315-001
```

---

## 9. Related Articles and References

| Reference | What It Is |
|---|---|
| KB-L2-L3-AUTOPILOT-ENROL-001 | Full technical KB article for L2/L3 engineers — detection, resolution, rollback, and preventive actions |
| INC-FINBRIDGE-20240315-001 | Source incident — Autopilot enrolment failure on DESKTOP-FB099 (FINBRIDGE\rthomas) |
| RCA-FULL-AUTOPILOT-FAILURE-DESKTOP-FB099-2024-03-15 | Full root cause analysis — Five Whys, evidence, corrective actions |
| Known Error — Autopilot Enrolment Failure | Known error record for this failure pattern |
| Microsoft Docs — Autopilot troubleshooting | aka.ms/autopilottroubleshoot |

---

*L1 KB Article prepared by DWP Engineer | Derived from RCA INC-FINBRIDGE-20240315-001 | v1.0 | 11/08/2026 | Status: Draft*
