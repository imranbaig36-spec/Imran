# Diagnostic Analysis: Legal Floor 6 Missing Shortcuts — Ranked Root Causes

## Timing Context
- **Deployment**: Document management app, Friday afternoon
- **Issue onset**: Monday morning (48-72 hour gap)
- **Scope**: 1 reported user so far; floor-wide scope to confirm
- **Correlated incident**: Login/performance issue affecting 12/45 users on same floor, same morning

---

## Ranked Causes (Most to Least Probable)

### 1. Document Management App Deployment Script / Post-Install Actions
**Probability: Highest (60%)**

**Why this fits the scope facts:**
- Timing coincidence is very strong (Friday deployment → Monday shortcuts gone)
- App installers frequently include post-install scripts that modify user profiles: cleanup, registry, shell customization
- Script could have:
  - Removed legacy shortcuts as part of "profile cleanup"
  - Reset start menu / desktop as part of app provisioning
  - Run with elevated privileges, affecting all user profiles on device
- Gap of 48-72 hours is plausible if script ran asynchronously or on device restart
- Partial user impact (1 reported, others unknown) could reflect:
  - Only this user had desktop shortcuts in certain location or format app targeted
  - This user's device was in specific state (sleep, restart cycle) when script ran
  - App only targets users matching specific criteria (role, group, licensing)

