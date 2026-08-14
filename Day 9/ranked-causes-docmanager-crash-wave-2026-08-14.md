# Ranked Likely Causes: DocManager Crash Wave (to confirm)

## Scope Facts Used
- Symptom: wave of app crashes (primarily `DocManager.exe`), alongside DEX score drop and rise in disk I/O
- Who: `Legal-Win11` device group (45 devices)
- Since: both DEX and crash rate degraded starting mid-morning today; normal earlier in day
- Change: Document Manager `v2.1` deployed this morning to all 45 devices; 0 install failures
- Baseline: previous `v2.0` stable for 6 weeks
- Device mix: some devices have 8GB RAM, others 4GB RAM
- Vendor note: `v2.1` has known limitation with high disk I/O and intermittent crashes on lower-RAM devices during first few post-install hours while indexing completes

## Ranked Causes (Most Probable First)

### 1) v2.1 post-install indexing defect on lower-RAM endpoints (to confirm)
**Why this fits**
- Timing matches exactly: issues start shortly after `v2.1` deployment.
- Symptom match is direct: vendor calls out high disk I/O + intermittent crashes.
- Population fit: 4GB RAM devices are explicitly higher risk.
- Broad deployment to all 45 devices explains wave behavior.

**Fastest confirm/eliminate check**
- Correlate `DocManager.exe` crash rate and disk I/O by RAM tier (4GB vs 8GB) within first 1-4 hours after install.

### 2) General `v2.1` runtime regression affecting all hardware profiles (to confirm)
**Why this fits**
- Strong temporal coupling to new version and abrupt break from long `v2.0` stability.
- Successful installation does not guarantee runtime stability.
- Could explain crashes on both 4GB and 8GB devices if bug is in shared execution path.

**Fastest confirm/eliminate check**
- Compare crash signatures (exception code/module/fault offset) across affected devices regardless of RAM.

### 3) v2.1 background activity causing resource-pressure-triggered crashes (to confirm)
**Why this fits**
- Scope explicitly includes rising disk I/O and DEX decline, consistent with endpoint stress.
- Mixed RAM fleet can create paging pressure that amplifies I/O and destabilizes app.
- Aligns with “first few hours after install” behavior.

**Fastest confirm/eliminate check**
- On a representative affected endpoint, verify crash timestamps align with peaks in page faults, commit pressure, and disk active time.

### 4) Legal-Win11 group-specific policy/environment interaction exposed by `v2.1` (to confirm)
**Why this fits**
- Incident currently scoped to one device group, suggesting possible environment-specific interaction.
- New version may trigger code paths sensitive to group policies/profile/storage configuration.
- Lower probability than vendor-noted issue, but still plausible.

**Fastest confirm/eliminate check**
- Compare same `v2.1` post-install window in a non-Legal Win11 cohort to see if crash/I/O pattern reproduces.

### 5) Legal data-state effect (large/complex document corpus) increasing first-run indexing load (to confirm)
**Why this fits**
- Heavier legal document sets can intensify first-run indexing I/O.
- Explains DEX drop and elevated crash pressure during post-upgrade indexing window.
- Compatible with prior `v2.0` stability and new `v2.1` behavior.

**Fastest confirm/eliminate check**
- Correlate crash frequency/time-to-first-crash with indexed data volume/profile size across affected devices.

## Weighting Note
The timing clue strongly prioritizes rollout-linked causes. The vendor-documented limitation is the top lead, but remains **to confirm** until telemetry validates RAM-tier and time-since-install correlation.
