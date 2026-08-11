# Windows 11 Intune Compliance Policy Translation (DWP)

Date: 2026-08-11  
Scope: Translate security baseline requirements into Microsoft Intune Compliance Policy settings for Windows 10/11 devices.

## Quick Start (New Engineer Walkthrough)

Use this when you are on the wizard shown in your screenshot:
- **Windows 10/11 compliance policy** with steps:
  - **1 Basics**
  - **2 Compliance settings**
  - **3 Actions for noncompliance**
  - **4 Assignments**
  - **5 Review + create**

### Step 1: Basics
- **Name**: `DWP-W11-Compliance-Baseline-N-1`
- **Description**:
  `Enforces DWP Windows 11 baseline compliance: BitLocker, Secure Boot, Firewall, OS minimum build (10.0.22621.2861), credential requirement, and applicable device integrity checks. Grace period is 7 days.`
- **Platform**: Windows 10 and later (preselected)
- **Profile type**: Windows 10/11 compliance policy (preselected)

### Step 2: Compliance settings
On your screen, expand each section in this order and fill as below.

#### 2.1 Custom Compliance
- Action: Leave unconfigured for this baseline unless DWP has a custom JSON/script-based compliance requirement.
- Why: None of the 7 required controls depend on Custom Compliance in your current scope.

#### 2.2 Device Health
- Set **BitLocker** requirement to **Require**.
- Set **Secure Boot** requirement to **Require**.
- Set **Code integrity / Device security posture** options to default unless specifically mandated by DWP baseline add-on.
- If present, set **Jailbroken devices** to **Block**.

Notes for Device Health:
- If "Jailbroken devices" is missing in Windows template, treat as not applicable on Windows and continue.
- In some tenants, BitLocker/Secure Boot can appear under **System Security** instead of **Device Health**; set them there if shown in that section.

#### 2.3 Device Properties
- Set **Minimum OS version** = **10.0.22621.2861**.
- Leave **Maximum OS version** blank unless DWP change control explicitly requires an upper cap.

#### 2.4 Configuration Manager Compliance
- If your environment is not using ConfigMgr compliance integration, leave this section at default/not configured.
- If co-managed and required by policy, set to require ConfigMgr compliance only after validating all pilot devices report correctly.

#### 2.5 System Security
- Set **Firewall** = **Require**.
- Set **Password required** = **Require**.
- Set **Minimum password length** = **8**.
- If shown, set password type/complexity per DWP standard (alphanumeric or tenant default).

#### 2.6 Microsoft Defender for Endpoint
- Use this section for Defender signal checks that are available in your tenant.
- If available, configure minimum Defender versions according to your patch baseline.

Important for Requirement 4 (Real-time protection):
- If this section does not provide a direct toggle for real-time protection state, enforce it in Endpoint security Antivirus policy:
  - Real-time protection = Enabled
  - Behavior monitoring = Enabled
  - Tamper protection = Enabled (where supported)

#### 2.7 Windows Subsystem for Linux (WSL)
- Leave at default unless DWP has explicit WSL compliance requirements.
- This section is not required to satisfy the 7 baseline controls listed in this document.

#### Step 2 quick validation checklist
Before clicking Next, verify these mandatory controls are set:
1. BitLocker = Require
2. Secure Boot = Require
3. Minimum OS version = 10.0.22621.2861
4. Firewall = Require
5. Password required = Require
6. Minimum password length = 8
7. Jailbroken devices = Block (only if present)

### Step 3: Actions for noncompliance
- Keep default action: **Mark device noncompliant**
- Set **Schedule (days after noncompliance)** = **7**
- Optional (recommended): add notification email action for users at day 0 or day 1

### Step 4: Assignments
- **Include groups**: Start with pilot device/user group first
- **Exclude groups**: Kiosk/shared/lab devices if they follow a different baseline

### Step 5: Review + create
- Confirm all required settings above are present and correct
- Click **Create**

### Post-create validation (important)
1. Sync one pilot device from Intune and from Company Portal.
2. Confirm device shows policy as **Succeeded**.
3. Validate each signal locally (BitLocker, Secure Boot, Firewall, OS build, credential state).
4. Confirm grace period behavior: noncompliance should not hard-fail until day 7.

## Post-assignment validation after a device sync

Use this when policy is already assigned and a test device has just synced.

### 1) Where to see this device status for this specific compliance policy

