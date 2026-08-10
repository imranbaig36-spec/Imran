# L1 KB Article — Finance Drive `S:` Missing at Sign-in

| Field | Value |
|---|---|
| **KB Reference** | KB-L1-DRIVE-MAP-FIN-001 |
| **Version** | v1.0 |
| **Date** | 10/08/2026 |
| **Status** | Draft |
| **Audience** | L1 Service Desk Engineers |
| **Incident Reference** | DRIVE-MAP-FIN-2024-03-15 |
| **Escalation Target** | L2 Endpoint Engineering |
| **Applies To** | Finance users on `DESKTOP-FB*` devices reporting drive `S:` missing after sign-in |

---

## 1. What Is This Issue?

Finance users have a shared network drive mapped as `S:` that should appear automatically every time they sign in. This drive points to `\\finbridge-fs01\Finance` and is used to access shared financial data.

When this issue occurs, `S:` does not appear in File Explorer after sign-in. The user cannot access their shared Finance files.

**This is a known failure pattern** linked to a specific configuration change. If the symptoms below match what the user is reporting, follow this article in order.

---

## 2. Is This the Right Article?

Before starting, confirm **all three** of the following match the report:

| # | Check | Expected |
|---|---|---|
| 1 | Is the affected user in the **Finance team**? | Yes — Finance users only |
| 2 | Is their device name starting with `DESKTOP-FB`? | Yes — e.g. `DESKTOP-FB01`, `DESKTOP-FB14` |
| 3 | Is drive `S:` specifically the missing drive? | Yes — not `T:`, `U:`, or any other letter |

If all three match — continue with this article.  
If any do not match — this article does not apply. Raise a general mapped drive fault ticket.

---

## 3. Initial Questions — Ask the User

Collect the following before doing anything else. Record every answer in the ticket.

| # | Question to Ask | Why You Need It |
|---|---|---|
| 1 | What is your full name and username? | Confirms identity and links to Active Directory account |
| 2 | What is your device name? (Start > right-click This PC > Properties > Device name) | Confirms it is a `DESKTOP-FB*` Finance device |
| 3 | When did you first notice `S:` was missing — today, or since a specific date/time? | Identifies the start of the incident window |
| 4 | Does `S:` appear for anyone else in your team, or is it missing for everyone? | Determines if it is a single-user issue or a team-wide outage |
| 5 | Have you signed out and signed back in since noticing the issue? | Rules out a one-off session glitch |
| 6 | Did anything change on your device recently — Windows update, any IT work done overnight? | Links the failure to a change window |
| 7 | Can you reach `\\finbridge-fs01\Finance` by typing it directly into the File Explorer address bar? | Confirms the file server is up and the issue is the drive letter only |

> **Key signal:** If the user says `\\finbridge-fs01\Finance` is accessible when typed directly, but `S:` is not mapped — this is a drive mapping assignment failure, not a file server outage.

---

## 4. Triage Checks — What to Do Next

Work through these steps in order. Record what you find in the ticket for each step.

---

### Check 1 — Confirm the Drive Is Truly Missing (Not Just Hidden)

Ask the user to open **File Explorer** and look under **This PC**.

- If `S:` is visible but shows a red X — the drive letter exists but cannot connect. This may be a different issue (network or permissions). Note it and continue.
- If `S:` is completely absent — this matches the known failure pattern. Continue.

---

### Check 2 — Confirm It Affects More Than One User

Ask: *"Can you check with one or two colleagues in Finance — is their `S:` drive also missing?"*

| Result | What It Means |
|---|---|
| Multiple Finance users affected | Team-wide or OU-wide failure — this article applies |
| Only this one user affected | May be a user-specific permission or profile issue — note it but still collect all information below before escalating |

---

### Check 3 — Check Event Viewer on the Affected Device

> You need to be able to remote into the device or guide the user through Event Viewer. If you do not have remote admin access, **skip to Section 5** and note in the ticket that log access was not available.

**How to open Event Viewer:**  
Start > search `Event Viewer` > open it > expand **Windows Logs** > click **System**

Look for the following event. Use **Filter Current Log** (right-hand panel) and enter Event ID `98`:

| Field | What to Look For |
|---|---|
| **Event ID** | `98` |
| **Source** | `Ntfs` |
| **Level** | Warning |
| **Message** | `File system could not map drive letter S: Drive letter has not been assigned.` |

**Record in the ticket:**
- Is Event `98` present? Yes / No
- If yes: what is the timestamp of the most recent Event `98`?

> If Event `98` is present — this confirms the drive letter was never assigned at sign-in. This matches the known failure pattern.

---

### Check 4 — Check If the File Server Is Reachable

Ask the user to open **File Explorer**, click in the address bar, type `\\finbridge-fs01\Finance` and press Enter.

| Result | Record in Ticket |
|---|---|
| Folder opens and shows files | File server is up — issue is the mapping only |
| Access denied | Possible permissions issue — note this |
| Path not found / cannot reach | File server may be down — raise separately |

---

## 5. Temporary Workaround — Apply If User Is in Active Production Hours

> **This workaround is within L1 scope.** It maps the drive for the current session only. It is a stop-gap — the drive will be missing again after the user next signs out and back in.

**Tell the user:**  
*"I can map the drive for you now so you can keep working. However, this will only last for your current session. When you sign out and sign back in, the drive will be missing again. Our engineering team will fix the underlying cause."*

**Steps to apply the workaround:**

1. Ask the user to open the **Start menu** and type `cmd`.
2. Right-click **Command Prompt** and select **Run as administrator**. Enter their admin password if prompted.
3. In the Command Prompt, type the following exactly and press Enter:

```
net use S: \\finbridge-fs01\Finance /persistent:no
```

