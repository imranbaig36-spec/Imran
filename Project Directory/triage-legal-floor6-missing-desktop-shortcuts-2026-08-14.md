# Triage Summary: Legal Floor 6 — Missing Desktop Shortcuts

**Summary**
User on Legal Floor 6 reports all desktop shortcuts have disappeared, occurring the morning after document management app deployment.

**Impact**
- **Who**: One user on Legal Floor 6 (to confirm if issue is isolated to this user or affects others)
- **How many**: 1 confirmed; scope unknown (1 of 45 users on floor — to confirm if others affected)
- **Business urgency**: Moderate — affects user productivity but not blocking critical function; may be isolated issue or symptom of broader profile corruption

**Known facts**
- Affected user: Legal Floor 6
- OS: Windows 11 (recent migration)
- Enrollment: Intune-enrolled
- Issue onset: This morning
- Trigger event: Document management app deployed Friday afternoon
- Symptom: Desktop shortcuts vanished
- Timing gap: Friday afternoon deployment → Monday morning discovery (48-72 hour gap)

**Missing information to gather**
- Is issue affecting only this user or other Legal Floor 6 users?
- Which shortcuts are missing? (All, or specific category such as work apps, OneDrive, Teams, etc.?)
- Are shortcuts missing from desktop only, or from taskbar/start menu as well?
- Has user restarted device since Friday? If yes, when?
- What is user's account type? (Local admin, standard user, delegated admin?)
- Did user manually delete shortcuts, or did they disappear automatically?
- Does user have multiple profiles on this device? (If yes, are shortcuts missing from all profiles?)
- Document management app: Does it include profile reset, cleanup, or shortcut management scripts?
- Intune policy: Any recent policy deployment targeting desktop, start menu, or shortcuts?
- Device restart history: Any unexpected restarts between Friday and Monday?

**Likely category**
- **Primary suspect**: Application deployment side effect (document management app installer or post-install script removed/reset shortcuts)
- **Secondary suspects**: 
  - Intune policy deployment (profile cleanup, Windows 11 start menu reset, shell policy)
  - User profile corruption or partial login (profile fails to load shortcuts)
  - Windows 11 profile migration issue (shortcuts lost during Win11 enrollment)

**First diagnostic step**
1. **Immediate check**: Ask user to restart device and observe if shortcuts return (rules out simple profile load issue)
2. **If shortcuts persist after restart**: 
   - Check Event Viewer on user's device → `Windows Logs` → `Application` and `System` for errors between Friday afternoon and Monday morning
   - Look for profile-related errors, app installer errors, or policy application failures
   - Check `%USERPROFILE%\Desktop` directory: Are shortcut files (.lnk) physically present but hidden, or deleted?
3. **Query Intune**: Confirm document management app deployed to this user; review app deployment script/configuration for any desktop/start menu modification commands
4. If shortcuts reappear after restart: Likely profile loading issue or race condition; monitor for recurrence
5. If shortcuts remain missing: Escalate to app vendor and Intune admins for post-deployment script audit

**Secondary concern**
Consider whether this is isolated user issue or floor-wide issue. If multiple Legal Floor 6 users report missing shortcuts, elevate to critical (systemic app deployment or policy failure). Recommend proactive outreach to other Legal Floor 6 users to determine scope.
