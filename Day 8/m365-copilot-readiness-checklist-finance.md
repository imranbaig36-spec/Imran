# Microsoft 365 Copilot Readiness Checklist — Finance Department
**Department:** Finance (~200 users)  
**Data sensitivity:** HIGH — payroll, board packs, M&A documents, client financial data  
**Date prepared:** 2026-08-12  
**Prepared by:** DWP Engineer  
**M365 licensing:** E5 confirmed; Copilot add-on not yet assigned

---

> **Risk note:** SharePoint permissions for this department were inherited from a 2019 migration and have never been audited. Before Copilot is enabled, Copilot will surface content that users have access to — including content they should never have had access to. Oversharing remediation is the **highest priority gate** in this checklist. Copilot must not be enabled until Sections 3 and 4 are complete and signed off.

---

## How to use this checklist
- Work through sections in order — sections 3 and 4 are prerequisites for all others.
- Mark each item: **[ ]** not started · **[~]** in progress · **[x]** complete
- Assign an owner and target date to each item before starting.
- A final sign-off row appears at the end of each section.

---

## Section 1 — Licensing Prerequisites
*Owner: _________________ · Target date: _________________*

| # | Check | Done |
|---|-------|------|
| 1.1 | Confirm all ~200 Finance users hold an active M365 E5 licence in Entra ID (Users > Licences). | [ ] |
| 1.2 | Identify any shared/service/room accounts in the Finance OU — Copilot licences must not be assigned to non-human accounts. | [ ] |
| 1.3 | Obtain budget approval and procurement sign-off for 200 × Microsoft 365 Copilot add-on licences. | [ ] |
| 1.4 | Assign Copilot add-on licences via group-based licensing to a scoped Finance security group — **do not assign individually or tenant-wide**. | [ ] |
| 1.5 | Confirm the Finance security group membership is accurate and HR-maintained before licence assignment. | [ ] |
| 1.6 | Verify no users are double-licensed (e.g., E3 + Copilot) which would waste spend. | [ ] |

**Section 1 sign-off:** _________________ Date: _________________

---

## Section 2 — Microsoft 365 Apps Client Version
*Owner: _________________ · Target date: _________________*

| # | Check | Done |
|---|-------|------|
| 2.1 | Confirm all Finance endpoints are running **Microsoft 365 Apps version 2307 (build 16626.20132) or later** — the minimum for Copilot in-app features. | [ ] |
| 2.2 | Verify endpoints are on **Current Channel** or **Monthly Enterprise Channel** (Semi-Annual Channel is not supported for Copilot). | [ ] |
| 2.3 | Run an Intune/MECM compliance report scoped to Finance devices to surface any endpoints below minimum build. | [ ] |
| 2.4 | Force-update or exclude non-compliant devices before Copilot licence assignment. | [ ] |
| 2.5 | Confirm Microsoft Teams desktop client is up to date (new Teams preferred; Copilot meeting features require new Teams). | [ ] |
| 2.6 | Confirm Edge is on a supported release channel (Copilot in Edge requires Chromium-based Edge 109+). | [ ] |

**Section 2 sign-off:** _________________ Date: _________________

---

## ⚠️ SECTION 3 — SharePoint & OneDrive Permissions Audit [HIGHEST PRIORITY — BLOCKING]
> **Why this is the top gate:** Copilot will retrieve and summarise any content the user has access to. With permissions inherited from a 2019 migration and never audited since, there is a high probability that Finance users have accumulated access to payroll files, board packs, M&A materials, and client data they should no longer hold. Enabling Copilot before this audit is complete would allow those users to query and extract that content through natural language. This is a **data governance and regulatory risk**, not just a technical one.

*Owner: _________________ · Target date: _________________*

### 3A — Audit Preparation