4. Ask the user to open **File Explorer** and check if `S:` now appears under **This PC**.

| Expected result | What it means |
|---|---|
| `The command completed successfully.` and `S:` appears | Workaround applied — user can work now |
| `System error 5` (Access denied) | User does not have permissions to the share — this is a different issue, note it |
| `System error 53` (Network path not found) | File server is unreachable — raise a separate network/server fault |

**Record in the ticket:** whether the workaround succeeded or failed, and the exact error message if it failed.

---

## 6. What L1 Cannot Do — Escalation Boundary

The permanent fix for this issue requires access and permissions that are **outside L1 scope**:

| Action Required | Why L1 Cannot Do It |
|---|---|
| Disable the failing Intune script deployment | Requires Intune RBAC role: **Policy and Profile Manager** — L1 does not hold this role |
| Change the script execution context in Intune | Same elevated Intune role required |
| Add or modify a GPO logon script | Requires **Domain Admin** or **GPO Editor** delegation — L1 does not hold this |
| Modify Intune device group assignments | Requires elevated Intune access |

**If any of the above is needed to resolve the issue permanently — escalate to L2 Endpoint Engineering.**

---

## 7. Mandatory Information to Collect Before Escalating

Do not escalate until all of the following has been recorded in the ticket. L2 engineers cannot work without this information.

### 7.1 — Affected Users and Devices

| Field | Value (fill in) |
|---|---|
| Number of affected users | |
| Affected device names (list all known) | |
| All confirmed to be `DESKTOP-FB*` devices? | Yes / No |
| All confirmed to be Finance team members? | Yes / No |

### 7.2 — Incident Timeline

| Field | Value (fill in) |
|---|---|
| When did users first report the issue? | Date and time |
| Was there an overnight change window before the issue started? | Yes / No — if yes, note the date |
| Did the issue start after a specific event (Windows update, IT work, migration)? | Note any detail given |

### 7.3 — File Server Reachability

| Field | Value (fill in) |
|---|---|
| Can the user reach `\\finbridge-fs01\Finance` by typing the UNC path directly? | Yes / No |

### 7.4 — Event Viewer Findings (if access was available)

| Field | Value (fill in) |
|---|---|
| Was Event ID `98` (Ntfs) present in the System log? | Yes / No / Not checked (no access) |
| Timestamp of the most recent Event `98` | |
| Screenshot of Event `98` attached to ticket? | Yes / No |

### 7.5 — Workaround Outcome

| Field | Value (fill in) |
|---|---|
| Was the `net use` workaround attempted? | Yes / No |
| Did it succeed? | Yes / No |
| If no — exact error message returned | |
| User confirmed working after workaround? | Yes / No |

### 7.6 — Steps Already Taken by L1

List every action taken, in order, with the result. Example format:

> - Asked user to check `\\finbridge-fs01\Finance` directly — accessible, files visible.
> - Checked Event Viewer System log — Event `98` present, timestamp 08:14.
> - Applied `net use` workaround — succeeded, user confirmed `S:` visible.
> - Unable to check Intune deployment — no Policy and Profile Manager role.

---

## 8. Escalation — How to Hand Over to L2

### When to Escalate

Escalate to L2 Endpoint Engineering if **any** of the following are true:

| Condition | Action |
|---|---|
| More than one Finance user is affected | Escalate immediately — this is a team-wide outage |
| The `net use` workaround failed with no network error | Escalate — the drive mapping issue has a different root cause |
| Event `98` is confirmed in the System log | Escalate — confirmed technical failure requiring L2 investigation |
| The workaround succeeds but the user will lose `S:` again at next sign-in | Escalate — permanent fix is required |
| You are unsure of the cause after completing Sections 3 and 4 | Escalate with all information collected |

### Escalation Priority

| Situation | Priority |
|---|---|
| All Finance users affected simultaneously | **High** — Finance team cannot work |
| A subset of Finance users affected | **Medium** |
| Single user affected, workaround in place | **Low** |

### What to Include in the Escalation Ticket

Copy the following into the escalation ticket body — fill in every field:

```
ESCALATION — Finance Drive S: Missing
=======================================
Ticket Reference: [your ticket number]
Escalating Engineer: [your name]
Escalation Time: [date and time]

AFFECTED USERS:
- Number affected:
- Device names:

INCIDENT TIMELINE:
- First reported:
- Change window before issue:

USER CHECKS:
- UNC path \\finbridge-fs01\Finance accessible: Yes / No
- Event ID 98 in System log: Yes / No / Not checked
- Event 98 timestamp (if found):

WORKAROUND:
- net use workaround attempted: Yes / No
- Workaround result: Success / Failed (error: )
- User confirmed working: Yes / No

STEPS TAKEN BY L1:
1.
2.
3.

REASON FOR ESCALATION:
[State clearly: limited access / knowledge gap / permanent fix required]

L2 KB REFERENCE: KB-DRIVE-MAP-FIN-001 (L2/L3 article)
RUNBOOK REFERENCE: Runbook-DRIVE-MAP-FIN-2024-03-15
```

---

## 9. Related Articles and References

| Reference | What It Is |
|---|---|
| KB-DRIVE-MAP-FIN-001 (L2/L3) | Full technical KB article for L2/L3 engineers — detection, resolution, rollback, and preventive actions |
| Runbook-DRIVE-MAP-FIN-2024-03-15 | Step-by-step remediation runbook for L2 engineers |
| RCA-DRIVE-MAP-FIN-2024-03-15 | Root cause analysis for the original 2024-03-15 Finance outage |

---

*L1 KB Article prepared by DWP Engineer | Derived from Runbook DRIVE-MAP-FIN-2024-03-15 | v1.0 | 10/08/2026 | Status: Draft*
