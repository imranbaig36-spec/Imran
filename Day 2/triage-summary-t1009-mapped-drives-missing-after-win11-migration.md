# Ticket T1009 — Mapped Drives Missing After Win11 Migration

---

## Prompt Used

> You are a DWP service-desk analyst writing structured triage summaries. For the ticket below produce: Summary; Impact; Known facts; Missing info to gather; Likely category; First diagnostic step. Do not invent facts — mark anything uncertain as "to confirm". Return only the triage summary.
>
> **Ticket:** After Win11 migration, a Finance user's mapped drives (S: and P:) are missing every morning and must be remapped by hand. Logon script exists but seems not to run reliably post-upgrade.

---

## Triage Summary

**Summary**
Finance user's mapped network drives (S: and P:) are not persisting after logon following a Windows 11 migration. The user is manually remapping each morning. A logon script exists but is not running reliably post-upgrade.

---

**Impact**
- Single user confirmed affected (wider Finance team impact: to confirm)
- Daily productivity disruption — manual remediation required each morning
- Risk of data being saved locally instead of shared drives if user skips remapping

---

**Known Facts**
- Drives affected: S: and P:
- Issue began after Windows 11 migration
- Logon script exists and was previously working
- User is manually remapping as a workaround
- Occurs consistently every morning (i.e. after full logoff/reboot)

---

**Missing Info to Gather**
- Is the logon script GPO-assigned or user-profile-assigned? (to confirm)
- Is the script a .bat, .vbs, or PowerShell script? (to confirm)
- What does Event Viewer (Application/System logs) show at logon? (to confirm)
- Is the user logging on via AVD, VPN, or direct corporate network? (to confirm)
- Has the user's OU or group policy scope changed during the migration? (to confirm)
- Are other Finance users on Win11 experiencing the same issue? (to confirm)
- Is "Always wait for the network at computer startup and logon" GPO enabled? (to confirm)

---

**Likely Category**
Group Policy / Logon Script Execution Failure (post-OS upgrade regression)

---

**First Diagnostic Step**
Run `gpresult /h gpresult.html` on the affected machine and review whether the drive-mapping GPO or logon script is being applied at logon. Check for any "denied" or "not applied" results linked to the Win11 upgrade.

---

## Ranked Likely Fixes

**1. GPO not applying at logon due to slow network / race condition**

- **Why likely:** Windows 11 changed default behaviour around network readiness at logon. If the machine connects to the network after the logon script fires, drives cannot map. This is one of the most common post-Win11 migration regressions.
- **Check:** In `gpresult /h`, look for the logon script GPO showing as applied but with warnings. Also check Event Viewer > Applications and Services Logs > Microsoft > Windows > GroupPolicy for "network not available" errors at logon time.
- **Action if confirmed:** Enable the GPO setting *"Always wait for the network at computer startup and logon"* under Computer Configuration > Administrative Templates > System > Logon.

---

**2. Logon script not executing — PowerShell execution policy blocking it**

- **Why likely:** If the logon script is PowerShell-based, Win11 may have reset or tightened the execution policy, silently preventing the script from running.
- **Check:** On the affected machine run `Get-ExecutionPolicy -List` and confirm the effective policy. Also check Event Viewer > Windows PowerShell log for execution errors at logon time.
- **Action if confirmed:** Set the appropriate execution policy via GPO (Computer Configuration > Windows Settings > Security Settings > Software Restriction Policies or via Set-ExecutionPolicy in a GPO preference). Do not set it manually on the endpoint alone — to confirm which policy scope applies.

---

**3. User moved to a different OU during migration — GPO no longer in scope**

- **Why likely:** Win11 migrations often involve re-imaging or re-joining machines, which can result in the computer or user object landing in a different OU, outside the scope of the drive-mapping GPO.
- **Check:** In `gpresult /h`, confirm whether the drive-mapping GPO appears under "Applied GPOs" or "Denied GPOs". Cross-check the user's current OU in Active Directory against where the GPO is linked.
- **Action if confirmed:** Move the computer or user object back to the correct OU, or extend the GPO link to cover the current OU — to confirm with AD admin before making changes.

---

**4. Drive mapping configured as "Replace" instead of "Update" in Group Policy Preferences** ✅ CONFIRMED FIX

- **Why likely:** If drives are mapped via Group Policy Preferences (GPP) rather than a logon script, a "Replace" action will delete and recreate the mapping each logon — and if it fails silently (e.g. due to timing), the drive is simply absent.
- **Check:** In Group Policy Management, open the relevant GPP drive mapping and check the Action field (Create / Replace / Update / Delete). Also check whether Item-Level Targeting is applied and whether the Win11 device satisfies the targeting filter — to confirm.
- **Action if confirmed:** Change the action to "Update" and review any Item-Level Targeting filters to ensure Win11 devices are included.

---

**5. Logon script path broken — UNC path or SYSVOL reference invalid on Win11**

- **Why likely:** Less common but possible if the logon script references a hardcoded path or legacy SYSVOL share that behaves differently under Win11's updated SMB or credential handling.
- **Check:** Manually run the logon script from a cmd prompt while logged in as the affected user and observe whether drives map successfully and whether any path errors appear.
- **Action if confirmed:** Update the script path references and test. Engage a senior engineer if SYSVOL replication or SMB signing changes are involved — to confirm scope.

---

## Closure Note

Resolved. Cause: Drive mapping GPO preference action was set to "Replace" instead of "Update"; following the Windows 11 migration the replacement was failing silently at logon, leaving S: and P: drives absent each morning. Action: GPO preference drive mapping action changed from "Replace" to "Update" and Item-Level Targeting filters verified to include Windows 11 devices. Preventive: Review all Group Policy Preference drive mapping actions as part of the Windows 11 migration checklist to ensure "Replace" is not used where "Update" is appropriate; include GPP targeting filter validation as a standard post-migration step. User confirmed working.
