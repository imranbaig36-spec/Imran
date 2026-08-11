# End User Communication - Autopilot Enrolment Failure DESKTOP-FB099 (2024-03-15)

## Audience 1 - Non-technical executive
Your device setup experienced a delay during the planned migration on 15 March 2024. DESKTOP-FB099, assigned to FINBRIDGE\rthomas, was unable to complete the automated setup process at 09:18 due to a pre-existing technical record that had not been cleared beforehand. No data was lost. The device was not left in an insecure state beyond the migration window. The issue has been identified, remediation steps are confirmed, and the device will be re-provisioned as a priority. The root cause is a process gap in the migration runbook that is being corrected to prevent recurrence across the programme.

## Audience 2 - Affected end-user (FINBRIDGE\rthomas, non-technical)
We wanted to let you know what happened with your device DESKTOP-FB099 on 15 March. During the planned migration, your device could not complete its automated setup at 09:18 because it still held a record from a previous IT management system that needed to be removed first. This was not caused by anything you did. Your data is safe. To resolve this, the IT team will need to wipe and re-provision your device — you will be contacted to arrange a convenient time. When re-provisioning takes place, you will need to sign in at the setup screen using your FINBRIDGE\rthomas account and allow the process to complete without interrupting it. If you have any questions in the meantime, please contact the Service Desk.

## Audience 3 - Engineer-to-engineer internal note
Incident facts: no data loss, single device scope only (DESKTOP-FB099 / FINBRIDGE\rthomas), failure at 09:18:44 on 2024-03-15. Incident ref: INC-FINBRIDGE-20240315-001.

Root cause: Autopilot enrolment blocked by pre-existing active legacy MDM enrolment (enrolled 2023-11-04, never retired).
- Primary error: 0x80180014 — The device is already enrolled in MDM.
- Secondary error: 0x80070005 — Access Denied on policy push.

Supporting evidence:
1. 09:18:44 — EnrolmentState: Failed, ErrorCode: 0x80180014. MDM service rejected Autopilot flow due to active legacy enrolment.
2. 09:19:01 — PolicyManager attempted to push 4 profiles regardless; all failed with 0x80070005. FailedProfile: FinBridge-Win11-Security-Baseline. ProfilesApplied: 0 of 4.
3. 09:19:45 — ComplianceEngine aborted: EvaluationResult: Could not evaluate. Reason: Enrolment not complete.
4. DeviceInfo confirmed: MDMEnrolled: Yes (previous enrolment), EnrolmentSource: Legacy (2023-11-04).
5. Licensing, network, TPM, Secure Boot, and Azure AD join all confirmed healthy — eliminated as contributing factors.

Exact action required (ordered):
1. Intune Admin Center: Devices → All devices → locate DESKTOP-FB099 record with enrolment date 2023-11-04 and source Manual/Legacy → Delete → wait 5–10 minutes.
2. Confirm FinBridge-Autopilot-Standard profile is assigned to a group containing DESKTOP-FB099 or rthomas.
3. Intune Admin Center: Devices → All devices → DESKTOP-FB099 → Wipe (leave enrolment state retention unchecked).
4. Device-side (physical or KVM): complete Autopilot OOBE, sign in as rthomas, allow provisioning to finish without interruption.
5. Verify: enrolment source = Autopilot, all 4 profiles = Succeeded, compliance = Compliant. Run dsregcmd /status to confirm AzureAdJoined: YES and correct MDMUrl.

Config/detail context:
1. Device: DESKTOP-FB099. Assigned user: FINBRIDGE\rthomas.
2. Legacy enrolment date: 2023-11-04. Autopilot profile: FinBridge-Autopilot-Standard.
3. OS build at failure: Windows 11 22621.2861.
4. Error codes: 0x80180014 (enrolment block) and 0x80070005 (policy access denied).

Preventive actions needed:
1. Run pre-migration estate audit immediately: export Intune devices filtered by enrolment source = Manual and enrolment date before Autopilot programme start; cross-reference against remaining migration queue.
2. Update Autopilot migration runbook with mandatory Gate 0 pre-flight check: confirm no existing MDM enrolment record before triggering Autopilot on any device.
3. Create dynamic Azure AD device group to surface legacy-enrolled devices as a standing pre-migration filter.
4. After each migration batch, validate all devices show enrolment source = Autopilot; any Manual/Legacy source post-migration requires rework.
