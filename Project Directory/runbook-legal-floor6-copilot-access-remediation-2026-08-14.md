# Runbook: Legal Floor 6 Copilot Access/Permissions Remediation
Version: 1.0
Last Updated: 2026-08-14
Owner: Security/Data-Governance
Source Incident: RCA Legal Floor 6 Copilot Access/Permissions Incident (2026-08-14)

## Purpose
Provide a controlled, evidence-bounded procedure to remediate unexpected Copilot surfacing of a legal client matter. This runbook does not assume technical cause details unless explicitly confirmed by security/data-governance.

## Preconditions and Prerequisites
- Active incident record exists and is linked to the original report.
- Security/data-governance ownership is confirmed.
- Reporter details are available: user ID, timestamp, example prompt/output, device, business impact.
- Evidence preservation approved per policy.
- Change authority is available for remediation execution.
- Temporary communication scope is limited to affected user and incident stakeholders unless broader impact is confirmed.

## Inputs Required Before Fix Execution
- Confirmed root-cause statement from security/data-governance (verbatim).
- Confirmed remediation action statement from security/data-governance (verbatim).
- Affected resource list (matter/workspace/repository IDs).
- Baseline access state snapshot taken before remediation.

## Procedure
1. Open and classify the incident as security/confidentiality priority.
Expected result: Incident priority, owner, and escalation path are visible and active.

2. Preserve time-sensitive evidence.
Action: Capture timestamped prompt/output evidence, relevant audit references, and decision log entries.
Expected result: Investigation package is complete enough for audit and legal review.

3. Confirm effective access exists at query time.
Action: Security team validates user effective permissions on the surfaced matter across relevant content systems.
Expected result: Access state is confirmed as either present or absent at event time.

4. Identify and document the authoritative access path.
Action: Security/data-governance records the exact confirmed cause in one sentence.
Expected result: Root cause is explicit and non-speculative.

5. Freeze remediation scope and rollback point.
Action: Record exactly what will change, where, by whom, and how to revert.
Expected result: Approved change plan includes a tested rollback path and pre-change snapshot.

6. Execute the confirmed remediation action.
Action: Apply only the security-confirmed fix: [CONFIRMED REMEDIATION ACTION - INSERT VERBATIM].
Expected result: Targeted access path is corrected with no unapproved side effects.

7. Re-check affected user outcome.
Action: Re-test with the affected user identity/context to confirm the unexpected matter is no longer surfaced.
Expected result: Original reproduction path fails to return the restricted matter.

8. Assess blast radius.
Action: Run the same access-path check for comparable users/groups/systems in scope.
Expected result: Additional affected users are either identified and remediated, or scope is confirmed limited.

9. Record closure evidence.
Action: Attach cause statement, remediation proof, audit references, verification timestamp, and approver sign-off.
Expected result: Closure package is complete and defensible.

## Verification Checklist
- Affected user cannot reproduce the original unintended matter surfacing.
- Audit traces show corrected permissions/access path after remediation timestamp.
- No unintended regression for legitimate matter access.
- Blast-radius checks completed and documented.
- Security/data-governance sign-off attached.

## Rollback Plan
Trigger rollback if remediation blocks legitimate access, causes wider disruption, or fails verification.

1. Revert using the pre-change snapshot/change record captured in Step 5.
Expected result: Environment returns to known pre-remediation state.

2. Validate business-critical access restoration for impacted legitimate users.
Expected result: Required operations resume while incident remains under security control.

3. Re-open incident status as containment in progress and escalate for alternate fix path.
Expected result: Governance continuity maintained and risk remains actively managed.

## Required Artifacts at Closure
- Confirmed finding text (verbatim).
- Confirmed remediation action text (verbatim).
- Change execution evidence (ticket IDs, timestamps, approvers).
- Verification evidence and timestamp.
- Residual risk statement.