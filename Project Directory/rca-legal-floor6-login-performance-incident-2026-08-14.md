# RCA: Legal Floor 6 Login/Performance Incident

## 1) Incident Summary
- Incident: Legal Floor 6 users experienced login failures, slow sign-in, and poor workstation performance.
- Date of triage: 2026-08-14.
- Current state: Suggested resolution was applied and service is reported resolved as of [confirmed time - to confirm].
- Verification statement: [confirmed verification detail - to confirm].

## 2) Scope and Impact (Confirmed vs To Confirm)
### Confirmed
- Floor 6 incident pattern was reported.
- Triage noted at least a dozen impacted users.
- Diagnostic analysis recorded distribution as 12/45 users (~27%), not universal.
- Deployment timing context documented: Friday afternoon deployment; issue onset Monday morning (48-72 hour gap).

### To Confirm
- Exact impacted user count at closure.
- Exact start and end timestamps for user impact window.
- Exact business services/processes impacted by degraded logon performance.
- Whether all affected devices were in the same deployment ring.

## 3) Problem Statement
Users on Legal Floor 6 experienced concentrated sign-in failures/slowness and workstation performance degradation after a Friday deployment window. Initial triage ranked deployment-related endpoint impact as the top hypothesis. Resolution has been reported, but root cause evidence remains partially unconfirmed and requires final corroboration.

## 4) Confirmed Inputs Used for This RCA
- Triage record: triage-B-floor6-login-failures-slow-signin-2026-08-14.md
- Diagnostic ranking: diagnostics-legal-floor6-ranked-causes-2026-08-14.md
- Evidence collector script prepared for endpoint validation: collect-floor6-endpoint-evidence.ps1
- Commented evidence collector copy validated in DryRun: collect-floor6-endpoint-evidence-commented.ps1

## 5) Timeline (All Unknowns Marked)
| Time (Local) | Event | Status |
|---|---|---|
| Friday afternoon (date/time to confirm) | Document management app deployment executed for Legal Floor 6 cohort | Confirmed (deployment occurred); exact timestamp to confirm |
| Monday morning (date/time to confirm) | Users reported slow sign-in/login failures/performance issues | Confirmed (issue onset window); exact first report time to confirm |
| 2026-08-14 (time to confirm) | Major-incident-candidate style triage actions initiated (scope/auth/network/change correlation) | Confirmed (triage plan documented); exact activation time to confirm |
| 2026-08-14 (time to confirm) | Working hypothesis set: deployment conflict/resource contention at login | Confirmed as hypothesis; causal proof to confirm |
| 2026-08-14 11:35 | Evidence collector script DryRun completed successfully | Confirmed |
| 2026-08-14 12:05 | Commented evidence collector DryRun completed successfully | Confirmed |
| [confirmed time - to confirm] | Suggested resolution applied | Reported by incident update; exact action/time to confirm |
| [confirmed time - to confirm] | Service restored and user validation completed | Reported by incident update; exact validation evidence to confirm |

## 6) Supporting Evidence Register
| Evidence Item | What It Shows | Current Status |
|---|---|---|
| triage-B-floor6-login-failures-slow-signin-2026-08-14.md | Initial symptoms, urgency, investigation order | Confirmed |
| diagnostics-legal-floor6-ranked-causes-2026-08-14.md | Ranked hypotheses; top cause = deployment conflict (70%) | Confirmed (hypothesis only) |
| Timing correlation (Friday deployment -> Monday impact) | Temporal association with 48-72 hour gap | Confirmed association; causality to confirm |
| Affected distribution 12/45 | Partial impact, not universal | Confirmed in diagnostic document |
| collect-floor6-endpoint-evidence.ps1 | Read-only evidence capture method for endpoint corroboration | Confirmed artifact exists |
| DryRun outputs (11:35 and 12:05) | Collector execution validity and planned artifacts | Confirmed |
| Intune assignment evidence (recipient match vs affected users) | Confirms or refutes direct deployment causation | To confirm |
| Endpoint event evidence (AppMan/Security/GroupPolicy/Profile) | Confirms logon contention mechanisms tied to deployment | To confirm |
| Before/after metric comparison (CPU/logon time) | Quantifies contention and recovery | To confirm |
| Remediation command history/change ticket | Validates exact fix and rollback scope | To confirm |

