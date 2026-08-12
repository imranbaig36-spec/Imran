# Copilot Support Ticket Triage (Day 8)

Date: 2026-08-12  
Audience: DWP engineer training (Copilot support tickets)

Cause options used (as requested):
- permissions/access boundary
- data indexing lag
- sensitivity label restriction
- license/client prerequisite issue
- guest/external sharing limitation
- genuine Copilot fault (last resort)

## Ticket 1
**ID:** 1  
**Ticket:** Finance lead: Copilot won't summarise the Q3 board pack in SharePoint. "It's right there, I can see it myself."

**Likely cause (ranked):**
1. permissions/access boundary
2. sensitivity label restriction
3. data indexing lag
4. license/client prerequisite issue
5. guest/external sharing limitation
6. genuine Copilot fault

**Fastest check:**
- Open the board pack in SharePoint and verify whether the file uses unique permissions, broken inheritance, or restricted link scope that could block Copilot retrieval context.

**Is this actually a Copilot bug?**
- **No (most likely).** The user can manually see the file, but Copilot access evaluation can still fail due to permission scope or policy boundary differences.

---

## Ticket 2
**ID:** 2  
**Ticket:** New hire (started yesterday): Copilot in Outlook seems to know nothing about my recent emails.

**Likely cause (ranked):**
1. data indexing lag
2. license/client prerequisite issue
3. permissions/access boundary
4. sensitivity label restriction
5. guest/external sharing limitation
6. genuine Copilot fault

**Fastest check:**
- Check mailbox/content indexing freshness for the new hire account and confirm enough ingestion time has elapsed since account/mailbox provisioning.

**Is this actually a Copilot bug?**
- **No (most likely).** New accounts commonly show delayed grounding while mailbox and graph signals are still being indexed.

---

## Ticket 3
**ID:** 3  
**Ticket:** HR manager: Asked Copilot in Word to pull data from a sensitive salary review spreadsheet, got "I don't have access to that content."

**Likely cause (ranked):**
1. sensitivity label restriction
2. permissions/access boundary
3. data indexing lag
4. license/client prerequisite issue
5. guest/external sharing limitation
6. genuine Copilot fault

**Fastest check:**
- Check the spreadsheet's sensitivity label and policy settings (including encryption/usage rights) to confirm Copilot access is intentionally restricted.

**Is this actually a Copilot bug?**
- **No.** The error text directly indicates an access/policy denial, which is expected behavior for protected HR content.

---

## Ticket 4
**ID:** 4  
**Ticket:** Sales rep: Copilot in Teams can't find a client contract that was shared with her via a guest link from another org.

**Likely cause (ranked):**
1. guest/external sharing limitation
2. permissions/access boundary
3. data indexing lag
4. sensitivity label restriction
5. license/client prerequisite issue
6. genuine Copilot fault

**Fastest check:**
- Confirm the contract is externally hosted and only shared by guest link from another tenant (not ingested as first-party organizational content in your tenant graph).

**Is this actually a Copilot bug?**
- **No (most likely).** Cross-tenant guest-link content often falls outside normal grounding scope.

---

## Ticket 5
**ID:** 5  
**Ticket:** IT admin: Copilot suddenly stopped working for the whole Finance team this morning, was fine yesterday.

**Likely cause (ranked):**
1. license/client prerequisite issue
2. permissions/access boundary
3. data indexing lag
4. sensitivity label restriction
5. guest/external sharing limitation
6. genuine Copilot fault

**Fastest check:**
- Verify whether Finance users still have active Copilot licenses and whether any recent policy/client rollout changed service availability.

**Is this actually a Copilot bug?**
- **Unclear.** Tenant-wide team impact suggests configuration/licensing change first; treat product fault only after entitlement and policy checks pass.

---

## Ticket 6
**ID:** 6  
**Ticket:** Manager: Copilot found and summarised a file I don't remember ever opening, from a folder I forgot I had access to.

**Likely cause (ranked):**
1. permissions/access boundary
2. data indexing lag
3. sensitivity label restriction
4. license/client prerequisite issue
5. guest/external sharing limitation
6. genuine Copilot fault

**Fastest check:**
- Validate the manager's effective access on that folder/file (including inherited group membership) to confirm Copilot is returning permitted content.

**Is this actually a Copilot bug?**
- **No.** This is usually expected retrieval from existing access rights, even if the user forgot that access.

---

## Ticket 7
**ID:** 7  
**Ticket:** Analyst: Copilot gives generic answers, doesn't seem to use any of our internal SharePoint content at all.

**Likely cause (ranked):**
1. license/client prerequisite issue
2. permissions/access boundary
3. data indexing lag
4. sensitivity label restriction
5. guest/external sharing limitation
6. genuine Copilot fault

**Fastest check:**
- Confirm the analyst is using a Copilot-enabled account/client with enterprise grounding enabled, then run a known-good prompt against a clearly accessible SharePoint file.

**Is this actually a Copilot bug?**
- **Unclear.** Generic output can indicate ungrounded mode from entitlement/client misconfiguration; bug only if prerequisites and access are confirmed healthy.

---

## Ticket 8
**ID:** 8  
**Ticket:** Executive assistant: Copilot in Outlook can't see a shared mailbox's calendar that I manage on behalf of my director.

**Likely cause (ranked):**
1. permissions/access boundary
2. license/client prerequisite issue
3. guest/external sharing limitation
4. data indexing lag
5. sensitivity label restriction
6. genuine Copilot fault

**Fastest check:**
- Verify delegate/shared mailbox permissions and whether Copilot is allowed to ground on delegated mailbox calendar data for that scenario.

**Is this actually a Copilot bug?**
- **No (most likely).** Delegate access and shared mailbox boundaries are a common non-bug limitation path.

---

## Notes for Trainees
- Default to access, policy, licensing, and indexing checks before escalating as a product defect.
- Only classify as genuine Copilot fault when all entitlement, boundary, policy, and external-content constraints are ruled out with evidence.