| # | Check | Done |
|---|-------|------|
| 3.1 | Run the **SharePoint Assessment Tool** (or Microsoft 365 Assessment Tool) against all Finance-related site collections to generate a full permissions report. | [ ] |
| 3.2 | Export all SharePoint site, library, folder, and file-level permission grants for Finance sites — include direct grants, group memberships, and sharing links. | [ ] |
| 3.3 | Identify all sites/libraries where Finance users have permissions inherited from 2019 groups that have not been reviewed. Flag these as high-risk. | [ ] |
| 3.4 | Identify all sites outside the Finance OU/site collection where Finance users have been granted access (cross-department oversharing). | [ ] |
| 3.5 | Pull a report of all **"Anyone" (anonymous) sharing links** active on Finance-related sites — these must all be revoked before Copilot goes live. | [ ] |
| 3.6 | Pull a report of all **"People in the organisation"** sharing links on high-sensitivity libraries (payroll, M&A, board packs) — evaluate and revoke where not justified. | [ ] |

### 3B — Remediation

| # | Check | Done |
|---|-------|------|
| 3.7 | **Revoke all anonymous sharing links** on Finance site collections. Confirm via re-run of the sharing links report. | [ ] |
| 3.8 | Remove stale 2019-era group memberships — cross-reference with current HR org chart and validate with Finance managers. | [ ] |
| 3.9 | Break permission inheritance on libraries containing payroll data; re-apply explicit, role-based grants only. | [ ] |
| 3.10 | Break permission inheritance on libraries containing board pack / M&A / client data; re-apply explicit, role-based grants only. | [ ] |
| 3.11 | Ensure **least-privilege** is applied: Finance staff should have access only to the libraries required for their current role — not all Finance libraries by default. | [ ] |
| 3.12 | Remove any external guest accounts from Finance sites that are no longer active or justified. | [ ] |
| 3.13 | Validate remediation with a second pass of the SharePoint Assessment Tool — confirm no high-risk findings remain before proceeding. | [ ] |

### 3C — OneDrive

| # | Check | Done |
|---|-------|------|
| 3.14 | Audit OneDrive for Business sharing for Finance users — check for externally shared files containing sensitive data. | [ ] |
| 3.15 | Restrict the default sharing scope for Finance users to **"Specific people only"** via SharePoint admin policy. | [ ] |
| 3.16 | Disable "Anyone" link creation for Finance users in SharePoint/OneDrive admin settings. | [ ] |

**Section 3 sign-off (must be completed before Copilot licences are assigned):**  
Signed: _________________ Role: _________________ Date: _________________

---

## ⚠️ SECTION 4 — Sensitivity Labelling [HIGH PRIORITY — BLOCKING]
> Copilot respects Microsoft Purview sensitivity labels when generating and summarising content. Without labels applied to Finance data, there is no automatic protection layer when Copilot drafts documents or emails using sensitive source content. Labelling must be in place before Copilot is enabled.

*Owner: _________________ · Target date: _________________*

| # | Check | Done |
|---|-------|------|
| 4.1 | Confirm Microsoft Purview Information Protection is enabled in the tenant and Finance is in scope. | [ ] |
| 4.2 | Confirm a sensitivity label taxonomy is published that covers Finance data classes — at minimum: **Internal**, **Confidential – Finance**, **Highly Confidential – Restricted**. | [ ] |
| 4.3 | Enable **auto-labelling policies** for SharePoint libraries holding payroll, board packs, M&A, and client financial data. | [ ] |
| 4.4 | Confirm auto-labelling simulation has been run and reviewed before enforcing — check the Purview compliance portal for simulation results. | [ ] |
| 4.5 | Apply **mandatory labelling** for Outlook and M365 Apps for Finance users so all new content is labelled at creation. | [ ] |
| 4.6 | Confirm Copilot is configured to inherit the highest label from source documents when generating outputs (this is the default, but verify in Purview settings). | [ ] |
| 4.7 | Confirm **DLP policies** are in place to block external sharing of content labelled Confidential or above, and that Finance sites are in scope. | [ ] |
| 4.8 | Run a content explorer scan to identify unlabelled files in Finance site collections — prioritise manual or auto-label coverage before go-live. | [ ] |

