# Copilot Support Ticket Triage — Legal Team (2026-08-12)

**Date:** 2026-08-12  
**Audience:** DWP engineer triage session  
**Cause ranking order used:**
1. permissions/access boundary
2. data indexing lag
3. sensitivity label restriction
4. license/client prerequisite issue
5. guest/external sharing limitation
6. genuine Copilot fault *(last resort only)*

---

## Ticket L-01 — Paralegal: SharePoint NDA "I don't have access to that content"

**Reported by:** Paralegal  
**Summary:** Asked Copilot to summarise a client NDA in SharePoint. Got "I don't have access to that content." File is in a folder she has never opened, only heard about in a meeting.

**Likely cause (ranked, most probable first):**
1. **permissions/access boundary** — She has never opened this folder; she likely has no actual permissions on it. Copilot enforces the same access boundary as SharePoint; if she cannot open it she cannot ground on it.
2. **sensitivity label restriction** — Client NDAs are high-value legal documents frequently protected with sensitivity labels (e.g. Confidential / Highly Confidential) that restrict Copilot grounding.
3. **data indexing lag** — Less likely for an existing document, but if the file was very recently uploaded it may not yet be indexed.

**Fastest check:**
Ask the paralegal to navigate directly to the SharePoint folder/file and attempt to open it. If SharePoint returns an access denied error, the cause is confirmed as permissions — not Copilot.

**Is this actually a Copilot bug?**
**No.** The user's own statement confirms she has never opened the folder and only heard about it second-hand. There is no evidence she holds permission to that content. The error message is consistent with correct access-boundary enforcement.

---

## Ticket L-02 — New Associate: Copilot in Outlook cannot find case emails

**Reported by:** New associate (started this week)  
**Summary:** Copilot in Outlook cannot find any case emails needed for context.

**Likely cause (ranked, most probable first):**
1. **data indexing lag** — Accounts provisioned within the last 7 days are routinely in the graph-indexing backfill window. Mailbox signals, sent items, and calendar data may not yet be surfaced to Copilot.
2. **license/client prerequisite issue** — Copilot licenses for new starters are sometimes activated after day-one provisioning; a gap between account creation and license assignment leaves the mailbox ungrounded.
3. **permissions/access boundary** — If the case emails sit in shared or matter-specific mailboxes, she may not yet have been added to the relevant distribution or access group.

**Fastest check:**
In the M365 admin centre, confirm the associate's Copilot license was assigned on or before her start date and check the Microsoft Search index status for the mailbox.

**Is this actually a Copilot bug?**
**No.** New-account indexing lag and late license activation are well-documented, expected behaviours for recently provisioned users.

---

## Ticket L-03 — Partner: Copilot surfaced a draft settlement from an unassigned matter

**Reported by:** Partner  
**Summary:** Copilot surfaced and summarised a draft settlement from a matter the partner is not assigned to. The partner was unaware they could see that folder at all.

> ⚠️ **This is a potential data governance / oversharing incident, not a Copilot fault.**  
> Escalate to the information security / records management team in parallel with triage.

**Likely cause (ranked, most probable first):**
1. **permissions/access boundary** — The partner holds access to the folder (likely via a broad group membership or broken permission inheritance) without realising it. Copilot correctly returned content within the user's access boundary. The problem is that the boundary is wider than intended.
2. **sensitivity label restriction** — The settlement draft may lack an appropriate sensitivity label, allowing it to be freely indexed and returned by Copilot where a label would have restricted it.

**Fastest check:**
Run an effective-permissions check on the settlement document/folder for the partner's account to confirm whether SharePoint itself would let them open it. If yes, the access boundary is the root cause and must be tightened.

**Is this actually a Copilot bug?**
**No.** Copilot returned content the partner legitimately (if unintentionally) has access to — this is correct product behaviour. The risk is an access governance gap, not a Copilot defect. The fix is to remove excess permissions and apply appropriate sensitivity labels to restrict future grounding.

---

## Ticket L-04 — Legal Ops Manager: All 40 Legal team members lost Copilot access simultaneously

**Reported by:** Legal ops manager  
**Summary:** All 40 Legal team users lost Copilot access this morning; worked fine all last week.

**Likely cause (ranked, most probable first):**
1. **license/client prerequisite issue** — Bulk license removal or reassignment is the most common cause of a sudden team-wide outage. A licence expiry, subscription change, or admin bulk-edit overnight would affect all users simultaneously.
2. **permissions/access boundary** — A group policy or security group change affecting the Legal team (e.g. removal from the Copilot-enabled group, conditional access policy applied) would produce the same sudden, team-scoped pattern.
3. **genuine Copilot fault** — A tenant-level service incident is possible but lower probability; would typically be visible in the M365 Service Health Dashboard with an active advisory.

**Fastest check:**
Open M365 admin centre → Licences → filter by Copilot licence and confirm current assignment count for the Legal team. Simultaneously check the M365 Service Health Dashboard for any active Copilot/Microsoft 365 advisories.

**Is this actually a Copilot bug?**
**Unclear.** The sudden, team-scoped pattern is far more consistent with a licensing or group policy change than a product bug. However, a tenant-level service incident cannot be ruled out until the health dashboard is reviewed. Classify as service incident only if licensing and policy checks are clean.

---

## Ticket L-05 — Contract Specialist: Vague generic answers about contract templates library

**Reported by:** Contract specialist  
**Summary:** Copilot gives vague, generic answers about clauses in the contract templates library and does not appear to actually read the documents.

**Likely cause (ranked, most probable first):**
1. **data indexing lag** — If the templates library was recently created, migrated, or renamed, it may not be fully indexed in Microsoft Search, causing Copilot to generate generic responses without document grounding.
2. **permissions/access boundary** — If the templates library uses restricted permissions or a broken inheritance model, Copilot may silently fall back to ungrounded responses rather than returning an explicit access error.
3. **sensitivity label restriction** — Templates labelled with policies that restrict extraction or Copilot use would produce generic output with no clear error message.
4. **license/client prerequisite issue** — If the user's account lacks the correct entitlements for SharePoint grounding (e.g. enterprise grounding not enabled), Copilot may appear to work but only generate from its base model.

**Fastest check:**
Ask the contract specialist to open a specific, known template document in SharePoint and then immediately ask Copilot: *"Summarise the document currently open."* If Copilot returns generic output rather than document-specific content, grounding is failing for that file — then check indexing and label status.

**Is this actually a Copilot bug?**
**Unclear.** Ungrounded output without an explicit error can indicate indexing, access, or label issues. Confirm grounding is working with a known-accessible file before escalating further. Only classify as a genuine fault if grounding is confirmed healthy and the problem persists across multiple accessible files.

---

## Triage Summary Table

| Ticket | Reporter | Most Probable Cause | Fastest Check | Copilot Bug? |
|--------|----------|---------------------|---------------|--------------|
| L-01 | Paralegal | permissions/access boundary | Open file directly in SharePoint | No |
| L-02 | New associate | data indexing lag | Check licence assignment date + index status | No |
| L-03 | Partner | permissions/access boundary (oversharing) ⚠️ | Run effective-permissions check on the file | No |
| L-04 | Legal ops manager | license/client prerequisite issue | Check Copilot licence count in M365 admin | Unclear |
| L-05 | Contract specialist | data indexing lag | Test grounding with open document prompt | Unclear |

---

## Engineer Notes
- **L-03 must be escalated** to information security / records management as a potential oversharing incident regardless of triage outcome.
- Default assumption: non-Copilot cause. Only classify as genuine Copilot fault after all access, licence, indexing, and label checks are exhausted with evidence.
