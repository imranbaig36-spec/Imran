Technical Action

Working hypothesis only: Friday Document Manager post-install script removed/altered shortcuts. Evidence confirmation status: to confirm.

If confirmed, take containment plus restoration actions.

Option A: Intune remediation (preferred)
1. Intune Admin Center > Devices > Scripts and remediations > Remediations.
2. Deploy a detection script to find missing required shortcuts in:
- C:\Users\*\Desktop
- C:\Users\Public\Desktop
3. Deploy a remediation script to recreate approved shortcuts from a known-good source package.
4. Assign to impacted Floor 6 device group only; run ASAP.
5. Remove or supersede the original post-install script/app assignment causing deletion.

Example restore command in remediation script:
Copy-Item "C:\ProgramData\DWP\ShortcutBaseline\*.lnk" "C:\Users\Public\Desktop\" -Force

Optional per-profile restore (SYSTEM context):
Get-ChildItem "C:\Users" -Directory | Where-Object { $_.Name -notin @('Public','Default','Default User','All Users') } | ForEach-Object { Copy-Item "C:\ProgramData\DWP\ShortcutBaseline\*.lnk" (Join-Path $_.FullName "Desktop") -Force -ErrorAction SilentlyContinue }

Permissions required: Intune Administrator or Endpoint Security Manager with remediation/script assignment rights (elevated permissions: yes).

Option B: SCCM (MECM) package/program
1. Configuration Manager Console > Software Library > Scripts or Packages.
2. Deploy approved restore script/package to impacted Floor 6 device collection.
3. Disable/supersede offending app deployment or post-install program.
4. Trigger client policy refresh and monitor compliance.

Client policy trigger command on endpoint:
Invoke-WmiMethod -Namespace root\ccm -Class SMS_Client -Name TriggerSchedule -ArgumentList '{00000000-0000-0000-0000-000000000021}'

Permissions required: SCCM Full Administrator or delegated app/script deployment rights (elevated permissions: yes).

Items to confirm before execution:
- Exact shortcut baseline (names, targets, icons) and source location (to confirm).
- Exact Document Manager app assignment and post-install script identity (to confirm).
- Whether shortcuts are machine-wide, per-user, or redirected via OneDrive/folder redirection (to confirm).

Floor Message

We are actively working on the missing shortcut issue on Floor 6 and are now restoring standard shortcuts to affected computers while we verify the exact cause. This is a controlled fix to reduce impact. If your shortcuts are still missing after a restart, please contact Service Desk with your computer name and a screenshot of your desktop. We will continue to share updates as we confirm the next steps.