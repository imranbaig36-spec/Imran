Technical Action

Working hypothesis only: Friday Document Manager deployment is causing login-time resource contention. Evidence confirmation status: to confirm.

If confirmed, execute one of the following containment actions immediately.

Option A: Intune (Microsoft Endpoint Manager)
1. Go to Apps > Windows > Document Manager app > Properties > Assignments.
2. Remove the affected Floor 6 Azure AD device group from Required install.
3. Add the same group to Uninstall assignment (if uninstall command is defined).
4. Save and force policy sync for impacted devices.
5. Monitor Device install status and per-device app remediation state.

PowerShell sync command on affected endpoint:
Start-Process "C:\Program Files (x86)\Microsoft Intune Management Extension\ClientHealthEval.exe"

Permissions required: Intune Administrator or equivalent app assignment rights (elevated permissions: yes).

Option B: SCCM (MECM)
1. Open Configuration Manager Console > Software Library > Applications > Document Manager.
2. Deploy action:
- Disable or delete Required deployment to Floor 6 device collection, and/or
- Create Uninstall deployment to Floor 6 impacted collection.
3. On collection: right-click > Client Notification > Download Computer Policy.
4. Track deployment status in Monitoring > Deployments.

Client policy refresh command on endpoint:
Invoke-WmiMethod -Namespace root\ccm -Class SMS_Client -Name TriggerSchedule -ArgumentList '{00000000-0000-0000-0000-000000000021}'

Permissions required: SCCM Full Administrator or delegated Application Deployment Manager rights (elevated permissions: yes).

Notes to confirm during execution:
- Exact app identifier/package ID (to confirm).
- Whether uninstall command is preconfigured for Document Manager (to confirm).
- Exact affected device collection/group membership (to confirm).

Floor Message

We are actively investigating this morning’s Floor 6 login and performance issues and are now isolating affected computers from the recent app rollout while we collect evidence. This is a precaution to reduce impact while we confirm root cause. If you still have slow sign-in, failed login, or missing shortcuts, please contact Service Desk and include your computer name and screenshot if possible. You can continue working where possible; we will share updates as soon as we verify the next step.