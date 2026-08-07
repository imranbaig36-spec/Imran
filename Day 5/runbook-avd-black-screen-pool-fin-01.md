# Title: AVD POOL-FIN-01 Black Screen After Login Runbook
# Version: 1.0
# Date: 07/08/2026
# Author: Sathishbabu
# reviewed: self
# status: draft
# change: initial version from RCA

# Runbook: AVD POOL-FIN-01 Black Screen After Login

**Incident pattern covered:** Users log in to AVD pool `POOL-FIN-01` and receive a black screen after authentication. Some sessions recover after about 30 seconds. Other sessions require reconnect. This runbook is based on the confirmed incident where an updated Intel GPU driver in the pool image caused `dwm.exe` crashes.

**Primary fix path:** Roll back the `POOL-FIN-01` image to the last known good image version `build-20240313`, then reimage affected session hosts.

---

## 1. Prerequisites

Complete this checklist before starting work.

### Access Checklist

- [ ] Azure Portal access to the correct subscription.
- [ ] Azure role with permission to view and modify Azure Virtual Desktop host pools, session hosts, and VM resources. `[ELEVATED PERMISSIONS]`
- [ ] Permission to place session hosts in drain mode by changing `Allow new sessions`. `[ELEVATED PERMISSIONS]`
- [ ] Permission to reimage, restart, or redeploy the affected session hosts or scale set instances. `[ELEVATED PERMISSIONS]`
- [ ] Permission to view image or scale set configuration for the affected pool. `[ELEVATED PERMISSIONS]`
- [ ] Permission to sign in to an affected session host for Event Viewer log review. `[ELEVATED PERMISSIONS]`
- [ ] Permission to view Azure Monitor activity logs if image or host actions need confirmation. `[ELEVATED PERMISSIONS]`

### Tools Checklist

- [ ] Azure Portal is accessible from your admin workstation.
- [ ] Remote desktop access method is available for the affected session host.
- [ ] Event Viewer is available on the affected session host.
- [ ] PowerShell with Az modules is available if a portal action fails or needs scripting.
- [ ] Incident ticket, bridge, or work notes are open so every action and timestamp can be recorded.

### Mandatory Information From The End User Or Service Desk

- [ ] Affected username in `domain\username` or UPN format.
- [ ] Time of the latest failed sign-in attempt.
- [ ] Whether the user saw a full black screen, a partial desktop, or a disconnect.
- [ ] Whether the black screen cleared after about 30 seconds or remained stuck.
- [ ] Whether the user was disconnected automatically or had to reconnect manually.
- [ ] Device and client used to connect, such as AVD desktop client, web client, thin client, or company laptop.
- [ ] Screenshot or wording of any error message if one was shown.
- [ ] Confirmation that the user is targeting `POOL-FIN-01` and not another pool.
- [ ] Names of at least two affected users if available, so post-fix validation is possible.

### Mandatory Environment Information

- [ ] Azure subscription name.
- [ ] Resource group name for `POOL-FIN-01`.
- [ ] Host pool name `POOL-FIN-01`.
- [ ] Comparison host pool name `POOL-FIN-02`.
- [ ] Current image version assigned to the affected session hosts.
- [ ] Last known good image version. For this incident, use `build-20240313`.
- [ ] Name of at least one affected session host.
- [ ] Contact route for impacted users before drain mode or reimage starts.

---

## 2. Procedure

1. Open Azure Portal and go to `Azure Virtual Desktop` > `Host pools` > `POOL-FIN-01`. `[ELEVATED PERMISSIONS]`
   Expected result: The overview page for `POOL-FIN-01` is open.

2. Open `POOL-FIN-01` > `Session hosts`.
   Expected result: The list of session hosts in the affected pool is visible.

3. Select a session host that shows an active or recently active affected user session.
   Expected result: You have the exact session host name that handled a black-screen user.

4. Record the selected session host name in the incident notes.
   Expected result: The host name is saved for later validation and evidence collection.

5. Connect to the selected session host using your approved admin remote access method. `[ELEVATED PERMISSIONS]`
   Expected result: You are signed in to the affected session host desktop.

6. Open `Event Viewer` on the host.
   Expected result: The Event Viewer console is open.

7. In Event Viewer, go to `Windows Logs` > `Application`.
   Expected result: The Application log is displayed.

8. Select `Filter Current Log...` in the Application log actions pane.
   Expected result: The filter dialog for the Application log is open.

