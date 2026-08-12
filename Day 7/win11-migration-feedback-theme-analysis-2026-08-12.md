# Win 11 Migration — Fin Bridge Staff Feedback Analysis
**Date:** 2026-08-12
**Analyst:** DWP Endpoint Team
**Source:** 50 post-migration comments from Fin Bridge staff
**Method:** Thematic clustering; severity weighted by user impact

---

## All Identified Themes

| # | Theme | Count | Severity |
|---|-------|-------|----------|
| 1 | Account Lockout / AVD Login Failure | 7 | Blocker |
| 2 | Floor 3 Printer Not Mapping | 6 | Blocker |
| 3 | OneDrive Files Missing / Sync Errors | 4 | Blocker |
| 4 | VPN Instability | 4 | Blocker |
| 5 | Shared Drive (S:) Inaccessible | 3 | Blocker |
| 6 | Slow Login Performance | 3 | Friction |
| 7 | Missing Desktop Shortcuts and Files | 3 | Friction |
| 8 | Start Menu and App Navigation | 2 | Friction |
| 9 | UI and Cosmetic Changes | 9 | Minor |
| 10 | Positive / Smooth Migration Experience | 9 | Positive |

**Total comments:** 50

---

### Theme Detail

**Account Lockout / AVD Login Failure** — Count: 7 | Severity: Blocker
IDs: 1, 11, 16, 21, 29, 37, 45
> *"Cannot log in to AVD at all since this morning. Tried 3 times. Urgent."*
> *"Account locked again, this is the third time this week."*

---

**Floor 3 Printer Not Mapping** — Count: 6 | Severity: Blocker
IDs: 3, 13, 19, 26, 35, 43
> *"Printer on floor 3 still broken, whole team can't print client docs."*
> *"Printer on floor 3 -- team has given up and is walking to floor 2 to print."*

---

**OneDrive Files Missing / Sync Errors** — Count: 4 | Severity: Blocker
IDs: 14, 23, 34, 42
> *"My OneDrive files are missing! This is urgent, need them for a meeting."*
> *"Missing files in OneDrive -- checked three times, still not there."*

---

**VPN Instability** — Count: 4 | Severity: Blocker
IDs: 5, 24, 39, 47
> *"VPN keeps dropping every 10 minutes, very frustrating for calls."*
> *"VPN dropped 4 times in one hour today, unacceptable for client work."*

---

**Shared Drive (S:) Inaccessible** — Count: 3 | Severity: Blocker
IDs: 7, 18, 31
> *"Finance shared drive completely inaccessible since the migration."*
> *"Cannot access S drive, blocking me from finishing month-end reports."*

---

**Slow Login Performance** — Count: 3 | Severity: Friction
IDs: 9, 32, 49
> *"Login is so slow now, takes 5 minutes some mornings."*
> *"Login speed has been consistently slow all week, not just today."*

---

**Missing Desktop Shortcuts and Files** — Count: 3 | Severity: Friction
IDs: 6, 22, 27
> *"Where did my desktop shortcuts go? Had to recreate them manually."*
> *"Files that used to be on my desktop are just gone now."*

---

**Start Menu and App Navigation** — Count: 2 | Severity: Friction
IDs: 12, 41
> *"New start menu layout is confusing, hard to find my apps."*
> *"Start menu search doesn't find some apps I use daily."*

---

**UI and Cosmetic Changes** — Count: 9 | Severity: Minor
IDs: 2, 8, 15, 17, 25, 30, 36, 44, 48
> *"Small thing but the taskbar clock format changed, prefer old one."*
> *"Wallpaper reset to default, not a big deal but noticed it."*

---

**Positive / Smooth Migration Experience** — Count: 9 | Severity: Positive
IDs: 4, 10, 20, 28, 33, 38, 40, 46, 50
> *"Love how fast the new laptop is! Much better than before."*
> *"Really smooth transition overall, thank you to the IT team."*

---

## Top 3 Priority Actions — Today (2026-08-12)

> Ranking weighs both **volume** (number of affected users) and **severity** (Blocker > Friction > Minor).
> A single Blocker outranks multiple Minor/Friction items.

---

### Rank 1 — Account Lockout / AVD Login Failure
**Count:** 7 | **Severity:** Blocker

**Why it ranks first:** Highest volume blocker. Users cannot begin their working day at all. Multiple individuals report this happening repeatedly across the week, indicating a systemic issue rather than isolated incidents — likely an AD policy conflict, MFA misconfiguration, or AVD app group assignment problem introduced during migration.

**Manager summary:** "Seven staff cannot access their desktops, some locked out for the third time this week — this is our most urgent live incident and needs an AD/AVD investigation today."

---

### Rank 2 — Floor 3 Printer Not Mapping
**Count:** 6 | **Severity:** Blocker

**Why it ranks second:** Second-highest volume blocker, persisting for at least three days post-migration. The entire Floor 3 team is affected (not isolated users), staff have already self-workaround'd by walking to Floor 2, and at least one comment flags an imminent client meeting. This is a GPO/print server mapping failure with a clear scope and external deadline pressure.

**Manager summary:** "The entire Floor 3 team has lost print capability since migration day with a client meeting at risk — we need a targeted GPO/print server fix assigned now."

---

### Rank 3 — VPN Instability
**Count:** 4 | **Severity:** Blocker

**Why it ranks third:** Equal comment volume to OneDrive (also 4) but prioritised above it because drops are occurring *live during client calls*, creating immediate reputational risk. OneDrive issues, while urgent, can sometimes be mitigated (SharePoint web access); a dropped client call cannot be recovered mid-conversation.

**Manager summary:** "Four staff are experiencing VPN drops mid-client-call — this is an active reputational risk and needs a network/split-tunnel review before end of business today."

---

*Note: OneDrive Files Missing (4 comments, Blocker) is the next priority immediately after the top 3 and should be addressed same day if resource allows.*
