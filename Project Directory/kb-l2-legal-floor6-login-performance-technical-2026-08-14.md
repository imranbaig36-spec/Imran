# L2 Technical Article: Legal Floor 6 Login/Performance Recurrence Handling
Version: 1.0
Last Updated: 2026-08-14
Derived From: Legal Floor 6 Login/Performance Remediation Runbook v1.0

Runbook Traceability (single source assurance):
- This article is a direct operational restatement of the runbook and must stay aligned.
- Runbook Procedure 1-9 -> L2 Procedure 1-9 in the same sequence.
- Runbook Verification Checklist -> L2 Verification Standard.
- Runbook Rollback Plan -> L2 Rollback Standard.

## Objective
Execute the same containment and recovery workflow used for the 2026-08-14 Legal Floor 6 login/performance incident without expanding scope or re-inventing the fix path.

## Entry Criteria
- Legal Floor 6 users report login failure, slow sign-in, or severe performance degradation at or just after sign-in.
- Current symptom pattern aligns with the known Document Manager rollout correlation.
- Endpoint Engineering or equivalent app deployment administrator is available.

## Required Inputs
- Affected-user or device list.
- Exact Document Manager app identifier and deployment target.
- Confirmation whether uninstall is defined.
- Pre-change assignment or deployment snapshot.
- Rollback point and validation contacts.

## Procedure
1. Confirm recurrence pattern.
Action: Match current symptoms, location, and timing against the original Floor 6 incident profile.
Expected result: You are handling the same incident shape, not an unrelated authentication or network issue.

2. Validate deployment correlation.
Action: Check whether affected devices are inside the active Document Manager deployment scope.
Expected result: The containment action is justified by scope alignment.

3. Capture rollback evidence.
Action: Save current app assignment or deployment state, group or collection membership, operator, and timestamp.
Expected result: Exact pre-change restoration data is preserved.

4. Remove the impacted Floor 6 scope from required deployment.
Action: In Intune, remove the Floor 6 device group from Required install. In SCCM, disable or delete the Required deployment for the impacted Floor 6 collection.
Expected result: Further forced app rollout stops for the targeted scope.

5. Start uninstall containment where available.
Action: In Intune, add the same group to Uninstall assignment if uninstall is configured. In SCCM, create an Uninstall deployment for the impacted collection.
Expected result: Already-impacted endpoints receive a removal instruction.

6. Force client policy retrieval.
Action: Run the documented Intune or SCCM client sync command on impacted endpoints.
Expected result: Clients request updated deployment policy without waiting for the next natural cycle.

7. Monitor first-wave device state.
Action: Confirm assignment change receipt and uninstall or remediation progress on at least three affected devices.
Expected result: The first-wave validation set reflects the intended change.

8. Verify user recovery.
Action: Re-test sign-in and post-login responsiveness with at least three previously affected users.
Expected result: Sign-in completes successfully and performance returns to acceptable levels.

9. Check for side effects and close evidence gaps.
Action: Confirm no unintended dependency break from removing the app and attach all evidence to the incident.
Expected result: Recovery is documented and no broader regression is introduced.

## Verification Standard
1. Deployment scope changed exactly as planned.
Expected result: Only the intended Floor 6 population was altered.

2. Required install is no longer active for the impacted scope.
Expected result: New forced installs stop.

3. Validation devices show sync and assignment-state change.
Expected result: Endpoint policy processing reflects the containment change.

4. At least three affected users verify restored sign-in and acceptable performance.
Expected result: The recurrence is operationally resolved.

## Rollback Standard
1. Restore the original Required assignment or deployment from the pre-change snapshot.
Expected result: Previous rollout state is reinstated exactly.

2. Remove temporary Uninstall assignment or deployment.
Expected result: Containment-specific removal stops.

3. Force policy retrieval and escalate for alternate root-cause analysis.
Expected result: Devices return to the restored state while investigation continues.

## Notes
- This article is a direct re-expression of the source runbook; do not add speculative remediation steps.
- If affected devices are not in the deployment scope, stop using this workflow and pivot to the next-ranked cause.