9. Enter `1000` in the `Includes/Excludes Event IDs` field.
   Expected result: The filter is set to return only Application Error events.

10. Set the `Logged` time filter to cover the incident window starting from the first reported failure.
   Expected result: The filtered view shows only Event ID `1000` entries from the relevant time period.

11. Open the newest matching Event ID `1000` entry.
   Expected result: The event detail window for the latest Application Error is open.

12. Confirm the `Faulting application name` is `dwm.exe`.
   Expected result: The event confirms Desktop Window Manager crashed.

13. Confirm the `Faulting module name` is `igdumd64.dll`.
   Expected result: The event matches the known Intel GPU driver failure pattern.

14. Return to Event Viewer and go to `Windows Logs` > `System`.
   Expected result: The System log is displayed.

15. Select `Filter Current Log...` in the System log actions pane.
   Expected result: The filter dialog for the System log is open.

16. Enter `9009` in the `Includes/Excludes Event IDs` field.
   Expected result: The filter is set to return Desktop Window Manager exit events.

17. Set the `Logged` time filter to the same incident window used in the Application log.
   Expected result: The System log now shows DWM failures from the same time period.

18. Open the newest matching Event ID `9009` entry.
   Expected result: The event detail window confirms a Desktop Window Manager exit close to the user login time.

19. Return to Azure Portal and go to `Azure Virtual Desktop` > `Host pools` > `POOL-FIN-02` > `Session hosts`.
   Expected result: The comparison pool session host list is open.

20. Check whether `POOL-FIN-02` session hosts show normal availability and no matching user complaints.
   Expected result: `POOL-FIN-02` appears healthy, which supports that the issue is isolated to `POOL-FIN-01`.

21. Return to Azure Portal and go to the Azure resource that controls the `POOL-FIN-01` session host image, such as the VM scale set or image assignment object used by your environment. `[ELEVATED PERMISSIONS]`
   Expected result: The current image source used to build or reimage `POOL-FIN-01` session hosts is visible.

22. Record the currently assigned image version in the incident notes. `[ELEVATED PERMISSIONS]`
   Expected result: The current image version is documented before any change is made.

23. Record `build-20240313` as the approved rollback image in the incident notes.
   Expected result: The exact target image for rollback is documented before execution.

24. Send the user-impact notification for drain and reimage to the affected support channel or user group.
   Expected result: Impacted users have been warned that sessions may disconnect or require reconnection.

25. Go to `Azure Virtual Desktop` > `Host pools` > `POOL-FIN-01` > `Session hosts` and open the first affected session host. `[ELEVATED PERMISSIONS]`
   Expected result: The selected session host details page is open.

26. Set `Allow new sessions` to `No` on that host. `[ELEVATED PERMISSIONS]`
   Expected result: The selected host is in drain mode and will not accept new sessions.

27. Repeat the `Allow new sessions = No` change for each affected `POOL-FIN-01` session host. `[ELEVATED PERMISSIONS]`
   Expected result: All affected hosts are in drain mode.

28. Refresh the `Session hosts` list for `POOL-FIN-01`.
   Expected result: The host list shows the affected hosts with `Allow new sessions` disabled.

29. Wait until no new user sessions are being created on the drained hosts.
   Expected result: Session counts stop increasing on drained hosts.

30. Change the image reference from the current version to `build-20240313` in the Azure resource that controls `POOL-FIN-01` session host deployment. `[ELEVATED PERMISSIONS]`
   Expected result: The deployment source now points to the known good image.

31. Save the image reference change in Azure Portal. `[ELEVATED PERMISSIONS]`
   Expected result: Azure confirms the image configuration update was accepted.

32. Start a reimage or redeploy action on one drained affected session host as the canary host. `[ELEVATED PERMISSIONS]`
   Expected result: The canary host enters a rebuild cycle on the known good image.

33. Refresh `Azure Virtual Desktop` > `Host pools` > `POOL-FIN-01` > `Session hosts` until the canary host returns to `Available` and `Succeeded` or your environment's healthy registered state.
   Expected result: The canary host is back in service and registered successfully.

34. Connect to the canary host through the normal AVD sign-in path using a test account.
   Expected result: The desktop loads on the first attempt without a black screen.

35. Open `Event Viewer` on the canary host and go to `Windows Logs` > `Application`.
   Expected result: The Application log is open on the rebuilt host.

