# Fin Bridge Win 11 Migration – Action Ranking & Theme Reference

**Source:** 15 post-migration comments from Fin Bridge staff  
**Reviewed by:** DWP Analyst  
**Date:** 2026-08-12

---

## Ranking Methodology

Severity takes precedence over volume. A single Blocker outranks any number of Minor comments. Where severity is equal, volume and trajectory (is the issue spreading?) are used to differentiate.

---

## Top 3 Themes to Act on Today

### Rank 1 — Credentials Vault Inaccessible (3 comments, Blocker)

**Why it ranks here:**  
Highest combined weight of any theme. Three independent reports confirm the issue is real, not a one-off. The comments span multiple days, the whole team is described as blocked, and at least one user has already escalated to their manager — meaning this is about to land on leadership regardless. Severity is maximum (Blocker) and the persistence signals no self-resolution is occurring.

**For your manager:**  
> "The shared credentials vault has been completely inaccessible for at least three days, the whole team is blocked, and it has already been escalated — this needs an incident owner assigned now."

---

### Rank 2 — Admin Console Lockouts (2 comments, Blocker)

**Why it ranks here:**  
Starts at 2 comments but the trajectory is the warning sign: comment 3 reports one locked-out engineer, comment 10 reports the lockout has spread to the whole team. That pattern — individual to team-wide in the same week — suggests an underlying permissions or policy change from the migration rather than a user error. Left unaddressed, the blast radius will grow.

**For your manager:**  
> "Admin console lockouts started with one engineer and have now spread team-wide, which points to a migration-induced permissions fault that will keep widening until it is fixed."

---

### Rank 3 — Test VM / Remote Access Down (2 comments, Blocker)

**Why it ranks here:**  
Two Blocker comments where users explicitly state they cannot do their jobs. The issue has persisted across at least two separate days (comments 1 and 12 read as the same person on different days), confirming it has not self-resolved. Ranked below Admin Console Lockouts only because there is no evidence yet of it spreading beyond the initial reporter(s); if a third report appears, this should move to Rank 2.

**For your manager:**  
> "At least one engineer has been unable to remote into their test VMs since the migration and is still blocked today — this is preventing them from doing any productive work."

---

---

## All Identified Themes (Reference)

| # | Theme | Count | Severity |
|---|---|---|---|
| 1 | Credentials Vault Inaccessible | 3 | Blocker |
| 2 | Admin Console Lockouts | 2 | Blocker |
| 3 | Test VM / Remote Access Down | 2 | Blocker |
| 4 | Cosmetic UI Changes | 3 | Minor |
| 5 | Performance Degradation | 1 | Friction |
| 6 | Positive Rollout Feedback | 4 | Positive |

---

### Theme 1: Credentials Vault Inaccessible

**Description:** Multiple staff unable to access the shared credentials vault, with the issue persisting across multiple days and escalating to management.

**Count:** 3 (comments 5, 8, 14)

**Quotes:**
> "Shared credentials vault is completely inaccessible, whole team blocked."  
> "Third day now I can't access the credentials vault, this is urgent."

**Severity:** Blocker

---

### Theme 2: Admin Console Lockouts

**Description:** Engineers are being locked out of the admin console entirely, with the problem spreading from individual users to the whole team.

**Count:** 2 (comments 3, 10)

**Quotes:**
> "Second engineer this week locked out of the admin console entirely."  
> "Admin console lockouts happening across the whole team now, not just one person."

**Severity:** Blocker

---

### Theme 3: Test VM / Remote Access Down

**Description:** Staff unable to remote into test VMs following the update, preventing them from carrying out their daily work.

**Count:** 2 (comments 1, 12)

**Quotes:**
> "Can't remote into any of my test VMs since the update, blocking my whole day."  
> "My test VM access is still down, can't do my job today either."

**Severity:** Blocker

---

### Theme 4: Cosmetic UI Changes

**Description:** Minor visual and audio changes noticed post-migration — smaller fonts, changed notification sounds, and adjusted icons — causing low-level friction but no work stoppage.

**Count:** 3 (comments 4, 7, 15)

**Quotes:**
> "Font in the new portal is slightly smaller, hard to read for some of us."  
> "Small UI icon changes, took a second to adjust but fine."

**Severity:** Minor

---

### Theme 5: Performance Degradation

**Description:** Slight slowdown in dashboard refresh speed observed, though considered barely noticeable by the reporting user.

**Count:** 1 (comment 9)

**Quotes:**
> "Dashboard refresh is a bit slower than before, barely noticeable."

**Severity:** Friction

---

### Theme 6: Positive Rollout Feedback

**Description:** Several staff reported a smooth migration experience, praised new UI features such as dark mode, and noted no issues at all.

**Count:** 4 (comments 2, 6, 11, 13)

**Quotes:**
> "Overall the rollout felt smoother than last time, appreciate it."  
> "Nice that the new theme supports dark mode properly now."

**Severity:** Positive
