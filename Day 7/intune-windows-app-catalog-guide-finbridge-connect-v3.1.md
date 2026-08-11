# DWP Step-by-Step Guide: Add a Windows App to Intune Catalog (Pre-Rollout)

## Purpose
Use this guide to add a Windows application to the Intune app catalog before any phased rollout begins.

Worked example used throughout:
- Application: FinBridge Connect v3.1
- Package type: Windows LOB app packaged as `.intunewin`
- Install command: `FinBridgeConnect_Setup.exe /silent`
- Uninstall command: `FinBridgeConnect_Setup.exe /uninstall /silent`
- Detection method: Registry key
- Detection value: `HKLM\SOFTWARE\FinBridge\Connect\Version = 3.1`

> Important UI note: Intune and Entra UI labels can vary by tenant version, licensing, and portal updates. Follow the path provided here, but always verify labels in your live tenant before proceeding.

---

## 1. Where to Add an App in Intune

1. Sign in to Microsoft Intune admin center.
2. Go to **Apps** > **Windows** > **Add**.
3. In **Select app type**, choose the app type that matches your package:
   - **Windows app (Win32)** for a `.intunewin` package (this is the correct type for FinBridge Connect v3.1).
   - **Microsoft Store app (new)** for apps sourced from Microsoft Store.
   - **Web link** for URL shortcuts published to users/devices.
4. Confirm you selected the intended type before uploading content.

UI variance flag:
- Some tenants show **Apps** > **All apps** > **Add** first, then app type selection.
- Some tenants label Win32 as **Windows app (Win32)** or similar. Verify in your tenant and do not rely on wording alone.

---

## 2. Create the Windows LOB App (Win32/.intunewin)

### Step 2.1 - Start the app creation flow
1. Select **Windows app (Win32)**.
2. Upload the `.intunewin` package for FinBridge Connect v3.1.
3. Continue to the app configuration pages.

UI variance flag:
- The upload page can be titled **App package file**, **Program**, or similar depending on tenant version.

### Step 2.2 - Complete App Information (required metadata)
1. Enter **Name**: `FinBridge Connect v3.1`.
2. Enter **Description**: Example: `FinBridge Connect desktop client for secure financial workflow connectivity.`
3. Enter **Publisher**: `FinBridge`.
4. Enter **Version**: `3.1`.
5. Add icon/category/owner notes if your DWP standard requires them.

Why this matters:
- These fields define how the app appears in catalog/search and how support teams identify exact versions.

### Step 2.3 - Configure Program (install/uninstall behavior)
1. In **Install command**, enter:
   - `FinBridgeConnect_Setup.exe /silent`
2. In **Uninstall command**, enter:
   - `FinBridgeConnect_Setup.exe /uninstall /silent`
3. Set **Install behavior** (context):
   - **System** context when app needs machine-wide install/admin rights.
   - **User** context only when app is per-user and does not require elevation.
4. For FinBridge Connect v3.1, use **System** unless vendor documentation explicitly states per-user install.

UI variance flag:
- Install context can be labeled **Install behavior**, **Run as**, or **User/System context**.

### Step 2.4 - Configure Requirements
1. Set **Operating system architecture**:
   - Select **Yes. Specify the systems the app can be installed on** and choose `64-bit` for modern enterprise Windows.
   - Do not leave this as **No. Allow this app to be installed on all systems** unless your DWP policy or vendor documentation explicitly supports 32-bit.
2. Set **Minimum operating system**:
   - Match your enterprise baseline (for example, `Windows 10 22H2` or Windows 11 supported build).
3. Save and continue.

Why this matters:
- Prevents assignment to unsupported devices and reduces false failures.

UI variance flag:
- In some tenants the architecture field defaults to **No. Allow this app to be installed on all systems** — always verify this is intentional before proceeding.

### Step 2.5 - Configure Detection Rules (required)
1. In the **Rules format** dropdown, select **Manually configure detection rules**.
   - Do NOT select **Use a custom detection script** — that option requires a `.ps1` file and is not applicable here.
2. Click **+ Add** to add a new rule.
3. Set **Rule type** to **Registry**.
4. Configure detection using:
   - Key path: `HKEY_LOCAL_MACHINE\SOFTWARE\FinBridge\Connect`
   - Value name: `Version`
   - Detection method: String comparison, Equals
   - Value: `3.1`
5. Validate spelling, hive, and value datatype exactly.
6. Click **OK** to save the rule.

Why this matters:
- Intune marks install success based on detection rule results, not only installer exit code.

UI variance flag:
- The path may be shown as `HKLM\...` or `HKEY_LOCAL_MACHINE\...`; both refer to the same hive.