Path A (start from the policy):
1. Intune admin center -> Devices -> Manage devices -> Compliance -> Policies
2. Open policy: **DWP-W11-Compliance-Baseline-N-1** (or your policy name)
3. Open **Device status**
4. Search the test device name
5. Open the device row to see per-setting results (BitLocker, Secure Boot, OS version, Firewall, password)

Path B (start from the device):
1. Intune admin center -> Devices -> All devices
2. Open the test device
3. Open **Device compliance** or **Compliance policies**
4. Open the same Windows 10/11 compliance policy entry to view status and failing setting detail

### 2) What each status means for Conditional Access impact

- **Compliant**:
  - Device satisfies policy checks.
  - If a Conditional Access policy requires compliant device, access is allowed (subject to other CA controls).

- **Not compliant**:
  - Device failed one or more required checks and is outside grace allowance.
  - If CA requires compliant device, access is blocked for targeted resources.

- **In grace period**:
  - Device currently fails at least one required check, but noncompliance action timer has not expired.
  - Typical behavior: access can continue until grace expires; after expiry status moves to Not compliant and CA block applies.
  - Confirm your tenant CA and compliance action design, as enforcement behavior depends on your exact policy combination.

### 3) BitLocker shows noncompliant but BitLocker is enabled: top 3 false-positive causes and fastest checks

1. Compliance telemetry is stale (sync/reporting lag)
- Why it happens: Device encryption is on, but Intune still shows old state from before encryption completed or before reboot.
- Fastest check:
  - On device: run `manage-bde -status C:` and verify **Protection Status: Protection On**.
  - In Intune: check device **Last check-in** time; trigger **Sync** from device record and Company Portal, then recheck policy status.

2. BitLocker is suspended (common during BIOS/firmware/feature updates)
- Why it happens: Volume is encrypted, but protection is suspended, so compliance can evaluate as failed.
- Fastest check:
  - On device: run `manage-bde -status C:` and confirm protection is not suspended.
  - If suspended, resume with `manage-bde -protectors -enable C:` and reboot, then sync.

3. Device encrypted on OS volume but key protector/TPM state not healthy yet
- Why it happens: Encryption may be present, but protector configuration is incomplete after provisioning, hardware changes, or TPM reset.
- Fastest check:
  - On device: run `manage-bde -protectors -get C:` and confirm protectors exist and are valid.
  - Check TPM health quickly with `tpm.msc` (TPM ready) or `Get-Tpm` in PowerShell.
  - After remediation, reboot and sync.

### First 24-hour monitoring checklist (to catch false positives early)

1. Policy -> **Device status**: count of Not compliant and In grace period for this policy.
2. Policy -> per-setting failure breakdown: verify whether failures cluster on BitLocker only.
3. Device **Last check-in** distribution: many stale check-ins indicate reporting delay rather than true drift.
4. Conditional Access sign-in failures tied to device compliance requirement.
5. Sample validation: manually verify at least 20 flagged devices with `manage-bde -status C:` before changing policy values.

### If a setting is not visible
- First confirm policy is truly **Windows 10/11 compliance policy**.
- Check if the setting moved section (commonly between Device Health and System Security).
- If still unavailable:
  - Enforce through Endpoint security (for RTP and detailed firewall behavior), and
  - Keep compliance policy as the gating layer.

## Policy Scope Assumptions
- Platform: **Windows 10 and later** (applies to Windows 11)
- Policy type: **Compliance policy** (not Configuration Profile / Endpoint Security policy)
- Grace period: **7 days** for all settings via compliance action

## Compliance Actions (Apply to All Settings)

### Action
- **Mark device noncompliant** after grace period

### Value
- **Schedule: 7 days**

### Effect
- Device can remain in a grace period state for 7 days before being marked noncompliant.

### False-positive risk
- Devices that are genuinely remediating (e.g., encryption in progress, pending reboot, delayed MDM sync) may still flip to noncompliant if remediation exceeds 7 days.

### Recommendation
- Keep 7 days for security posture, but add operational controls:
  - Ensure user communications start at day 0 and day 5.
  - Monitor devices in grace state and proactively remediate before day 7.

---

## Requirement Mapping

## 1) Requirement: BitLocker must be enabled on the OS drive

### Settings name
- **Require BitLocker**

### Value
- **Require**

### Effect
- The OS device must report BitLocker drive encryption enabled to be compliant.

