# JAMF Configuration Profile Translation: macOS Security Baseline (DWP)

Date: 2026-08-14  
Scope: Translate macOS baseline requirements into JAMF Pro Configuration Profile settings for a 25-device Design team fleet.

## Quick Start (New Engineer Walkthrough)

Use this when creating baseline controls in JAMF Pro for supervised/managed macOS endpoints.

Expected admin flow:
1. Computers -> Configuration Profiles -> New
2. General payload (name, scope, distribution method)
3. Add required payloads (Security and Privacy, Restrictions, Login Window/Passcode equivalent, Software Update)
4. Scope to Design pilot group first
5. Save, deploy, verify device-level status

Recommended profile naming:
- Profile: `DWP-macOS-Baseline-N-1-Design`
- Scope group: `SG-Design-macOS-Prod-25`

## Verification Discipline (Day 6 Intune carry-over)

JAMF payload names, category placement, and option labels can change by JAMF Pro version and Apple management model updates.

Where this document marks **Verification needed**, validate exact labels and paths in your own JAMF instance before CAB sign-off or production rollout.

---

## Baseline Settings Matrix

| # | Baseline requirement | Payload type | Value | Effect | False-positive risk | UI drift flag |
|---|---|---|---|---|---|---|
| 1 | FileVault disk encryption must be enabled | Security and Privacy (FileVault area) or dedicated FileVault payload | Enable FileVault, enforce for users, escrow recovery key to JAMF, minimal deferral | Encrypts local disk data at rest and protects data if device is lost | Encryption may be in progress; user has not completed logout/restart; recovery key exists locally but escrow not yet uploaded | **High - Verification needed** |
| 2 | Gatekeeper must be enabled (identified developers only) | Security and Privacy (Gatekeeper / app execution) | Allow apps from App Store and identified developers only; do not allow Anywhere | Blocks unsigned and untrusted binaries by default while allowing signed developer software | Local prompt behavior during first launch can look like failure; scripts can read stale Gatekeeper state before profile settles | **High - Verification needed** |
| 3 | Minimum macOS version = current stable minus one point release | Restrictions or Software Update policy path plus Smart Group logic | Define minimum allowed macOS version as stable-1 (example: stable 14.6 -> minimum 14.5) | Prevents endpoints from lingering on vulnerable older builds | Inventory lag after upgrade; staged rings intentionally delay updates; "stable" version not updated in policy calendar | **High - Verification needed** |
| 4 | Firewall must be enabled | Security and Privacy (Firewall) | Enable macOS Application Firewall; optional stealth mode per hardening standard | Reduces unsolicited inbound network exposure | Third-party security stack can mask status; temporary manual toggle before next MDM refresh | **Medium - Verify labels** |
| 5 | Login password required after sleep/screen saver | Security and Privacy or passcode/login payload path | Require password immediately after sleep or screensaver (grace 0, or approved short grace) | Prevents unattended session takeover | Telemetry can lag until session refresh; external display wake behavior can delay lock-state updates | **High - Verification needed** |
| 6 | Automatic security updates enabled | Software Update payload (or equivalent updates management section) | Enable automatic security updates, system data file updates, and auto-check/download/install where exposed | Improves patch consistency and reduces manual update dependency | Device offline during maintenance window; update pending reboot; Apple CDN delays and deferred inventory upload | **High - Verification needed** |

---

## Requirement Mapping (Detailed)

## 1) Requirement: FileVault disk encryption must be enabled

### Payload type
- Security and Privacy -> FileVault (or dedicated FileVault payload depending on JAMF version)

### Value
- FileVault: Enabled
- Recovery key escrow: Enabled to JAMF
- Deferral: Keep strict (0-1 deferrals for this baseline unless change advisory approves more)

### Effect
- Startup volume is encrypted and cannot be read without valid unlock credentials or recovery mechanism.

### False-positive risk
- Encryption started but not completed.
- User has not completed required restart/logout cycle.
- Recovery key generated but JAMF inventory has not ingested escrow state yet.

### Recommendation
- Keep FileVault required.
- Add a Smart Group for "FileVault enabled but key not escrowed" to separate telemetry lag from real risk.

### UI path (latest known, verify in tenant)
- JAMF Pro -> Computers -> Configuration Profiles -> [baseline profile] -> Security and Privacy -> FileVault options

### UI drift flag
- **High**: FileVault controls and escrow wording shift across JAMF builds and management model updates.

---

## 2) Requirement: Gatekeeper must be enabled (identified developers only)

### Payload type
- Security and Privacy -> Gatekeeper / app execution controls

### Value
- Permit apps from App Store and identified developers.
- Block "Anywhere" behavior.

### Effect
- Prevents execution of unsigned/untrusted software while preserving signed developer software workflows.

### False-positive risk
- Internal tools signed with nonstandard chains can trigger prompts and look like policy failure.
- Scripted checks can return stale or transitional `spctl` output shortly after profile deployment.

### Recommendation
- Keep policy strict for Design fleet.
- Validate all required creative tools are correctly signed before broad scope expansion.

### UI path (latest known, verify in tenant)
- JAMF Pro -> Computers -> Configuration Profiles -> [baseline profile] -> Security and Privacy -> Gatekeeper

### UI drift flag
- **High**: Gatekeeper labels have varied by macOS generation and JAMF interface updates.

---

## 3) Requirement: Minimum macOS version = current stable minus one point release

### Payload type
- Restrictions and/or Software Update payload path, plus compliance Smart Group criteria

