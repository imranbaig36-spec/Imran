# DEX Startup Performance — Causal Analysis
**Date:** 2026-08-12
**Device group:** Finance-Win11 (215 devices)
**Analyst:** DWP Endpoint Team

---

## Scope Facts (established before analysis)

- **Device group affected:** Finance-Win11 — 215 devices
- **Change:** New security baseline configuration profile deployed at 02:00 on 2026-08-04 to Finance-Win11 only; included a startup compliance logging script and an additional Defender scan policy
- **Magnitude:** Median startup time increased from 17.5 s (score 84) on 2026-08-03 to 41.3 s (score 61) on 2026-08-04 — a 23.8-second increase and a 23-point score drop, sustained across three subsequent days with no recovery
- **Comparison group:** IT-Win11 (40 devices, no config change applied) remained stable at 16.8–17.1 s (scores 84–85) across the same period, confirming the degradation is specific to the changed group

---

## Ranked Causes

---

### Cause 1 — Startup compliance logging script running synchronously (blocking login)
**Probability: Most likely**

**Why it fits the evidence:**
The startup time metric measures login to usable desktop. A startup script configured to run synchronously executes before Windows hands control to the user, meaning every second the script takes is added directly to the measured startup time. The 23.8-second increase maps precisely to script execution time. The degradation began on exactly the morning of 2026-08-04 — the first boot after the overnight deployment — and has been consistent every day since, which matches a script that runs on every login. The IT-Win11 group received no script and shows no change, eliminating any external factor as the cause.

**Fastest check to confirm or eliminate:**
Open `Event Viewer → Applications and Services Logs → Microsoft → Windows → GroupPolicy → Operational` on an affected Finance device. Look for startup script execution events around login time and note the duration. If a script is logging 20+ seconds of runtime, this is confirmed. Alternatively, review the script itself for synchronous network calls, file writes to a server share, or waits that would explain the duration.

---

### Cause 2 — Additional Defender scan policy triggering a resource-intensive scan at startup
**Probability: Likely**

**Why it fits the evidence:**
The new baseline included an additional Defender scan policy targeting Finance-Win11 only. If that policy schedules or triggers a scan at device startup (e.g. a quick scan on login or an updated real-time protection rule that performs an initial sweep), it will spike CPU and disk usage during the login sequence, delaying the desktop from becoming usable. The 23.8-second increase is consistent with Defender scan activity on a managed device. Again, timing is exact and the comparison group — with no policy change — is unaffected.

**Fastest check to confirm or eliminate:**
On an affected device, open `Windows Security → Virus & threat protection → Protection history` and check whether scans are logged at the time of each login. Cross-reference with `Task Manager → Performance` during a test login to observe whether CPU or disk spikes above 80% in the first 40 seconds. If Defender activity coincides with the slow window, this is confirmed.

---

### Cause 3 — Baseline profile processing overhead delaying policy evaluation at login
**Probability: Possible**

**Why it fits the evidence:**
When a new configuration profile is deployed via Intune or GPO, the device must evaluate and apply new policies at each login until they are fully cached. A complex baseline with multiple new settings, compliance checks, and certificate requirements can add measurable delay to the login sequence. The timing fits — the profile landed overnight on 2026-08-04 — and the Finance-Win11 group is the only target. However, this cause is less likely than the above two because: policy processing overhead typically reduces after the first few logins as settings are cached, whereas the DEX data shows the elevated startup time persisting consistently across three days (59, 60, 61), which points to something executing every login rather than a one-time evaluation cost.

**Fastest check to confirm or eliminate:**
Review `Event Viewer → Applications and Services Logs → Microsoft → Windows → DeviceManagement-Enterprise-Diagnostics-Provider` on an affected device for policy sync duration at login. If processing time drops significantly after day one but startup time remains elevated, this cause is eliminated and focus should shift fully to Causes 1 and 2.

---

## Recommended First Action

Check Cause 1 first. It is the single most direct explanation for a sustained, consistent, per-login delay of this magnitude. Reviewing the script itself and the GroupPolicy event log will take under 10 minutes and will either confirm it or rule it out cleanly before investigating Cause 2.