### False-positive risk
- Common causes for healthy-appearing devices being flagged:
  - Encryption is enabled but still in-progress (status not yet fully reported).
  - TPM/firmware changes or suspended BitLocker during servicing.
  - Co-management/reporting delay between device and Intune.

### Recommendation
- Keep set to **Require**.
- Reduce false positives operationally by:
  - Forcing a sync after provisioning and after reboot.
  - Using staged rollout to validate telemetry/reporting.
  - Verifying BitLocker state with remediation script before compliance deadline.

### UI path (latest known; may vary by portal updates)
- Intune admin center -> **Devices** -> **Manage devices** -> **Compliance** -> **Policies** -> **Create** -> Platform: **Windows 10 and later** -> **System Security** -> **Require BitLocker**

### UI drift flag
- **Low**: Setting name is stable, but menu labels ("Compliance" vs "Device compliance") can shift.

---

## 2) Requirement: Secure Boot must be enabled

### Settings name
- **Require Secure Boot to be enabled on the device**

### Value
- **Require**

### Effect
- Device must boot with UEFI Secure Boot enabled; devices with Secure Boot off are noncompliant.

### False-positive risk
- BIOS/UEFI mode mismatches (legacy boot mode), firmware bugs, or stale posture data after BIOS updates.

### Recommendation
- Keep set to **Require**.
- Reduce false positives by:
  - Standardizing UEFI mode in hardware baseline.
  - Requiring reboot + sync after firmware updates.

### UI path (latest known; may vary by portal updates)
- Intune admin center -> **Devices** -> **Manage devices** -> **Compliance** -> **Policies** -> **Create** -> Platform: **Windows 10 and later** -> **System Security** -> **Require Secure Boot to be enabled on the device**

### UI drift flag
- **Medium**: Exact wording occasionally changes between "Require Secure Boot" and longer form text.

---

## 3) Requirement: Minimum OS build N-1 (22621.2861)

### Settings name
- **Minimum OS version**

### Value
- **10.0.22621.2861**

### Effect
- Devices must be at or above build 22621.2861 to be compliant.

### False-positive risk
- Devices on equivalent patched states with delayed inventory refresh may briefly report old build.
- Version formatting errors (missing major version prefix) can incorrectly fail.

### Recommendation
- Set exactly to **10.0.22621.2861**.
- Pair with update rings/expedite updates so compliant build is reachable before day 7.
- Document change control for periodic N-1 updates.

### UI path (latest known; may vary by portal updates)
- Intune admin center -> **Devices** -> **Manage devices** -> **Compliance** -> **Policies** -> **Create** -> Platform: **Windows 10 and later** -> **System Security** -> **Minimum OS version**

### UI drift flag
- **Low**: Setting is stable; placement in blade may move slightly.

---

## 4) Requirement: Windows Defender real-time protection must be on

### Settings name
- **Microsoft Defender Antimalware minimum version** *(optional companion, not sufficient alone)*
- **Microsoft Defender Antispyware minimum version** *(optional companion)*
- **Microsoft Defender Antivirus minimum version** *(optional companion)*

### Value
- If used, set minimum signature/engine/platform versions per your patch cadence.

### Effect
- Compliance can enforce Defender component currency, but **Windows compliance policy does not provide a direct "real-time protection = on" toggle** in all tenants.

### False-positive risk
- Relying only on version minimums may pass devices where RTP is disabled but signatures are current.
- Conversely, temporary update-channel delays may mark healthy protected devices noncompliant.

### Recommendation
- **Important adjustment**: Enforce real-time protection in an Endpoint security policy, then use compliance for state gating.
  - Endpoint security -> Antivirus policy:
    - Real-time protection: **Enabled**
    - Behavior monitoring: **Enabled**
    - Tamper protection: **Enabled** (where supported)
- In compliance policy, use Defender minimum versions only if your operations can maintain strict update SLAs.

### UI path (latest known; may vary by portal updates)
- Compliance path (version checks): Intune admin center -> **Devices** -> **Manage devices** -> **Compliance** -> **Policies** -> **Create** -> Platform: **Windows 10 and later** -> **Microsoft Defender Antivirus**
- Enforcement path (RTP on/off): Intune admin center -> **Endpoint security** -> **Antivirus** -> Windows 10 and later policy

