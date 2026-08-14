# RCA - Legal Document Manager v2.1 Crash Spike (Legal-Win11)

Date: 2024-03-25  
Prepared by: DWP Operations

## Executive Summary

A wave of application crashes affected the Legal-Win11 device group after deployment of Legal Document Manager v2.1. Nexthink DEX telemetry shows a stable baseline at 08:00 and 09:00, followed by a sharp degradation at 10:00 and 11:00: DEX score fell from 90-91 to 58-55, crash rate rose from 0.1%-0.2% to 6.2%-6.8%, and disk I/O moved from normal to high. SCCM confirms that v2.1 was deployed successfully to all 45 devices between 09:38:20 and 09:44:07, placing the change directly before the crash spike.

The strongest supported root cause is the vendor-documented v2.1 auto-save indexing behavior, which can cause high disk I/O and intermittent crashes during the first few hours after installation on devices with under 8GB RAM. Because 18 of the 45 Legal-Win11 devices have 4GB RAM, the fleet contains a substantial portion of devices in the known-risk category. `DocManager.exe` accounted for 74% of crashes in the peak window, tying the crash wave to the newly deployed application.

## Scope and Impact

- Affected group: Legal-Win11
- Fleet size: 45 devices
- Hardware mix: 27 devices with 8GB RAM, 18 devices with 4GB RAM
- Symptom: Large increase in app crashes and disk I/O after application rollout
- Business impact: Legal users experienced unstable application behavior during morning work hours
- Unaffected period: 08:00 and 09:00 telemetry remained normal before deployment

## Supporting Evidence

### 1. DEX Telemetry Evidence

| Time | DEX Score | App Crash Rate | Disk I/O | Interpretation |
|---|---|---|---|---|
| 08:00 | 91 | 0.1% | Normal | Baseline condition |
| 09:00 | 90 | 0.2% | Normal | Still stable before deployment |
| 10:00 | 58 | 6.2% | High | First post-install degradation window |
| 11:00 | 55 | 6.8% | High | Degradation persists and worsens |

Additional DEX detail:
- Top crashing process from 10:00-11:00: `DocManager.exe`
- Process share: 74% of all crashes in that window

Interpretation:
- The crash surge is time-aligned with the deployment window, not the earlier baseline.
- High disk I/O appears at the same time as the crash increase.
- The dominant crashing process matches the new application.

### 2. SCCM Deployment Evidence

| Time | Evidence |
|---|---|
| 09:38:20 | Deployment started: Legal Document Manager v2.1 to Legal-Win11 (45 devices) |
| 09:44:07 | Install completed: 45 of 45 devices |
| 09:44:07 | Install result: Success, 0 failures |

Interpretation:
- The rollout succeeded operationally.
- The deployment completed shortly before the crash spike began.
- Package delivery failure is not supported by the evidence.

### 3. Vendor Release Note Evidence

Package details:
- Previous version: Document Manager v2.0
- New version: Document Manager v2.1
- New capability: auto-save feature
- Known limitation: devices with under 8GB RAM can experience high disk I/O and intermittent crashes during the first few hours after installation while the initial index builds

Interpretation:
- The vendor note matches the observed pattern in both timing and symptom type.
- The fleet contains 18 devices in the stated risk class.

## Timeline (from provided data)

- 08:00: DEX baseline is healthy; crash rate 0.1%; disk I/O normal
- 09:00: DEX remains healthy; crash rate 0.2%; disk I/O normal
- 09:38:20: SCCM starts deployment of Legal Document Manager v2.1
- 09:44:07: SCCM reports successful installation on all 45 devices
- 10:00: DEX drops sharply to 58; crash rate jumps to 6.2%; disk I/O is high
- 11:00: DEX drops further to 55; crash rate reaches 6.8%; disk I/O remains high

## Analysis

- The timing is causal-looking, not coincidental: the fleet is stable before the change, then degrades within the first post-install hour.
- The crash signal is concentrated in `DocManager.exe`, which points to the deployed application rather than a generic workstation problem.
- The disk I/O spike is consistent with the vendor's known indexing limitation.
- The low-RAM portion of the fleet is large enough to drive a visible group-level incident.

## 5 Whys

1. Why did Legal-Win11 see a wave of crashes?
- Because `DocManager.exe` crashes increased sharply after the application rollout.

2. Why did `DocManager.exe` start crashing more often?
- Because v2.1 introduced an auto-save indexing path that increases disk I/O during initial build.

3. Why did the issue become visible at the group level?
- Because the crash rate jumped across the fleet shortly after deployment and persisted through the first post-install hours.

4. Why were some devices more exposed than others?
- Because 18 devices in the fleet have 4GB RAM, which falls into the vendor's known-risk category.

5. Why did the bad release reach a broad fleet without early stop?
- Because the deployment completed successfully from SCCM's perspective, but there was no evidence of an automated performance gate to pause the rollout when crash and disk I/O telemetry worsened.

## Final Root Cause Statement

Primary root cause: Legal Document Manager v2.1's auto-save indexing behavior caused high disk I/O and intermittent crashes during the initial post-install period, especially on low-RAM devices, resulting in a fleet-wide crash spike in Legal-Win11.

Contributing factors:
- 40% of the fleet has only 4GB RAM.
- The vendor limitation was present in release notes but not sufficiently gated before broad deployment.
- No rollback threshold is evident from the supplied data.

## Confirmed/Planned Remediation

Immediate recovery actions:
1. Pause further deployment of v2.1.
2. Roll back affected devices to v2.0 or disable the auto-save/indexing behavior if rollback is not immediately possible.
3. Prioritize the 4GB devices for rollback or exclusion.
4. Validate that crash rates and disk I/O return to baseline.

## Verification of Resolution

Success criteria:
- DEX score returns toward the pre-change baseline.
- App crash rate returns to near baseline.
- Disk I/O returns to normal.
- `DocManager.exe` no longer accounts for the majority of crashes.
- The issue does not recur during the first few hours after remediation or pilot re-release.

## Preventive Actions

1. Deployment controls
- Add telemetry-based hold points for crash rate and disk I/O after app updates.
- Require explicit approval for broad rollout when vendor notes mention low-RAM limitations.

2. Hardware targeting
- Exclude 4GB devices from releases that require heavy indexing or caching until validated.
- Prefer phased rollout by hardware class rather than a single all-at-once push.

3. Vendor risk management
- Translate vendor release notes into deployment rules before packaging.
- Maintain a known-issues register tied to fleet inventory profiles.

4. Operational readiness
- Define a rollback threshold for early post-install instability.
- Add a pilot group validation step that includes both 8GB and 4GB device classes only when the release is proven safe for both.

## Notes on Error Interpretation

- The supplied data does not include a numeric application error code.
- This RCA relies on the literal DEX and SCCM evidence and the vendor's written limitation statement.