**Section 4 sign-off (must be completed before Copilot licences are assigned):**  
Signed: _________________ Role: _________________ Date: _________________

---

## Section 5 — Identity & MFA Readiness
*Owner: _________________ · Target date: _________________*

| # | Check | Done |
|---|-------|------|
| 5.1 | Confirm all 200 Finance users are registered for **MFA** — run the Entra ID MFA registration report and remediate gaps. | [ ] |
| 5.2 | Confirm **Conditional Access** is enforcing MFA for all M365 services for Finance users — no legacy auth exceptions. | [ ] |
| 5.3 | Confirm legacy authentication protocols (Basic Auth, SMTP AUTH for non-service use) are blocked for Finance users. | [ ] |
| 5.4 | Confirm all Finance accounts are sourced from a managed identity (Entra ID cloud or hybrid-joined) — no purely on-prem-only accounts remain. | [ ] |
| 5.5 | Confirm devices used by Finance users are **Entra ID joined or hybrid-joined** and compliant in Intune before Copilot licence assignment. | [ ] |
| 5.6 | Review any privileged Finance admin accounts — confirm these are not the day-to-day accounts that will receive Copilot licences. | [ ] |
| 5.7 | Confirm Conditional Access blocks Copilot access from non-compliant or unmanaged devices. | [ ] |

**Section 5 sign-off:** _________________ Date: _________________

---

## Section 6 — End-User Communications & Enablement
*Owner: _________________ · Target date: _________________*

| # | Check | Done |
|---|-------|------|
| 6.1 | Draft and send a pre-launch communication to Finance users explaining what Copilot is, what it can and cannot do, and the data responsibility expectations. | [ ] |
| 6.2 | Communicate clearly to Finance users that **Copilot will see what they can see** — reinforce that they must not use Copilot to access, summarise, or share content beyond their role. | [ ] |
| 6.3 | Publish or link to the organisation's **AI Acceptable Use Policy** for Finance staff before go-live. | [ ] |
| 6.4 | Identify Finance champions (typically 2–3 power users per team) to test Copilot in a pilot phase before broad rollout. | [ ] |
| 6.5 | Assign champions to complete **Microsoft Copilot Adoption training** (available via Microsoft Learn / Adoption Hub). | [ ] |
| 6.6 | Schedule a 30-minute briefing session with Finance managers on data hygiene expectations and how to escalate oversharing concerns post-launch. | [ ] |
| 6.7 | Confirm a **Copilot feedback channel** (e.g., a Teams channel or shared mailbox) is in place for Finance staff to report unexpected behaviour or data concerns. | [ ] |
| 6.8 | Define and communicate the rollback/suspension process — how Copilot licences will be removed if a data incident is suspected. | [ ] |

**Section 6 sign-off:** _________________ Date: _________________

---

## Final Go/No-Go Gate

Before assigning Copilot licences to any Finance user, all of the following must be signed off:

| Gate | Signed off | Date |
|------|-----------|------|
| Section 3 — Permissions & oversharing audit complete, no high-risk findings outstanding | | |
| Section 4 — Sensitivity labels deployed, auto-labelling active, DLP policies confirmed | | |
| Section 5 — MFA enforced for all 200 users, Conditional Access confirmed | | |
| Section 1 — Licences procured and group-based assignment ready (do not assign until above are done) | | |
| Section 2 — All Finance endpoints at minimum supported build | | |
| Section 6 — Comms sent, champions briefed, feedback channel live | | |

**Overall go-live approval:**  
Approved by: _________________ Role: _________________ Date: _________________

---

*Document owner: DWP Engineer · Review cycle: Before each Copilot rollout phase and after any significant SharePoint permission change*
