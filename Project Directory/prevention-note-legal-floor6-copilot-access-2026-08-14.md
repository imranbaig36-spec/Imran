## Prevention Note: Legal Floor 6 Copilot Access Incident
**Date: 14 August 2026**

### Incident Summary
A member of the Legal Floor 6 team gained access to a client document in Copilot that their role and assignment should not have permitted. This was detected when the user reported the unauthorized access.

---

### Preventive Control Required

**Mandatory pre-deployment peer review of all access grants to client matters in Copilot.**

**Specificity:**
- **What:** Before any change that grants a user access to one or more client matters is deployed to the Copilot production environment, an independent team member (different from the person making the change request) must review and approve the assignment.
- **When:** At the point of change deployment — not after the fact, not retrospectively.
- **Who:** The reviewer must be someone with knowledge of Legal team staffing and client matter assignments (e.g., a team lead or access governance administrator).
- **Check:** The reviewer must confirm that the user's role and current assignment justify access to each specific client matter being granted.
- **Documentation:** The review decision and reviewer identity must be logged in the change record.

---

### Why This Would Have Caught It

Under this control, the unauthorized access grant would have been questioned during the review step before it was deployed. A peer reviewer with knowledge of the Legal team's structure would have caught the mismatch between the user's role and the client matter access being assigned.

---

### Assumption / To Confirm

This prevention note assumes the unauthorized access resulted from a change or configuration decision (rather than a system defect). The exact technical cause of the access being granted should be confirmed before finalizing this control implementation.

---

## Issue 2: Legal Floor 6 Login Performance Incident

### Incident Summary
Legal Floor 6 users experienced login failures, slow sign-in, and workstation performance degradation following a Friday afternoon document management app deployment. The issue onset occurred Monday morning (48–72 hour gap). Approximately 27% of floor users (12 of 45) were affected, suggesting the deployment was scoped to a subset of devices.

---

### Preventive Control Required

**Mandatory synthetic first-logon performance test in production-equivalent environment before broad floor rollout of any endpoint application deployment.**

**Specificity:**
- **What:** Before deploying any application that executes during login (including post-install scripts, policy-driven automation, or profile initialization changes) to a production floor cohort, the application must be tested in a test environment that mirrors the target floor's user profile type, Windows version, Intune/SCCM policy state, and typical device state (to confirm specifics of production-mirror requirements).
- **Test scenario:** Perform a minimum of three cold first-logon tests with performance timing capture (logon duration, CPU/disk utilization during sign-in window).
- **Pass/fail criteria:** Logon time must not exceed [baseline for floor - to confirm], and no signs of resource contention (CPU sustained >80%, profile service delays, or policy application timeout).
- **When:** Before the deployment is approved for floor-level rollout; if pilot ring has not been approved yet, testing occurs pre-pilot.
- **Documentation:** Test results (timestamp, device config, logon times, resource metrics) must be logged in the change record and remain visible until 30 days post-deployment.

---

### Why This Would Have Caught It

This control would have revealed the deployment-related logon contention during testing before Monday morning production impact. The 48–72 hour gap between Friday deployment and Monday impact suggests a first-logon scenario (weekend/end-of-week logoff, Monday morning logon). A synthetic first-logon test on Monday or in the test environment prior to floor rollout would have surfaced the performance degradation.

---

### Assumption / To Confirm

This prevention note assumes the login performance issue was caused by the Friday document management app deployment (deployment-related endpoint contention during logon is the top hypothesis at 70% confidence per diagnostic ranking). Final confirmation of root cause requires Intune/SCCM assignment records, affected-device parity, and Windows event log correlation to be attached to the RCA.

---

## Issue 3: Legal Floor 6 Missing Desktop Shortcuts Incident

### Incident Summary
A Legal Floor 6 user reported missing desktop shortcuts discovered Monday morning, following a Friday document management app deployment. The issue appeared 48–72 hours after deployment. Current scope is one confirmed user; broader scope impact is to confirm.

---

### Preventive Control Required

**Mandatory pre- and post-deployment shortcut baseline validation gate for any application deployment that includes post-install scripts or policy modifications affecting user profiles.**

**Specificity:**
- **What:** For any application deployment that includes a post-install script or Intune/Group Policy change that could modify user desktop, Start menu, taskbar, or user profile artifacts, a baseline inventory of shortcuts must be captured before deployment and compared after deployment on pilot devices.
- **Pre-deployment:** Document all shortcuts present on a pilot test device in the same profile state as production users (to confirm profile type specifics).
- **Post-deployment:** Re-run the same inventory immediately after deployment and after first user logon on the same pilot device.
- **Comparison:** Flag any deleted, moved, or modified shortcuts for manual review before broad floor rollout.
- **When:** As part of pilot validation, before approval for floor-wide deployment.
- **Documentation:** Baseline inventory, post-deployment inventory, and delta report must be attached to the change record.

---

### Why This Would Have Caught It

This control would have detected the missing shortcuts on the pilot device before floor-wide deployment on Friday, or identified the issue immediately after post-install execution. The 48–72 hour delay suggests either a first-logon script execution (Monday morning) or a scheduled task trigger, both of which would be visible in a post-deployment re-inventory.

---

### Assumption / To Confirm

This prevention note assumes the missing shortcuts were caused by the Friday document management app deployment post-install behavior (deployment-related post-install action is the top hypothesis at 60% confidence per diagnostic ranking). Final confirmation requires Intune/SCCM deployment history, endpoint event logs around the Friday and Monday timeframe, and a before/after shortcut inventory from the affected user's device.
