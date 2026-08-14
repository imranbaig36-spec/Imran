# RCA: Legal Floor 6 Missing Desktop Shortcuts Incident

## 1) Incident Summary
- Incident: Missing desktop shortcuts reported on Legal Floor 6.
- Date of triage artifacts: 2026-08-14.
- Current state: Suggested resolution was applied and issue is resolved as of [confirmed time - to confirm].
- Verification statement: [confirmed verification detail - to confirm].

## 2) Scope and Impact (Confirmed vs To Confirm)
### Confirmed
- One Legal Floor 6 user reported desktop shortcuts disappeared.
- Symptom discovered Monday morning.
- Friday afternoon document management app deployment occurred before symptom discovery.
- Timing gap documented as 48-72 hours.
- Environment context in triage: Windows 11 recent migration and Intune enrollment.

### To Confirm
- Whether additional Floor 6 users were affected.
- Final impacted count at closure.
- Whether missing shortcuts were desktop-only versus Start/Taskbar as well.
- Whether issue affected one profile or multiple profiles on the same device.

## 3) Problem Statement
A user on Legal Floor 6 reported missing desktop shortcuts after a recent deployment window. Triage ranked deployment-related post-install behavior as the top hypothesis, but required evidence checks were needed to confirm causation. Resolution has been reported, while some proof points remain to confirm.

## 4) Sources Used (Confirmed Inputs)
- triage-C-missing-desktop-shortcuts-floor6-2026-08-14.md
- triage-legal-floor6-missing-desktop-shortcuts-2026-08-14.md
- diagnostics-legal-floor6-missing-shortcuts-ranked-causes-2026-08-14.md
- collect-floor6-endpoint-evidence.ps1 (prepared evidence-collection method)

## 5) Timeline
| Time (Local) | Event | Status |
|---|---|---|
| Friday afternoon (timestamp to confirm) | Document management app deployed | Confirmed deployment; exact timestamp to confirm |
| Monday morning (timestamp to confirm) | Missing desktop shortcuts reported by Legal Floor 6 user | Confirmed report window; exact first report time to confirm |
| 2026-08-14 (time to confirm) | Triage documented and ranked likely causes | Confirmed |
| 2026-08-14 (time to confirm) | Working hypothesis set: post-install script or policy side-effect | Confirmed as hypothesis; root cause to confirm |
| [confirmed time - to confirm] | Suggested resolution applied | Reported; exact technical step to confirm |
| [confirmed time - to confirm] | User-impact reported resolved | Reported; verification artifacts to confirm |

## 6) Supporting Evidence Register
| Evidence Item | What It Supports | Status |
|---|---|---|
| Triage C note | Incident classification and initial response plan | Confirmed |
| Triage summary (Legal Floor 6 shortcuts) | Scope currently 1 confirmed user, context and unknowns | Confirmed |
| Diagnostic ranked causes | Top hypothesis: app deployment post-install action (60%) | Confirmed as hypothesis only |
| Timing correlation | Friday deployment precedes Monday symptom window | Confirmed temporal correlation; causality to confirm |
| Suggested confirmation checks in diagnostics | AppMan logs, app script logs, policy logs, desktop file presence checks | Confirmed as planned evidence path |
| Evidence collector script | Read-only method to collect endpoint proof | Confirmed available |
| Intune/SCCM action logs for applied resolution | Confirms exact remediation executed | To confirm |
| Before/after shortcut inventory and user validation | Confirms restoration outcome and durability | To confirm |

## 7) Root Cause Assessment
### Provisional Conclusion
- Most likely cause based on ranked diagnostics: document management app deployment post-install action altered or removed shortcut artifacts.
- Confidence: Medium.

### Why Provisional, Not Final-Confirmed
- The triage set strong temporal and technical plausibility, but final confirmation artifacts were not included in the provided evidence set.
- Items still required: management-plane deployment logs, endpoint event correlation around execution window, and before/after shortcut inventory proof.

## 8) Five-Why Analysis
1. Why were desktop shortcuts missing?
- Because shortcut files or shell references were removed/altered, or desktop path/profile state changed (to confirm).

2. Why were files/references removed or altered?
- Most likely a deployment-linked post-install script or policy action executed in the Friday-Monday window (to confirm).

3. Why would that action affect this user and not everyone?
- Possible selective targeting, profile state differences, or execution timing variance across devices (to confirm).

4. Why was this not caught before user impact?
- Pre-deployment validation likely did not include explicit shortcut integrity checks across affected profile types (to confirm).

5. Why did incident response start with hypothesis rather than immediate proof?
- Endpoint and management telemetry correlation had to be gathered first; triage used ranked hypothesis to prioritize checks (confirmed process approach).

## 9) Corrective Actions Taken
### Confirmed
- Incident was triaged with ordered checks for profile state, policy deployment, and deployment correlation.
- Suggested resolution was applied and issue reported resolved as of [confirmed time - to confirm].

### To Confirm
- Exact remediation method used (for example: Intune remediation script, SCCM package, assignment change, or equivalent).
- Exact scope of remediation target group/device list.
- Post-change validation details (who confirmed, how many endpoints checked, duration monitored).

## 10) Preventive Actions
1. Add Shortcut Integrity Gate to App Rollouts
- Pre- and post-deployment checks for desktop shortcut baseline in pilot and first production ring.
- Owner/date: to confirm.

2. Ring-Based Rollout Controls
- Enforce smaller pilot cohorts with explicit hold points before floor-wide deployment.
- Owner/date: to confirm.

3. Post-Install Script Governance
- Require script review checklist for profile/desktop/start-menu modifications.
- Owner/date: to confirm.

4. Automated Evidence Capture Trigger
- On first report, run standardized read-only collector on one affected and one unaffected device for differential analysis.
- Owner/date: to confirm.

5. Policy Change Correlation Practice
- Record Intune/GPO policy deltas for the same window as app deployment to identify combined side effects quickly.
- Owner/date: to confirm.

6. Closure Evidence Standard
- Do not close as final root cause until log correlation and restoration proof are attached to incident record.
- Owner/date: to confirm.

## 11) Residual Risk
- Without final corroboration, recurrence remains possible in future deployment waves.
- Residual risk level: Medium (to confirm after full evidence pack review).

## 12) Final Closure Statement
- Operational outcome: Missing-shortcuts issue reported resolved as of [confirmed time - to confirm], verified by [confirmed verification detail - to confirm].
- RCA status: Provisional conclusion supports deployment-related side effect; final confirmation pending evidence completion.
- Required next step: Attach confirmation artifacts (Intune/SCCM deployment history, endpoint event correlation, and before/after shortcut inventory) to convert this RCA from provisional to final.
