# Diagnostic Analysis: Legal Floor 6 Login Issue — Ranked Root Causes

## Timing Context
- **Deployment**: Friday afternoon
- **Issue onset**: Monday morning (48-72 hour gap)
- **Distribution**: 12/45 users (~27%), not universal

---

## Ranked Causes (Most to Least Probable)

### 1. Document Management App Deployment Conflict
**Probability: Highest (70%)**

**Why this fits the scope facts:**
- Deployment timing → issue onset is too coincidental (Friday afternoon → Monday morning)
- Partial user impact (27%) suggests selective deployment or conditional trigger (app may only affect users meeting certain criteria: licensing, role, profile type)
- New applications on Windows 11 + Intune stack frequently cause authentication credential caching, logon script, or LSASS conflicts
- 48-72 hour gap could represent: app service activation delay, overnight Intune policy processing, or weekend background update completion

**Fastest confirmation check:**
- Query Intune device enrollment: Which users on Legal Floor 6 received the document management app deployment? Does affected user list match deployment scope exactly?
  - **If match**: App is primary suspect
  - **If no match**: Eliminates app as direct cause

**Evidence to confirm app deployment as cause:**
- Affected users' event logs show app installation/service start ≤ 2 hours before login failure
- Unaffected users on same floor did NOT receive app deployment
- Disabling or uninstalling app resolves login time for at least 3 affected users
- App process or service log shows elevation request or credential/token handling errors at time of login failure

---

### 2. Intune Policy Enforcement (Weekend Sync/Group Policy Processing)
**Probability: High (20%)**

**Why this fits the scope facts:**
- Windows 11 post-migration often has unresolved Intune policy conflicts; weekend policy reapplication is common trigger
- Partial impact (27%) suggests policy targets a specific user group or device category (e.g., specific security group, device model, enrollment profile)
- Recently migrated environment may have conflicting on-premises vs. cloud policy
- 48-72 hour gap aligns with weekend Intune sync cycles and Monday group policy refresh

**Fastest confirmation check:**
- On one affected device: Open `Event Viewer` → `Windows Logs` → `System`. Filter for Policy (Gp or Intune) events between Friday afternoon and Monday morning. Look for error codes or policy application failures.
  - **If Intune policy errors present**: Policy conflict suspected
  - **If clean policy logs**: Rules out policy as primary cause

**Evidence to confirm Intune policy as cause:**
- Policy application errors in device event logs Friday evening–Monday morning
- Affected users all share a common Intune group or enrollment profile
- Policy rollback or remediation resolves login issue
- Unaffected users have different policy assignment

---

### 3. Network Authentication / DNS Resolution (Floor-Specific)
**Probability: Moderate (10%)**

**Why this fits the scope facts:**
- Windows 11 DNS/network authentication issues can be localized to physical location or subnet
- Recently migrated devices may have stale DNS or network profile settings
- Partial impact could reflect devices on specific network segment or recent reboot status
- Could be coincidental timing (network maintenance occurred Friday, effects discovered Monday)

**Fastest confirmation check:**
- On one affected device: Open `Command Prompt` (admin) and run `nslookup`, `nbtstat -R`, and `ipconfig /all`. Verify DNS servers, network adapter settings, and domain controller reachability.
- Compare results to one unaffected device on same floor.
  - **If DNS/DC resolution differs or fails**: Network auth issue likely
  - **If identical**: Rules out network as cause

**Evidence to confirm network/DNS as cause:**
- Affected devices cannot resolve domain controller hostnames
- Unaffected devices on same floor have working DNS resolution
- Network adapter settings differ between affected/unaffected
- Flushing DNS cache or restarting network adapter resolves issue

---

## App Deployment — Confirmation/Elimination Framework

**Evidence that CONFIRMS app deployment as cause:**
1. Affected user list is exact subset of app deployment recipients
2. App installation/service startup timestamp precedes login failure by <4 hours
3. App process error logs show auth-related failures (credential provider, LSASS, Kerberos errors)
4. Unaffected users have no app deployment record
5. Uninstalling app from 3 affected devices resolves login issue within 1 hour

**Evidence that ELIMINATES app deployment as cause:**
1. Affected users did NOT receive app deployment
2. App deployed to 100+ users across multiple floors; only 12 on Legal Floor 6 affected
3. App installation completed successfully; no errors in app or system logs
4. Same app version deployed to pilot floor last week with zero login issues

---

## Next Investigation Step
Validate cause #1 (app deployment scope) within 15 minutes using Intune query. This has highest probability and fastest elimination path. If app deployment scope matches affected user list exactly, escalate to application vendor and Intune admins for compatibility testing. If no match, pivot to cause #2 (policy logs).
