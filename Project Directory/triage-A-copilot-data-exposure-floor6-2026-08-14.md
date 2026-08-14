# Triage A: Possible Unauthorized Copilot Client-Matter Exposure (Floor 6)

**Date:** 2026-08-14  
**Incident Type:** Security/Confidentiality  
**Priority:** P1 (Highest)

## What Was Reported
A paralegal stated Copilot surfaced a client matter they believe they never had access to.

## Why This Is Urgent
Potential confidentiality breach with legal/regulatory implications. Treat as a security incident until disproven.

Classification guardrail:
- Handle as a security signal first, not as an "AI bug" triage path.
- Reason: incident risk depends on authorization correctness and exposure scope, not UI/feature behavior.

## What To Check First (In Order, And Why)
1. **Preserve evidence immediately**: timestamp, user, prompt, returned content, screenshot, session/context IDs.  
Why: evidence is time-sensitive and needed for defensible investigation.
2. **Validate source permissions** across DMS/SharePoint/OneDrive/matter ACLs.  
Why: confirms unauthorized access vs inherited/group access not understood by user.
3. **Review Copilot/Graph audit trails** for query and retrieval path.  
Why: identifies which system/content source returned the result under which identity.
4. **Check recent permission/group changes** for user and matter.  
Why: permission drift after changes is a common cause.
5. **Assess blast radius** (more users, more matters, repeated pattern).  
Why: determines scope and containment/notification obligations.

## Immediate Actions (Right Now)
- Open a **P1 security incident** and engage Security + Legal/Compliance.
- Instruct reporter to stop further Copilot interaction on that matter and preserve details.
- If approved by policy, apply temporary containment (scope-limited Copilot restriction) while validating access.
- Start incident timeline and decision log.

## What To Tell Non-Technical Stakeholders
“We are treating this as a potential confidentiality incident and have initiated an urgent security review. We are preserving evidence, verifying access permissions, and confirming whether this is a true breach or a configuration issue. We will provide a verified scope update and containment actions.”

## Owner Handoff
- Security Lead: SOC / Information Security
- Service Desk Lead: Duty Manager
- Supporting Teams: Identity, App Owner (DMS), Compliance/Legal
