# M365 Copilot Readiness — Tiered Priority Ranking
**Department:** Finance (~200 users)  
**Date:** 2026-08-12  
**Prepared by:** DWP Engineer  
**Source document:** m365-copilot-readiness-checklist-finance.md

---

## Why tiering matters for this deployment

Not all readiness checks carry equal risk. For a standard department you could make a case for doing a phased rollout while some checks are still in progress. For Finance — with payroll, board packs, M&A documents, and client financial data on SharePoint permissions that have not been reviewed since 2019 — that logic does not apply. The tiers below reflect the consequence of getting each item wrong in this specific context, not just generic M365 best practice.

---

## TIER 1 — MUST complete before rollout (blocking)

> Skipping any of these items creates a risk that cannot be retrospectively fixed after Copilot is live. Data exposure through Copilot is not like a misconfigured report — once a user has queried sensitive content and received a Copilot-generated summary, that exposure has already occurred.

| Ref | Item | Why it is blocking |
|-----|------|--------------------|
| 3.1–3.4 | SharePoint permissions audit — all Finance site collections | Copilot will query any content the user can access. Unaudited 2019 permissions mean users almost certainly have access to content beyond their current role. This cannot be discovered after Copilot is live without accepting the exposure. |
| 3.5–3.6 | Revoke all anonymous and broad "org-wide" sharing links on Finance sites | Anonymous links bypass all identity controls. Copilot can surface content behind these links to any user who encounters them. Must be zero before go-live. |
| 3.7–3.13 | Permissions remediation — break inheritance, remove stale groups, least-privilege | The audit finding is only useful if acted on. Remediation must be confirmed by a second-pass report, not assumed. |
| 3.14–3.16 | OneDrive sharing controls for Finance users | Payroll and client data can easily reside in OneDrive. Same exposure risk as SharePoint if unchecked. |
| 4.1–4.4 | Sensitivity labels deployed and auto-labelling active | Copilot inherits the label from source content when generating outputs. Without labels, Copilot-generated documents carry no automatic classification or DLP protection, even when drafted from highly sensitive source material. |
| 4.7 | DLP policies confirmed and Finance sites in scope | Without DLP, a labelled document can still be exfiltrated. Label + DLP is the minimum control pair for Finance data. |
| 5.1–5.2 | MFA enforced for all 200 Finance users | Copilot operates under the user's identity. A compromised account without MFA gives an attacker full Copilot-assisted access to all Finance data. MFA must be confirmed, not assumed. |
| 5.3 | Legacy authentication blocked for Finance users | Legacy auth bypasses Conditional Access and therefore bypasses MFA enforcement. A single legacy-auth gap undermines the entire identity control. |
| 1.1–1.2 | Verify all 200 users hold E5 and no service accounts are in scope | Copilot cannot function without the correct licence. Service accounts in the licence group create uncontrolled access vectors. |
| 1.4–1.5 | Assign Copilot add-on via scoped security group with verified membership | Assigning tenant-wide or to an unvalidated group risks enabling Copilot for users outside Finance or for leavers still in the directory. |

---

## TIER 2 — SHOULD complete before rollout (high risk if skipped)

> These items do not technically prevent Copilot from functioning, but skipping them in a Finance context creates compliance gaps, user confusion, or undetected data risks that will be significantly harder to close after rollout.

| Ref | Item | Why it is high risk if skipped |
|-----|------|-------------------------------|
| 4.5 | Mandatory labelling enforced for Outlook and M365 Apps | Without mandatory labelling, new Finance content created after go-live (Copilot-assisted drafts, emails, summaries) will be unlabelled. DLP and downstream controls then have no signal to act on. |
| 4.6 | Confirm Copilot inherits highest label from source documents | If this default is not verified, Copilot could produce a summary of a Highly Confidential document with no label applied to the output. |
| 4.8 | Content explorer scan — identify unlabelled files in Finance libraries | Auto-labelling only covers content matched by policy. Pre-existing unlabelled files are a blind spot that Copilot will happily query and surface. |
| 5.4–5.5 | All Finance accounts Entra-joined; devices compliant in Intune | Unmanaged or non-compliant devices are an uncontrolled endpoint for Copilot output — summaries of board packs could be copied to personal devices with no MDM oversight. |
| 5.7 | Conditional Access blocks Copilot from non-compliant devices | Even with MFA in place, without this policy a user on a personal unmanaged device can access Copilot and Finance content. |
| 6.1–6.3 | Pre-launch comms, AI Acceptable Use Policy published | Finance users who don't understand what Copilot can see are the most likely source of accidental data misuse. Comms before go-live set expectations; comms after go-live are remediation. |
| 6.6 | Manager briefing on data hygiene expectations | Finance managers need to understand they are accountable for how their teams use Copilot. Without this briefing, governance is technical-only with no human accountability layer. |