**Fastest confirmation check:**
- On affected user's device: Open `Event Viewer` → `Applications and Services Logs` → `Microsoft-Windows-AppMan/Admin`. Look for app installation/execution events Friday afternoon through Monday morning.
- Check `C:\ProgramData\[AppName]\` and `HKEY_LOCAL_MACHINE\Software\[AppName]` for post-install script logs or cleanup records.
- Compare app deployment configuration in Intune or app vendor documentation: Does app include profile/desktop cleanup steps?
  - **If script logs found**: App deployment is cause
  - **If no evidence of app-driven removal**: Rules out app script as cause

---

### 2. Intune Policy Deployment (Profile Cleanup / Start Menu Reset Policy)
**Probability: High (25%)**

**Why this fits the scope facts:**
- Windows 11 post-migration often includes Intune policies for start menu reset, profile cleanup, or default app assignment
- Policy could have been deployed Friday evening or Saturday and executed on device restart/logon Monday morning
- Partial user impact (1 reported) could reflect:
  - Policy targets specific user group; this user is member of that group
  - Policy targets devices by OS version; this user's device was updated over weekend
  - Profile load timing issue on this device specifically
- Intune policy can include registry/file deletion commands affecting user shell

**Fastest confirmation check:**
- On affected user's device: Open `Event Viewer` → `Windows Logs` → `System`. Filter for Policy (Group Policy Application or Intune) events Friday evening through Monday morning. Look for errors or policy deployments.
- Run `gpresult /h report.html` (command prompt, admin) to generate group policy result report. Review "Applied Group Policy Objects" for any start menu, profile, or shell policies applied in last 72 hours.
- Query Intune: Which policies targeted this user's device over Friday-Monday window? Do any include profile/start menu/shortcuts modifications?
  - **If policy errors or cleanup policies found**: Intune policy is cause
  - **If clean policy logs**: Rules out policy as cause

---

### 3. User Profile Corruption / Incomplete Profile Load from Win11 Migration
**Probability: Moderate (15%)**

**Why this fits the scope facts:**
- Legal Floor 6 recently migrated to Windows 11; user profile migration from Win10 can fail partially
- Shortcuts stored in `%USERPROFILE%\Desktop` and registry; migration can leave profile in inconsistent state
- Shell restart on login Monday could have triggered profile cleanup or rejection of corrupted data
- Partial impact (1 user) is consistent with profile migration issue affecting specific user rather than all
- 48-72 hour gap could represent: migration process running in background, profile sync delay, or shell restart after policy enforcement

**Fastest confirmation check:**
- On affected user's device: Check if `%USERPROFILE%\Desktop` folder exists and is accessible. Run `dir %USERPROFILE%\Desktop` in command prompt (admin). Are `.lnk` files physically present?
- Check Event Viewer → `Windows Logs` → `Application` for profile load errors, SVCHOST errors, or shell failures Friday-Monday.
- Query Intune enrollment history for this user: Did device report any enrollment errors, remediation actions, or policy reapplication during Friday-Monday window?
  - **If desktop folder corrupt or files deleted but no profile error logs**: Migration artifact
  - **If profile errors present**: Profile corruption is cause
  - **If profile logs clean**: Rules out this cause

---

## Connection to Login/Performance Issue — Shared Root Cause Analysis

### Possible Shared Root Cause: YES, plausible
**Reasoning for connection:**
- **Same trigger event**: Both issues appeared after Friday document management app deployment
- **Same time window**: Both discovered Monday morning (48-72 hour gap allows for async or restart-triggered events)
- **Both affect user profile/authentication stack**: 
  - Login issue = credential/authentication/logon script failure
  - Shortcuts issue = profile file system / shell config loss
- **Same underlying failure mode**: App deployment or policy failure could corrupt user profiles differently:
  - User A: Profile auth/logon script broken → login fails
  - User B: Profile desktop/shell data deleted → shortcuts missing
  - User C: Profile unaffected → no issue
- **Deployment scope uncertainty**: App deployed to 45 users; login affected 12, shortcuts affected 1 (so far). Different manifestations of same systemic profile corruption.

**Key question to determine connection**: 
- Is the affected user who reported missing shortcuts **the same person** as any of the 12 users with login issues?
  - **If YES**: Same user, likely same root cause (shared profile corruption from deployment)
  - **If NO, but both in same cohort**: Different users, same deployment, suggests deployment failure is systemic but manifestation varies by user

### Possible Independence: Also plausible
**Reasoning for independence:**
- **Different scope**: Login issue affects 27% of floor (12/45); shortcuts issue affects 1 user (2%). Different scope suggests different failure modes.
- **Different failure signature**: Authentication failure vs. file deletion are distinct system behaviors; less likely to share single root cause
- **Independent timing within window**: Both could happen Friday-Monday without being related. App deployment could affect auth; user action or separate issue could delete shortcuts.
- **User action possible**: User could have manually deleted desktop shortcuts; coincidental timing with deployment

---

## Recommendation: Test for Connection

**Before treating as independent issues, confirm:**

1. **Is this the same user as one of the 12 login-issue users?**
   - If YES → Likely shared root cause; treat as systemic deployment failure
   - If NO → Still could be connected or independent; proceed to step 2

2. **Are any of the 12 login-issue users also reporting missing shortcuts?**
   - If YES → Strong evidence of connection
   - If NO → Likely independent issues

3. **Do other Legal Floor 6 users report missing shortcuts?**
   - If YES → Systemic issue; correlate with app deployment scope
   - If NO → Likely isolated to this one user; could be independent issue or user-specific profile state

**If connection is confirmed**: Escalate as single systemic incident tied to Friday app deployment; audit all 45 Legal Floor 6 users for both login and profile integrity issues.

**If independence confirmed**: Handle as separate incidents; login issue is higher priority (27% impact); shortcuts issue is lower priority (1 user, self-service recovery possible via restart or shortcut recreation).

---

## Next Investigation Steps (Priority Order)

1. **Immediate**: Confirm whether missing-shortcuts user is among the 12 login-issue users (identifies if same incident or two incidents)
2. **Parallel**: Restart device (fastest check for both issues; profile reload may restore shortcuts; login issue behavior may change)
3. **If issues persist after restart**: 
   - Execute fastest checks for causes #1 and #2 (app script logs, Intune policy)
   - If evidence found in both, shared root cause likely confirmed
   - Escalate to app vendor and Intune admins
4. **If only shortcuts persist**: Profile corruption likely; may require manual recovery or profile reset

---

## Connection Summary Statement

**Explicit assessment**: These issues **could plausibly share a root cause** (app deployment or policy failure affecting user profiles differently) **but should not be assumed connected without evidence**. 

- **Supporting connection**: Same deployment trigger, same time window, both affect profile stack, partial floor-wide impact
- **Against connection**: Different scope (27% vs. 1%), different failure mode (auth vs. file system)
- **Determining factor**: Whether affected user is same person or in same deployment cohort

Treat initially as potentially connected; confirm with user identity and scope verification before deciding whether to investigate as single systemic issue or two independent issues.