### Step 2.6 - Dependencies
1. You will land on the **Dependencies** tab after Detection rules.
2. This page lists applications that must be installed before FinBridge Connect v3.1 can be installed.
3. For FinBridge Connect v3.1, leave this page empty (**No results**) unless the vendor documentation explicitly lists a prerequisite application.
4. Click **Next** to continue.

Why this matters:
- Only add dependencies if vendor documentation requires them. Adding unnecessary dependencies can block or delay deployment.

---

### Step 2.7 - Supersedence
1. You will land on the **Supersedence** tab after Dependencies.
2. This page is used to replace or update a previously deployed version of the same app.
3. For a first-time deployment of FinBridge Connect v3.1, leave this page empty.
4. Only configure this if you are replacing an older version of FinBridge Connect already deployed in Intune.
5. Click **Next** to continue.

Why this matters:
- Misconfigured supersedence rules can unintentionally uninstall or overwrite apps on devices.

---

### Step 2.8 - Review Return Codes
Return codes are located on the **Program** tab (wizard tab 2), not a separate tab. Scroll down to the **Return codes** section on that page to review them.

1. Navigate back to the **Program** tab if needed.
2. Scroll down to the **Return codes** table.
3. Confirm the following baseline codes are present and correctly mapped:
   - `0` = Success
   - `1707` = Success
   - `3010` = Soft reboot required
   - `1641` = Hard reboot initiated/success with reboot
   - `1618` = Retry
   - Unknown or vendor-specific non-zero codes = Failure unless documented otherwise
4. Add custom return code mappings only when validated in vendor install documentation or packaging test logs.

Why this matters:
- Correct return code handling prevents good installs being reported as failed.

### Step 2.9 - Review and Create
1. Review all pages.
2. Confirm package, commands, requirements, detection, and return codes.
3. Select **Create**.

---

## 3. Assignment Basics (Pilot First)

### Step 3.1 - Understand assignment types
1. **Required**:
   - Intune installs automatically on targeted devices/users.
2. **Available for enrolled devices**:
   - App is shown in Company Portal for optional user install.
3. **Uninstall**:
   - Intune removes the app from targeted devices/users.

UI variance flag:
- Assignment labels can appear as **Required**, **Available**, **Uninstall**, or slightly longer wording in some tenants.

### Step 3.2 - Assign to pilot group first
1. Create/select a small pilot group (for example 10-50 representative devices/users).
2. Assign FinBridge Connect v3.1 to the pilot group first.
3. Do not assign directly to the full 10,000-device fleet.

Why pilot first:
- Limits blast radius if packaging, detection, dependency, or compatibility issues exist.
- Validates install timing, restart behavior, and user impact before scaled rollout.
- Produces real telemetry to tune requirements and detection rules.

### Step 3.3 - Save assignments
1. Add pilot group under **Required** (or **Available** if pilot policy requires user-triggered install).
2. Save assignment changes.

---

## 4. Verification Steps

### Step 4.1 - Confirm app appears correctly in catalog
1. Go to **Apps** > **Windows** (or **All apps**).
2. Search for `FinBridge Connect v3.1`.
3. Open app record and confirm:
   - Name, Publisher, Version
   - Install/uninstall commands
   - Detection rule points to `HKLM\SOFTWARE\FinBridge\Connect\Version = 3.1`
   - Assignment includes pilot group only

### Step 4.2 - Check install status on a test device
1. Pick a device in pilot group.
2. Sync policy on device (Company Portal or Settings sync) if needed.
3. In Intune, open app > **Device install status** (or similarly named status blade).
4. Locate the test device and review state.

UI variance flag:
- Status pages may be labeled **Device install status**, **Monitor**, or split across separate status tabs.

### Step 4.3 - Interpret common statuses
1. **Installed**:
   - App installed and detection rule confirmed expected state.
2. **Failed**:
   - Install process failed or detection did not match expected state after install attempt.
3. **Not applicable**:
   - Device does not meet requirements (OS version/architecture/context) or assignment scope does not apply.

### Step 4.4 - Basic triage if not successful
1. If **Failed**, first verify installer command syntax and return code mapping.
2. Recheck detection rule path/value and data type.
3. Confirm test device meets requirements and received assignment.
4. Review Intune Management Extension logs on test device for detailed error code.

---

## 5. Ready-for-Phased-Rollout Checklist

Complete all checks below before expanding beyond pilot:
1. App metadata is accurate and searchable.
2. Install/uninstall commands run successfully in pilot.
3. Detection rule reliably identifies version `3.1`.
4. Return code handling is validated.
5. Pilot status shows expected install success rate with no critical regressions.
6. Rollout wave plan is approved (pilot -> ring 1 -> ring 2 -> broad deployment).

If any checklist item is incomplete, pause rollout and remediate before adding larger assignment groups.