### Value
- Set minimum required macOS to stable minus one point release.
- Example operational rule: if current stable is 14.6, enforce minimum 14.5.

### Effect
- Blocks drift to unsupported builds and aligns fleet to a current patch baseline.

### False-positive risk
- Devices updated recently but inventory still shows previous build.
- Ringed rollouts intentionally hold subset devices behind target temporarily.
- Baseline number not updated after Apple releases new point update.

### Recommendation
- Implement monthly baseline review calendar task.
- Keep a short grace period for update adoption and explicitly document exceptions.

### UI path (latest known, verify in tenant)
- JAMF Pro -> Computers -> Configuration Profiles -> [baseline profile] -> Restrictions or Software Update section (tenant/version dependent)
- JAMF Pro -> Computers -> Smart Computer Groups -> criteria: Operating System Version >= target

### UI drift flag
- **High**: OS enforcement can be split between config profile settings and update policy constructs depending on JAMF version.

---

## 4) Requirement: Firewall must be enabled

### Payload type
- Security and Privacy -> Firewall

### Value
- Firewall: Enabled
- Optional hardening: Stealth mode enabled where compatible with support tooling

### Effect
- Reduces inbound attack surface by enforcing host firewall controls.

### False-positive risk
- Endpoint may report stale status between local change and JAMF inventory cycle.
- Security products can alter reporting interpretation without actual protection loss.

### Recommendation
- Keep required on all Design devices.
- Pair with a Smart Group for firewall disabled signal to trigger rapid triage.

### UI path (latest known, verify in tenant)
- JAMF Pro -> Computers -> Configuration Profiles -> [baseline profile] -> Security and Privacy -> Firewall

### UI drift flag
- **Medium**: Firewall options are usually stable, but sub-option labels can move.

---

## 5) Requirement: Login password required after sleep/screen saver

### Payload type
- Security and Privacy (password requirement behavior) or login/passcode-related payload section

### Value
- Require password after sleep/screensaver.
- Set grace period to immediate (`0`) unless approved exception exists.

### Effect
- Protects active sessions when endpoints are left unattended.

### False-positive risk
- Lock requirement applied but user session has not refreshed.
- Display wake quirks can delay visible lock enforcement or reporting timestamps.

### Recommendation
- Keep immediate lock for security-sensitive users.
- If user friction is high, consider short approved grace with compensating controls and documented exception.

### UI path (latest known, verify in tenant)
- JAMF Pro -> Computers -> Configuration Profiles -> [baseline profile] -> Security and Privacy / passcode-login settings

### UI drift flag
- **High**: Placement and naming vary by payload template and macOS version.

---

## 6) Requirement: Automatic security updates enabled

### Payload type
- Software Update payload (or equivalent update management controls)

### Value
- Enable automatic security response/system data updates.
- Enable automatic check/download/install settings where exposed.
- Keep update behavior aligned to N-1 compliance target.

### Effect
- Improves consistency of patch uptake and shortens exposure window for known vulnerabilities.

### False-positive risk
- Device powered off or offline during update schedule.
- Update installed but reboot pending; compliance still shows old state.
- Apple update channel delays in region cause temporary noncompliance.

### Recommendation
- Set automatic updates on and schedule weekly verification of update backlog.
- Use user comms for reboot prompts to reduce "installed but pending restart" drift.

### UI path (latest known, verify in tenant)
- JAMF Pro -> Computers -> Configuration Profiles -> [baseline profile] -> Software Update

### UI drift flag
- **High**: Software update controls have changed materially across recent JAMF and Apple management evolutions.

---

## Scope and Assignment Guidance (25-device Design Fleet)

1. Start with pilot scope (5 devices), then expand to all 25 after 48-hour validation.
2. Exclude break-glass/admin testing device group from immediate strict lock timing if needed.
3. Use separate profiles for FileVault and Software Update if rollback needs differ from core endpoint hardening.
4. Trigger inventory update after deployment wave to reduce temporary false positives.

---

## Post-Deployment Validation (After Device Check-in)

### Where to verify profile application
1. JAMF Pro -> Computers -> search target Mac -> Profiles tab.
2. Confirm baseline profile status is installed and not pending/failed.
3. Open device details and verify each expected control signal.

### What to verify for each requirement
1. FileVault on and recovery key escrowed.
2. Gatekeeper policy equivalent to identified developers only.
3. OS version at or above defined stable-1 floor.
4. Firewall enabled.
5. Password required on wake from sleep/screensaver.
6. Automatic security updates enabled and recent update check present.

### First 24-hour monitoring checklist
1. Count devices missing profile installation vs fully compliant.
2. Check Smart Group membership spikes for FileVault or OS version failures.
3. Review check-in recency for all 25 endpoints to separate drift from stale telemetry.
4. Validate at least 5 randomly sampled devices locally before changing policy values.

---

## Known Drift and Label Stability Advisory

- Do not treat payload labels in this document as immutable UI strings.
- JAMF Pro UX and payload location can change by version and enrollment model.
- If a label in your tenant differs from this document, preserve the baseline intent (control objective) and map to the nearest equivalent setting.
- Record any tenant-specific label/path deltas in your local DWP runbook after implementation.

## Suggested Final Baseline (At a Glance)

- FileVault: Enabled with key escrow required.
- Gatekeeper: App Store and identified developers only.
- Minimum macOS version: current stable minus one point release.
- Firewall: Enabled.
- Password after sleep/screensaver: Required immediately.
- Automatic security updates: Enabled.

## Engineering note

This translation is intentionally implementation-focused, but exact payload naming should always be validated in your own JAMF instance before production rollout.