## 7) Root Cause Assessment
### Current RCA Position
- Provisional root cause: Deployment-related endpoint contention during login caused by Friday document management app change path.
- Confidence level: Medium (resolved after suggested action reported, but central-system corroboration remains to confirm).

### Why Not Final-Confirmed Yet
- Final correlation artifacts (Intune/SCCM assignment records, affected-device parity, and key event IDs before/after fix) are not yet attached in this RCA package.

## 8) Five-Why Analysis
1. Why did users on Legal Floor 6 experience login failures/slowness and poor performance?
- Because login-time endpoint processing likely became resource-heavy or blocked for a subset of users (to confirm with endpoint event and process evidence).

2. Why did login-time processing become resource-heavy/blocked?
- Because a newly deployed document management component or associated policy/script likely executed during sign-in and contended for CPU/profile/auth workflows (to confirm).

3. Why did only a subset (12/45) appear affected?
- Likely due to scoped deployment targeting, conditional policy assignment, user/profile differences, or device-state variance (to confirm).

4. Why was this not detected pre-incident?
- Pre-deployment validation likely did not fully test Monday first-logon behavior under Floor 6 production conditions (to confirm).

5. Why did triage initially rely on hypothesis instead of immediate proof?
- Endpoint and central telemetry correlation required additional evidence collection and cross-team log access, so hypothesis-led triage was used first (confirmed process pattern; exact evidence latency to confirm).

## 9) Corrective Actions Taken
### Confirmed
- Incident triage prioritized scope, identity, network, policy, and deployment-correlation checks.
- Resolution action was applied and service was reported restored [time/details to confirm].
- Read-only evidence collector was prepared and validated in DryRun for consistent data capture.

### To Confirm
- Exact remediation action executed (for example: Intune ring removal, uninstall assignment, SCCM deployment disablement, or equivalent).
- Exact list of devices/users included in remediation.
- Exact validation method used to confirm recovery (sample size, pass criteria, duration observed).

## 10) Preventive and Follow-Up Actions
1. Change Control Hardening
- Require ring-based deployment with explicit legal-floor pilot gate and automated rollback criteria.
- Status: To confirm owner/date.

2. Pre-Production Login Performance Testing
- Add synthetic first-logon tests and profile initialization checks for Windows 10/11 before broad rollout.
- Status: To confirm owner/date.

3. Assignment Drift and Scope Validation
- Pre-approve device/user group membership snapshots before deployment and compare post-deployment.
- Status: To confirm owner/date.

4. Mandatory Telemetry Bundle at Go-Live
- Capture AppMan, GroupPolicy operational, User Profile Service, Security auth metrics for first 24 hours.
- Status: To confirm owner/date.

5. Incident Runbook Standardization
- Use collect-floor6-endpoint-evidence.ps1 on at least one affected and one unaffected device for rapid differential diagnosis.
- Status: Confirmed available; operational adoption to confirm.

6. Closure Evidence Checklist
- Do not close as final root cause until assignment records, event correlation, and post-fix stability window are attached.
- Status: To confirm implementation in incident process.

## 11) Residual Risk
- If root-cause proof remains incomplete, similar symptom recurrence could occur on future waves or related policy/app updates.
- Risk level: Medium (to confirm after final evidence review).

## 12) Final Closure Statement
- Operational outcome: Issue reported resolved as of [confirmed time - to confirm], with user validation [confirmed verification detail - to confirm].
- RCA status: Provisional conclusion supports deployment-related login/performance contention, pending final evidence attachment from endpoint and management-plane telemetry.
- Next mandatory step: Complete confirmation package (Intune/SCCM assignment and before/after event correlation) before converting this RCA from provisional to final.