36. Filter the Application log for Event ID `1000` for the time period after the canary rebuild.
   Expected result: Only post-rebuild application crashes, if any, are displayed.

37. Confirm there are no new Event ID `1000` entries where `dwm.exe` faults on `igdumd64.dll` after the canary test sign-in.
   Expected result: The known driver crash is no longer occurring on the canary host.

38. Start reimage or redeploy actions on the remaining drained affected session hosts. `[ELEVATED PERMISSIONS]`
   Expected result: The rest of the affected hosts begin rebuilding on the known good image.

39. Refresh `Azure Virtual Desktop` > `Host pools` > `POOL-FIN-01` > `Session hosts` until all rebuilt hosts return to a healthy registered state.
   Expected result: All rebuilt hosts show as available for service.

40. Set `Allow new sessions` to `Yes` on each rebuilt healthy host. `[ELEVATED PERMISSIONS]`
   Expected result: The restored hosts can accept user sessions again.

41. Ask at least two previously affected users to sign in to `POOL-FIN-01`.
   Expected result: Users reach a usable desktop on the first attempt.

42. Record the final image version, host status, and validation outcome in the incident notes.
   Expected result: The incident record clearly shows what changed and how the fix was confirmed.

---

## 3. Verification

1. Open Azure Portal and go to `Azure Virtual Desktop` > `Host pools` > `POOL-FIN-01` > `Session hosts`. `[ELEVATED PERMISSIONS]`
   Expected result: The current session host list for `POOL-FIN-01` is visible.

2. Confirm every restored host shows `Available` in the `Status` column.
   Expected result: No restored host shows unavailable, shutdown, or upgrade-related unhealthy status.

3. Confirm every restored host shows `Allow new sessions` as `Yes`.
   Expected result: Healthy hosts are open to accept user connections.

4. Select one restored host and note its session count.
   Expected result: You have a baseline session count for validation.

5. Ask one previously affected user to sign in to `POOL-FIN-01` through the normal AVD client path.
   Expected result: The user reaches the desktop on the first attempt.

6. Refresh `Azure Virtual Desktop` > `Host pools` > `POOL-FIN-01` > `Session hosts`.
   Expected result: One or more restored hosts show active sessions increasing normally.

7. Ask a second previously affected user to sign in to `POOL-FIN-01` through the normal AVD client path.
   Expected result: The second user also reaches the desktop on the first attempt.

8. Connect to one restored host using your approved admin remote access method. `[ELEVATED PERMISSIONS]`
   Expected result: You are signed in to a rebuilt session host for post-fix log verification.

9. Open `Event Viewer` on the restored host.
   Expected result: The Event Viewer console is open.

10. In Event Viewer, go to `Windows Logs` > `Application`.
   Expected result: The Application log is displayed.

11. Select `Filter Current Log...` in the Application log actions pane.
   Expected result: The Application log filter dialog is open.

12. Enter `1000` in the `Includes/Excludes Event IDs` field.
   Expected result: The Application log is filtered to Application Error events only.

13. Set the `Logged` time filter to start at the time the first rebuilt host was returned to service.
   Expected result: Only post-remediation Application Error events are displayed.

14. Review the filtered Application events for entries where the `Faulting application name` is `dwm.exe` and the `Faulting module name` is `igdumd64.dll`.
   Expected result: No new matching driver crash events are present after remediation.

15. In Event Viewer, go to `Windows Logs` > `System`.
   Expected result: The System log is displayed.

16. Select `Filter Current Log...` in the System log actions pane.
   Expected result: The System log filter dialog is open.

17. Enter `9009` in the `Includes/Excludes Event IDs` field.
   Expected result: The System log is filtered to Desktop Window Manager exit events only.

18. Set the `Logged` time filter to the same post-remediation period.
   Expected result: Only post-remediation DWM failures, if any, are displayed.

19. Review the filtered System events for new Desktop Window Manager exit events after user validation sign-ins.
   Expected result: No new Event ID `9009` entries are present after remediation.

20. Open Azure Portal and go to `Azure Virtual Desktop` > `Host pools` > `POOL-FIN-02` > `Session hosts`.
   Expected result: The comparison pool host list is visible.

21. Confirm `POOL-FIN-02` still shows normal host availability and no related user-impact reports in the incident channel.
   Expected result: The issue remains isolated to `POOL-FIN-01` and no wider platform fault is active.

