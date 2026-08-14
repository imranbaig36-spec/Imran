# RCA: Legal Floor 6 Copilot Access/Permissions Incident

## 1) Executive Summary
- Incident: A Legal Floor 6 paralegal reported Copilot surfaced a client matter she believed she had never accessed.
- Security/data-governance status: Investigation completed.
- Confirmed finding from security/data-governance: [their finding - to confirm].
- Confirmed remediation action taken: [confirmed action - to confirm].
- Current service status after remediation: [status and verification statement - to confirm].

Important constraint applied in this RCA:
- No permissions path, group, ACL, or system behavior is asserted unless explicitly confirmed by security/data-governance.
- Any missing detail is marked to confirm.

## 2) Scope and Impact
### Confirmed
- One individual on Legal Floor 6 was confirmed as affected at initial triage stage.
- Incident was treated as a security/confidentiality priority event.
- Security/data-governance investigation was formally escalated and completed.

### To Confirm
- Whether any additional users/matters were confirmed affected.
- Final blast radius and impacted repositories/systems.
- Exact time window of exposure.
- Whether policy/regulatory notification thresholds were met.

## 3) Confirmed Evidence Sources Used
1. triage-A-copilot-data-exposure-floor6-2026-08-14.md
2. escalation-legal-floor6-client-matter-access-2026-08-14.md
3. security-analysis-legal-floor6-unintended-access-2026-08-14.md
4. legal-floor6-copilot-access-service-desk-action-2026-08-14.md
5. Security/data-governance final investigation output: [reference/ticket/report ID - to confirm]

## 4) Timeline (Confirmed Facts and Explicit Gaps)
| Time (Local) | Event | Status |
|---|---|---|
| Friday afternoon (exact timestamp to confirm) | Document management app deployed to relevant cohort | Confirmed as prior change context |
| Monday morning (exact timestamp to confirm) | User reported unexpected client matter surfaced in Copilot | Confirmed |
| 2026-08-14 (time to confirm) | Security/confidentiality triage initiated and escalated | Confirmed |
| 2026-08-14 (time to confirm) | Service desk confirmed escalation tracking and ownership | Confirmed |
| [time to confirm] | Security/data-governance completed investigation | Confirmed completion; exact time to confirm |
| [time to confirm] | Security/data-governance confirmed root cause finding | Confirmed that a finding exists; exact finding text to confirm |
| [time to confirm] | Remediation action executed | Confirmed that action was taken; exact action text to confirm |
| [time to confirm] | Post-remediation verification completed | To confirm |

## 5) Root Cause Statement
### Confirmed
- Root cause was determined by security/data-governance investigation and is recorded as:
  [their finding - to confirm]

### Not Confirmed in this document
- Specific technical permission chain (group inheritance, direct ACL, sync artifact, app-provisioning assignment, or other) unless explicitly provided by security/data-governance.

## 6) Supporting Evidence Matrix
| Evidence Artifact | What It Demonstrates | Status |
|---|---|---|
| Reporter details + prompt/output capture | Initial event authenticity and investigative starting point | Confirmed at triage level |
| Access audit trail reviewed by security/data-governance | Authoritative determination of actual access path | Finding summary to confirm |
| Identity/group/ACL change history | Whether access was expected or mis-scoped | To confirm |
| Copilot/Graph retrieval audit path | Which content source and identity context were used | To confirm |
| Remediation execution logs | Proof of action taken and timestamp | To confirm |
| Post-remediation validation checks | Confirmation that issue no longer reproduces | To confirm |

## 7) Five-Why Analysis (Strictly Bounded to Confirmed Inputs)
1. Why was a matter surfaced unexpectedly to the user?
- Because the user’s effective access path permitted retrieval at query time, per security/data-governance investigation outcome [to confirm exact mechanism].

2. Why did that effective access path exist?
- [Confirmed causal factor from security/data-governance - to confirm].

3. Why was the causal factor not prevented earlier?
- [Control/process gap identified by security/data-governance - to confirm].

4. Why was the control/process gap not detected pre-incident?
- [Detection/monitoring limitation identified by security/data-governance - to confirm].

5. Why did this present through Copilot rather than being noticed earlier elsewhere?
- Copilot surfaced content according to existing permissions model; timing/visibility pathway specifics require security confirmation [to confirm].

## 8) Corrective Actions
### Confirmed
- Security/data-governance completed investigation.
- Remediation was executed: [confirmed action - to confirm].

### To Confirm
- Exact systems changed (for example: specific group membership, ACL entry, policy assignment, connector scope, or other).
- Exact change ticket IDs, approvers, and execution timestamps.
- Validation method, sample size, and observation period used to confirm recovery.

## 9) Preventive Actions (Non-Assumptive; Final Ownership/Details Pending)
1. Access Governance Hardening
- Implement/strengthen periodic least-privilege reviews for legal matter access.
- Owner/date/evidence of implementation: to confirm.

2. Change Guardrails for Matter Access
- Require pre-change impact assessment and post-change validation for any bulk access/provisioning change.
- Owner/date/control definition: to confirm.

3. Drift Detection and Alerting
- Add automated alerts for unexpected access grants to sensitive matter scopes.
- Platform scope and thresholds: to confirm.

4. Incident Evidence Standardization
- Standardize required artifacts (access audit export, identity diff, retrieval path evidence, remediation log) before closure.
- Runbook owner/date: to confirm.

5. Closure Quality Gate
- Require explicit security sign-off with root-cause sentence, remediation proof, and no-repro verification before final closure.
- Governance owner/date: to confirm.

## 10) Residual Risk
- Residual risk cannot be fully rated until the exact confirmed cause and remediation evidence are attached.
- Current residual risk statement: to confirm.

## 11) Final Assessment and Closure Conditions
- This RCA is intentionally evidence-bounded and does not infer unconfirmed permissions details.
- To finalize this RCA, append the security/data-governance confirmed finding verbatim and remediation evidence:
  - Confirmed finding text
  - Confirmed remediation action text
  - Audit artifact references
  - Verification outcome and timestamp
- Final closure status: to confirm.

## 12) Appendices
### A) Confirmed Finding Placeholder (to be replaced verbatim)
[their finding - to confirm]

### B) Confirmed Remediation Placeholder (to be replaced verbatim)
[confirmed action - to confirm]

### C) Verification Placeholder
[confirmed verification detail - to confirm]
