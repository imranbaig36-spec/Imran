# L2 Technical Article: Handling Recurrence of Legal Floor 6 Copilot Access/Permissions Incident
Version: 1.0
Last Updated: 2026-08-14
Derived From: Legal Floor 6 Copilot Access/Permissions Remediation Runbook v1.0

Runbook Traceability (single source assurance):
- This article preserves the runbook structure one-for-one and must not introduce parallel logic.
- Runbook Procedure 1-9 -> L2 Procedure 1-9 in identical operational order.
- Runbook Verification Checklist -> L2 Verification Standard.
- Runbook Rollback Plan -> L2 Rollback Standard.

## Objective
Execute the same controlled remediation workflow used for the 2026-08-14 incident, without introducing unconfirmed assumptions.

## Entry Criteria
- User reports Copilot surfaced a legal matter they did not expect.
- Incident is active and classified as security/confidentiality priority.
- Security/data-governance escalation path is available.

## Required Inputs
- Reporter package: user ID, timestamp, prompt/output capture, device, impact statement.
- Security-confirmed root-cause sentence (verbatim).
- Security-confirmed remediation action sentence (verbatim).
- Pre-change access snapshot and rollback point.

## Procedure
1. Confirm ticket linkage and ownership.
Expected result: Incident, escalation, and security owner are all linked and visible.

2. Preserve evidence before making any changes.
Expected result: Prompt/output and audit references are retained for defensible review.

3. Validate effective access at event time.
Expected result: True access state is confirmed under the reported identity/context.

4. Record authoritative access path and root cause.
Expected result: Single non-speculative cause statement exists.

5. Approve scoped change and rollback plan.
Expected result: Change scope, target objects, approvals, and rollback method are documented.

6. Execute only the confirmed fix.
Action placeholder: [CONFIRMED REMEDIATION ACTION - INSERT VERBATIM].
Expected result: Access path is corrected without unrelated permission drift.

7. Verify no-repro for original scenario.
Expected result: Affected user context no longer returns restricted matter.

8. Run blast-radius checks for comparable users/groups.
Expected result: Scope is either expanded and remediated or confirmed contained.

9. Complete closure evidence package and security sign-off.
Expected result: Incident can close with cause, fix proof, verification, and residual risk statement.

## Verification Standard
- Reproduction test fails for unintended matter surfacing.
- Audit evidence aligns with remediation timestamp.
- Legitimate access remains functional.
- Security/data-governance sign-off present.

## Rollback Standard
Trigger rollback for business-critical access regression, widespread impact, or failed verification.

1. Restore from pre-change snapshot.
Expected result: Known-good pre-change state restored.

2. Validate critical legal workflows and re-open as containment if needed.
Expected result: Service stability restored while alternate fix is developed.

## Notes for Engineers
- Do not close as AI behavior without permission-path validation.
- Do not broadcast floor-wide communications unless additional confirmed cases or security direction requires it.
- Keep all causal and remediation statements verbatim from security/data-governance outputs.