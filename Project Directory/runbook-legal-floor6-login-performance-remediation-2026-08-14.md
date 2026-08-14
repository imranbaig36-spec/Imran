# Runbook: Legal Floor 6 Login/Performance Remediation
Version: 1.0
Last Updated: 2026-08-14
Owner: Endpoint Engineering / Incident Management
Source Incident: RCA Legal Floor 6 Login/Performance Incident (2026-08-14)

## Purpose
Provide the controlled containment-and-recovery procedure for recurrence of the Legal Floor 6 login failure, slow sign-in, and workstation performance incident tied to the Friday Document Manager rollout hypothesis.

## Prerequisites
- Active incident ticket linked to the original Floor 6 login/performance incident.
- Incident lead assigned and Endpoint Engineering engaged.
- Affected Floor 6 Azure AD device group or SCCM device collection identified.
- Exact Document Manager application name, package ID, and deployment target confirmed.
- Confirmation whether the application has a working uninstall command.
- At least one affected device and one unaffected comparison device identified.
- Change authority available for app assignment or deployment modification.
- Evidence capture plan in place for pre-change and post-change comparison.

## Inputs Required Before Execution
- Current affected-user or affected-device list.
- Pre-change deployment snapshot showing current Required install assignment or Required deployment.
- Rollback point: original group or collection membership and deployment configuration.
- Verification contacts on Floor 6 who can test sign-in after the change.

## Procedure
1. Confirm the incident still matches the known pattern.
Action: Validate that users are on Legal Floor 6 and symptoms are login failure, slow sign-in, or heavy workstation performance degradation after the Document Manager deployment window.
Expected result: Incident scope is confirmed as a recurrence of the known pattern rather than a new unrelated outage.

2. Confirm deployment correlation before containment.
Action: Compare the affected-device list to the Document Manager deployment target in Intune or SCCM.
Expected result: Affected devices are confirmed to be inside the current deployment scope, supporting controlled containment.

3. Capture the pre-change state.
Action: Record screenshots or exports of current app assignments or deployments, current group or collection membership, ticket number, operator name, and timestamp.
Expected result: There is a defensible rollback point and evidence package before remediation begins.

4. Stop further required rollout to the impacted Floor 6 scope.
Action: Remove the affected Floor 6 Azure AD device group from Required install in Intune, or disable/delete the Required deployment to the impacted Floor 6 SCCM collection.
Expected result: No additional impacted devices in the scoped Floor 6 population will continue receiving the app as a required deployment.

5. Initiate removal from already impacted endpoints when supported.
Action: If an uninstall command is defined, add the same Floor 6 group to Uninstall assignment in Intune, or create an Uninstall deployment to the impacted SCCM collection.
Expected result: Devices that already received the app begin processing a controlled removal action.

6. Force policy retrieval on impacted endpoints.
Action: On Intune-managed devices, run `Start-Process "C:\Program Files (x86)\Microsoft Intune Management Extension\ClientHealthEval.exe"`. On SCCM-managed devices, run `Invoke-WmiMethod -Namespace root\ccm -Class SMS_Client -Name TriggerSchedule -ArgumentList '{00000000-0000-0000-0000-000000000021}'`.
Expected result: Impacted endpoints check in promptly and pick up the changed assignment or deployment.

7. Monitor execution state for the first validation set.
Action: Track app install status, uninstall status, remediation state, and any failures for at least three affected devices.
Expected result: The first validation set shows policy receipt and either app removal or confirmed cessation of required install.

8. Re-test sign-in and workstation performance with Floor 6 users.
Action: Have at least three affected users sign in again after policy refresh and confirm login duration and post-login responsiveness.
Expected result: Sign-in succeeds within normal expectations and the original performance degradation is no longer reproduced on the validation set.

9. Confirm limited blast radius.
Action: Verify unaffected Floor 6 or adjacent-floor devices that were not in the scoped change remain stable, and confirm no broader business-critical application dependency was introduced by removing the app.
Expected result: Recovery is contained to the intended scope with no new outage created by the fix.

10. Record closure evidence.
Action: Attach deployment-change evidence, sync timestamps, uninstall or deployment status, user verification notes, and any remaining exceptions to the incident.
Expected result: The incident record supports closure or controlled monitoring with evidence.

## Verification
1. The Floor 6 affected-device list matches the deployment scope that was changed.
Expected result: The remediation targeted the right population.

2. Required install is no longer assigned to the impacted Floor 6 scope.
Expected result: Further forced rollout is stopped.

3. If uninstall was used, status reporting shows success or active processing on the validation devices.
Expected result: The removal action is observable and progressing.

4. At least three previously affected users can sign in successfully and report improved performance.
Expected result: The known symptom pattern is no longer reproduced on the validation sample.

5. No high-severity regression is reported for unaffected users or dependent workflows.
Expected result: The containment fix did not create a wider service issue.

## Rollback
Trigger rollback if the app removal causes a business-critical outage, if the wrong scope was modified, or if verification shows the fix path is invalid.

1. Restore the original Required install assignment in Intune or re-enable the original Required deployment in SCCM using the pre-change snapshot.
Expected result: The prior deployment state is restored exactly as captured.

2. Remove the Uninstall assignment or Uninstall deployment if one was created for containment.
Expected result: Endpoints stop processing the temporary removal action.

3. Force policy retrieval again on affected endpoints.
Expected result: Devices receive the restored deployment state promptly.

4. Re-open the incident as containment failed and escalate to Endpoint Engineering, the app owner, and the vendor if applicable.
Expected result: Alternate diagnosis and fix planning continue under active incident control.

## Closure Artifacts
- Ticket or change record showing who modified the deployment and when.
- Pre-change and post-change assignment or deployment evidence.
- Endpoint sync evidence and status results for the validation set.
- User verification notes for sign-in recovery.
- Residual-risk statement if root-cause confirmation remains provisional.