### UI drift flag
- **High**: Defender categories and labels have changed across Intune UX revisions and security blade updates.

---

## 5) Requirement: Firewall must be enabled for all profiles

### Settings name
- **Firewall**

### Value
- **Require**

### Effect
- Device must have firewall enabled to be compliant.

### False-positive risk
- Third-party firewall integrations or reporting mismatches can mark compliant devices as noncompliant.
- Short posture lag after profile or security stack changes.

### Recommendation
- Keep set to **Require**.
- If using non-Microsoft endpoint security stack, validate compliance signal mapping before broad rollout.
- Consider companion Endpoint security Firewall policy to enforce domain/private/public profile states explicitly.

### UI path (latest known; may vary by portal updates)
- Intune admin center -> **Devices** -> **Manage devices** -> **Compliance** -> **Policies** -> **Create** -> Platform: **Windows 10 and later** -> **System Security** -> **Firewall**

### UI drift flag
- **Medium**: Some tenants show this under a security subsection with slightly different labels.

---

## 6) Requirement: A PIN or password must be configured

### Settings name
- **Password required**
- **Minimum password length**
- **Password type** *(if available in your tenant/policy template)*

### Value
- **Password required: Require**
- **Minimum password length: 6 or higher** (recommend 8 for enterprise baseline)
- **Password type: Device default / Alphanumeric** per DWP standard

### Effect
- Device requires a local unlock credential (PIN/password) and enforces minimum complexity/length constraints where configured.

### False-positive risk
- Windows Hello for Business PIN state can lag in reporting right after enrollment.
- Shared or kiosk scenarios may intentionally not use user PIN/password in expected pattern.

### Recommendation
- Keep **Password required = Require**.
- To reduce false positives:
  - Exclude kiosk/shared device profiles from this user-facing control set.
  - Align compliance setting with your Windows Hello policy (avoid contradictory complexity rules).

### UI path (latest known; may vary by portal updates)
- Intune admin center -> **Devices** -> **Manage devices** -> **Compliance** -> **Policies** -> **Create** -> Platform: **Windows 10 and later** -> **Device Health** or **System Security** (tenant-dependent) -> password-related settings

### UI drift flag
- **High**: Password/PIN related controls have shifted sections and naming across template versions.

---

## 7) Requirement: Device must not be jailbroken or rooted

### Settings name
- **Jailbroken devices** *(platform capability dependent)*

### Value
- **Block**

### Effect
- Devices detected as rooted/jailbroken are marked noncompliant.

### False-positive risk
- On Windows, this signal may be not applicable or effectively neutral depending on platform implementation.
- Some virtualization or test-lab states can produce ambiguous health signals.

### Recommendation
- If present in your Windows compliance template, set to **Block**.
- If absent/not applicable for Windows, document as **covered by platform constraints** and rely on Defender + Secure Boot + BitLocker + attestation controls.

### UI path (latest known; may vary by portal updates)
- Intune admin center -> **Devices** -> **Manage devices** -> **Compliance** -> **Policies** -> **Create** -> Platform-specific settings

### UI drift flag
- **High**: This control is common on mobile platforms and may not appear for Windows templates.

---

## DWP Engineer Notes: Accuracy and Portal-Drift Advisory
- Paths above were adjusted to match the current navigation style shown in your tenant screenshot: **Devices -> Manage devices -> Compliance**.
- Intune UX labels and policy blade grouping can change. Validate exact paths in your tenant before CAB sign-off.
- The **setting names above are the canonical names typically shown in Windows compliance policy templates**, but some tenants display shortened variants.
- Requirement 4 (real-time protection on) is the key gap if implemented with compliance policy alone; enforce through Endpoint security Antivirus policy for deterministic control.

## Suggested Final Compliance Configuration (At a Glance)
- Require BitLocker = **Require**
- Require Secure Boot to be enabled on the device = **Require**
- Minimum OS version = **10.0.22621.2861**
- Firewall = **Require**
- Password required = **Require**
- Minimum password length = **8** (recommended)
- Jailbroken devices = **Block** (if available for Windows template)
- Compliance action: Mark noncompliant after **7 days**

## Validation Checklist Before Production
- Confirm all settings are available in your specific Windows compliance template.
- Pilot with representative hardware generations and firmware states.
- Validate compliance signal latency and remediation completion within 7 days.
- Confirm Conditional Access impact (grace period vs immediate access block behavior).