22. Record the successful user sign-ins, host status, and clean log findings in the incident notes.
   Expected result: The closure evidence clearly shows the service is restored.

Do not close the incident until Steps 2, 3, 6, 7, 14, 19, and 21 all succeed.

---

## 4. Rollback

Use this section if the remediation work causes reduced capacity, registration failures, or broader login failures.

1. Open Azure Portal and go to `Azure Virtual Desktop` > `Host pools` > `POOL-FIN-01` > `Session hosts`. `[ELEVATED PERMISSIONS]`
   Expected result: The affected host list is visible and ready for immediate containment.

2. Set `Allow new sessions` to `No` on any host that still shows black-screen behavior or failed post-fix validation. `[ELEVATED PERMISSIONS]`
   Expected result: New users cannot land on unstable hosts.

3. Leave `Allow new sessions` as `Yes` on any rebuilt host that passed validation. `[ELEVATED PERMISSIONS]`
   Expected result: Healthy capacity remains available to users.

4. Go to the Azure resource that controls the `POOL-FIN-01` session host image, such as the VM scale set or image assignment object used by your environment. `[ELEVATED PERMISSIONS]`
   Expected result: The current image source configuration is open.

5. Change the image reference from `build-20240313` back to the image version recorded before remediation. `[ELEVATED PERMISSIONS]`
   Expected result: The pool deployment source is restored to its previous value.

6. Save the image reference change in Azure Portal. `[ELEVATED PERMISSIONS]`
   Expected result: Azure confirms the image configuration update was accepted.

7. Return to `Azure Virtual Desktop` > `Host pools` > `POOL-FIN-01` > `Session hosts` and select one failed canary or failed rebuilt host. `[ELEVATED PERMISSIONS]`
   Expected result: One failed host is selected for rapid rollback validation.

8. Start a reimage or redeploy action on that single failed host. `[ELEVATED PERMISSIONS]`
   Expected result: The selected host starts rebuilding against the restored image reference.

9. Refresh the `Session hosts` page until the rebuilt rollback host returns to `Available` and `Succeeded` or your environment's healthy registered state.
   Expected result: The host is back online and registered.

10. Ask a previously affected user or test account to sign in through the normal AVD client path.
    Expected result: The user either reaches the desktop normally or reproduces the failure immediately.

11. Connect to the rebuilt rollback host and open `Event Viewer` > `Windows Logs` > `Application`. `[ELEVATED PERMISSIONS]`
    Expected result: The Application log is open on the rollback validation host.

12. Filter the Application log for Event ID `1000` for the period after the rollback rebuild started.
    Expected result: Only post-rollback application crash events are shown.

13. Check whether new `dwm.exe` crashes referencing `igdumd64.dll` are still being logged.
    Expected result: You have an immediate yes or no answer on whether the rollback state is safe.

14. Reimage the remaining failed hosts only if Step 10 succeeds and Step 13 is clean. `[ELEVATED PERMISSIONS]`
    Expected result: The rollback proceeds only when the single-host validation passes.

15. Escalate to the image engineering or platform team immediately if Step 10 fails or Step 13 shows new `igdumd64.dll` crashes.
    Expected result: The incident is handed off with proof that the current rollback target does not restore service.

16. Keep one failing host in drain mode without further rebuild attempts for evidence collection. `[ELEVATED PERMISSIONS]`
    Expected result: A reproducible host remains available for deeper driver or image analysis.

---

## 5. Notes

- This runbook applies when `POOL-FIN-01` is affected and `POOL-FIN-02` is unaffected after an image update.
- The confirmed fault pattern is `dwm.exe` crashing with faulting module `igdumd64.dll` and follow-on Desktop Window Manager failures.
- The incident can appear intermittent because some users recover after 30 seconds or on a later reconnect attempt.
- Do not treat intermittent recovery as a successful fix; the defective driver can still be present.
- If both pools are affected, stop using this runbook as the primary path and investigate domain-wide, profile-wide, or platform-wide causes.
- If Event ID `1000` is present but the faulting module is not `igdumd64.dll`, collect the new module name and reassess before reimaging the pool.
- If host registration fails after reimage, keep the host drained and troubleshoot AVD agent registration separately before returning it to service.
- Related incident source: AVD POOL-FIN-01 black screen incident resolved by image rollback after defective Intel GPU driver deployment.
- Preventive follow-up from the RCA: maintain a known-defective-driver list, validate driver changes before production rollout, and use canary deployment for future image updates.