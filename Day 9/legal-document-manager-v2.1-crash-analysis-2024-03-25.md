# Legal Document Manager v2.1 Crash Spike - Technical Analysis

Date: 2024-03-25  
Analyst: DWP Operations

## 1) Incident Scope Facts (from provided data)

- Affected device group: **Legal-Win11**
- Fleet size: **45 devices**
- Hardware mix:
  - **27 devices** with 8GB RAM
  - **18 devices** with 4GB RAM
- DEX baseline before deployment:
  - 08:00 DEX score 91, app crash rate 0.1%, disk I/O normal
  - 09:00 DEX score 90, app crash rate 0.2%, disk I/O normal
- Deployment event:
  - 09:38:20 deployment started for **Legal Document Manager v2.1**
  - 09:44:07 install completed on **45 of 45 devices**
  - 09:44:07 install result: **Success, 0 failures**
- Post-deployment degradation:
  - 10:00 DEX score 58, app crash rate 6.2%, disk I/O high
  - 11:00 DEX score 55, app crash rate 6.8%, disk I/O high
- Top crashing process in the 10:00-11:00 window: **DocManager.exe**
  - Accounted for **74% of all crashes** in that window
- Vendor release note for v2.1:
  - New auto-save feature
  - Known limitation: on devices with under 8GB RAM, auto-save indexing can cause high disk I/O and intermittent crashes during the first few hours after installation while the initial index builds

## 2) Correlated Timing View

| Time | Source | Event | Correlation |
|---|---|---|---|
| 08:00 | Nexthink DEX | Normal score and crash rate | Pre-change baseline for Legal-Win11 |
| 09:00 | Nexthink DEX | Still normal | No evidence of an active crash issue before deployment |
| 09:38:20 | SCCM | Deployment of Legal Document Manager v2.1 started | Change point begins |
| 09:44:07 | SCCM | Install completed on all 45 devices | Deployment finished successfully |
| 10:00 | Nexthink DEX | Crash rate jumps to 6.2%, disk I/O high, score drops to 58 | First clear post-install degradation window |
| 11:00 | Nexthink DEX | Crash rate increases further to 6.8%, disk I/O still high, score drops to 55 | Ongoing post-install impact while indexing likely continues |

## 3) Ranked Most-Likely Causes (most probable first)

### Cause 1 (Most Probable)
**Legal Document Manager v2.1 auto-save indexing is causing high disk I/O and intermittent crashes during the initial post-install build window.**

Why it fits evidence:
- The crash spike begins immediately after the successful v2.1 deployment.
- Disk I/O changes from normal to high at the same time the crash rate jumps.
- The top crashing process is `DocManager.exe`, matching the newly deployed application.
- The vendor note explicitly describes this failure mode.

Fastest check to confirm/eliminate:
- Compare the start time of `DocManager.exe` crash activity with the deployment window and verify that the same process dominates crash telemetry only after v2.1 rollout.
- Check whether crashes decrease after the first few hours as the initial index completes.

Specific remediation if confirmed:
- Roll back to v2.0 or suspend v2.1 for affected devices until the vendor limitation is addressed.
- Stagger rollout and exclude low-RAM devices from v2.1 until validated.

### Cause 2
**The impact is amplified on 4GB RAM devices, which are in the vendor's stated risk group for v2.1 indexing behavior.**

Why it fits evidence:
- 18 of 45 devices in Legal-Win11 are 4GB RAM systems.
- The vendor note specifically calls out devices with under 8GB RAM.
- A subset of the fleet is therefore known to be at elevated risk of disk I/O saturation and intermittent crashes.

Fastest check to confirm/eliminate:
- Break the DEX crash and performance data down by RAM class if device-level inventory is available.
- Validate whether 4GB devices account for most crashes and the worst DEX score reduction.

Specific remediation if confirmed:
- Block v2.1 on 4GB devices.
- Use phased deployment with hardware-based targeting and post-install performance gating.

### Cause 3
**The deployment succeeded operationally, but no guardrail stopped the change after early telemetry showed abnormal disk I/O and crash behavior.**

Why it fits evidence:
- SCCM shows a clean 45/45 success result, so the problem is not package failure.
- DEX telemetry shows the real issue only after installation completed.
- Without a rollback threshold, the deployment continued long enough for the crash wave to persist.

Fastest check to confirm/eliminate:
- Review deployment monitoring and rollback policy for early warning thresholds on crash rate and disk I/O.

Specific remediation if confirmed:
- Add automated pause/rollback criteria for crash rate and disk I/O spikes after application releases.

## 4) Finalized Working Hypothesis

**Final hypothesis:** Legal Document Manager v2.1 introduced an auto-save indexing path that, during the first few hours after installation, drove high disk I/O and intermittent crashes. The impact was magnified on the 18 devices with 4GB RAM in the Legal-Win11 fleet, producing the sharp post-install DEX degradation and DocManager.exe crash concentration.

## 5) Exact Remediation Steps (if final hypothesis confirmed)

1. Pause further rollout of Legal Document Manager v2.1.
2. If feasible, roll back affected devices to v2.0 or disable the auto-save feature pending vendor guidance.
3. Exclude 4GB devices from any continued v2.1 exposure until stability is proven.
4. Confirm whether the crash rate and disk I/O return to baseline after rollback or feature suppression.
5. Re-test v2.1 on a small pilot of 8GB devices only.
6. Require a performance gate before broader release.

## 6) Verification Checks After Remediation

- Crash telemetry:
  - App crash rate returns from 6.2%-6.8% to near-baseline levels.
  - `DocManager.exe` no longer dominates crash volume.
- Performance telemetry:
  - Disk I/O returns from high to normal.
  - DEX score recovers from the mid-50s back toward the 90 baseline.
- Deployment validation:
  - No repeat spike occurs after the first few hours on pilot devices.

## 7) Preventive Action

1. Add hardware-aware targeting for applications with known low-RAM limitations.
2. Require staged release gates tied to crash rate and disk I/O telemetry for desktop software.
3. Add a fast rollback path for application updates that materially increase crash rate within the first hours after deployment.
4. Validate vendor release notes against fleet inventory before broad deployment.