---

## TIER 3 — CAN complete during or after rollout (lower risk)

> These items improve the deployment quality and user experience but do not create a data exposure risk if they are not complete on day one.

| Ref | Item | Notes |
|-----|------|-------|
| 1.3 | Budget approval and procurement sign-off for licences | Administrative prerequisite; no security consequence. Should naturally complete before 1.4 anyway. |
| 1.6 | Check for double-licensing (E3 + Copilot waste) | Cost governance, not a security control. Can be reviewed in the first licence audit cycle post-rollout. |
| 2.1–2.6 | M365 Apps client version and channel checks | Endpoints below the minimum build simply won't activate Copilot features — they fail safe. Remediation can continue in parallel with rollout to other compliant devices. |
| 5.6 | Confirm privileged admin accounts are not the Copilot-licensed accounts | Important hygiene but does not change the data exposure risk for standard Finance users. Address in the first post-rollout identity review. |
| 6.4–6.5 | Finance champions identified, Microsoft Learn training assigned | Enhances adoption quality; does not affect security posture. Pilot phase naturally accommodates this. |
| 6.7 | Copilot feedback channel established | Useful for surfacing problems post-launch. Should be in place before wide rollout but not a blocker for a controlled pilot. |
| 6.8 | Rollback/suspension process defined and communicated | Should be documented before wide rollout. For an initial pilot group it can be completed in parallel. |

---

## Why the permissions audit belongs in TIER 1 — not licensing or client version

This is the question worth answering explicitly, because the instinct in many rollout projects is to start with the straightforward technical checks (licensing, build versions) and treat permissions as a background task. In this Finance context, that instinct is wrong for the following reasons.

### 1. Licensing and client version fail safe — permissions do not

If a user's M365 Apps build is below the minimum, Copilot simply does not light up for that user. The consequence of getting it wrong is that Copilot doesn't work. If a user's SharePoint permissions include access to board packs, payroll files, or M&A materials from a 2019 group membership they should never have had, and Copilot is enabled, the consequence of getting it wrong is that the user can now query, summarise, and extract that data through natural language. One scenario is a broken feature. The other is a data breach.

### 2. Copilot is a force multiplier for existing access — in both directions

Before Copilot, a Finance analyst with residual 2019 permissions to the M&A library would have to actively navigate to that SharePoint site and open documents. Most users wouldn't. With Copilot, they can type "summarise the latest acquisition targets" into a chat prompt and receive an answer — without ever knowing they shouldn't have that access, and without a clear audit trail that a specific document was opened. Copilot removes the friction that previously acted as an informal barrier to oversharing.

### 3. The 2019 migration is a specific, documented risk — not a theoretical one

Generic Copilot readiness guidance mentions permissions as a consideration. For this department it is a confirmed problem: permissions have not been reviewed in seven years, across a department that handles the most sensitive financial data in the organisation. The likelihood of material oversharing is high, not speculative. Tier 1 is appropriate when the risk is known and the remediation is feasible before go-live.

### 4. Remediation after go-live is not equivalent to remediation before

Once Copilot is live, tightening permissions does not undo any queries that have already been run. There is no "undo" for a Copilot session that summarised a payroll file a user should never have accessed. For content classified as payroll, board packs, M&A documents, or client financial data, post-facto remediation may also trigger notification obligations under UK GDPR or FCA requirements. The cost of getting it wrong after go-live is categorically higher than the cost of delaying go-live by two to four weeks to complete the audit.

### 5. Sensitivity labels depend on permissions being correct first

Labels control what Copilot does with content after it retrieves it. But if the permissions model means Copilot can retrieve content it should never reach, labels cannot compensate. Permissions are the first line of defence; labels are the second. You cannot layer the second on top of a broken first.

---

*This document should be read alongside the full checklist (m365-copilot-readiness-checklist-finance.md). Items in Tier 1 must have named owners and confirmed completion dates before a go-live date is set.*
