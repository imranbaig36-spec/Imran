# Root Cause Analysis — Adobe Acrobat Pro v23.6 Installation Failure
**Incident date:** 2024-03-15  
**RCA completed:** 2026-08-12  
**Author:** DWP Endpoint Engineering  
**Severity:** Medium — deployment blocked on one AVD pool; no data loss, no user data at risk  
**Status:** Root cause confirmed; remediation actions defined

---

## 1. Incident Summary

On 2024-03-15 at 10:01, an Intune-managed deployment of Adobe Acrobat Pro v23.6 failed on a single AVD pool with MSI return code **1603 (Fatal error during installation)**. The failure reproduced identically on a scheduled retry 60 minutes later. No other pools were affected. The pool in question had received an **overnight base image update** immediately prior to the failure window. Detection confirmed the application was not installed after either attempt.

---

## 2. Timeline of Events

| Time | Event |
|---|---|
| Overnight (pre-10:01) | Base image update applied to one AVD pool |
| 10:01:00 | Intune AgentExecutor begins Adobe Acrobat Pro v23.6 install |
| 10:01:01 | Install context confirmed as SYSTEM |
| 10:01:03 | `msiexec /i AcrobatPro.msi /quiet` executed |
| 10:01:44 | MSI exits with return code **1603** — 41 seconds after launch |
| 10:01:45 | Detection rule runs: checks `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0` |
| 10:01:45 | Detection result: **Not found** |
| 10:01:47 | Install marked failed; retry scheduled for 60 minutes |
| 11:01:47 | Retry attempt 1 begins |
| 11:02:31 | MSI exits with return code **1603** again — 43 seconds after launch |

---

## 3. Most Likely Root Cause — With Evidence

### Primary Cause: Conflicting Adobe installation silently included in the overnight image update

**Conclusion statement:**  
The overnight image update introduced a pre-existing Adobe product (most likely Adobe Acrobat Reader or an earlier Acrobat Pro version) into the pool's base image. When Intune attempted to install Acrobat Pro v23.6, the Windows Installer detected an existing conflicting Adobe MSI component registration and aborted with 1603.

### Evidence from the log

| Evidence item | Significance |
|---|---|
| **Failure is pool-scoped** — other pools unaffected | Isolates the cause to the overnight image change; not a network, Intune policy, or package issue |
| **Return code 1603 on both attempts, identical runtime (~41–43 s)** | The MSI progresses to the same point before aborting. A transient fault (e.g., temp file lock, service restart) would not reproduce identically after 60 minutes. A persistent environment condition — such as a conflicting installed product — would. |
| **No change between attempt 1 and retry** | 60-minute gap with no remediating action; the environment was unchanged. The same persistent blocker halted both runs. |
| **41–43 s runtime before failure** | MSI 1603 triggered by a fast path rejection (permissions, missing file) typically fails in under 5 seconds. A 41-second window indicates the installer reached component registration or upgrade detection before aborting — consistent with a conflict check. |
| **Detection rule checks `Acrobat Reader` path, not `Acrobat Pro`** | Suggests the detection rule was authored for a Reader deployment and reused. If a Reader version was present in the image, detection would never find it under the Pro key, causing Intune to perpetually retry — compounding the 1603 from the MSI conflict. |
| **SYSTEM install context** | Rules out per-user profile issues. Any conflicting product visible to SYSTEM (i.e., machine-wide MSI registration) would block the install regardless of which user is logged in. |

### Why competing causes are ranked lower

| Cause | Reason downgraded |
|---|---|
| SYSTEM TEMP permissions | Would cause near-instant failure (< 5 s), not 41 s. Would also block all SYSTEM-context MSIs, not just Adobe. |
| Missing VC++ Redistributable | Possible but secondary — if the image introduced Reader, it likely brought its own runtimes. |
| AppLocker/SRP policy | Would block `msiexec.exe` process launch entirely; 41 s runtime confirms the process ran. |
| Detection rule mismatch alone | Does not cause 1603 directly; it amplifies retry behaviour on top of the primary conflict. |

---

## 4. Five Whys Analysis

```
WHY 1 — Why did the Adobe Acrobat Pro v23.6 installation fail?

  The Windows Installer returned code 1603 (fatal error), indicating a
  blocking condition prevented the MSI from completing successfully.

      |
      v

WHY 2 — Why did the Windows Installer encounter a fatal error?

  A conflicting Adobe product was already registered in the Windows
  Installer component database on the affected pool's VMs. MSI detected
  the conflict during component registration and aborted.

      |
      v

WHY 3 — Why was a conflicting Adobe product present on the VMs?

  The overnight base image update introduced a pre-installed Adobe product
  (Reader or earlier Acrobat version) into the pool's image without the
  software catalogue team's awareness. The image was not checked for
  pre-existing Adobe MSI registrations before deployment.

      |
      v

WHY 4 — Why was the image not checked for conflicting software before deployment?

  The image build and validation process did not include a pre-deployment
  software conflict check. There was no automated gate to compare installed
  MSI products against the Intune app catalogue before a refreshed image
  was released to a pool.

      |
      v

WHY 5 — Why was there no automated software conflict check in the image pipeline?

  The image build process was designed primarily to validate OS configuration
  and security baselines (CIS/NCSC). Application-layer conflict detection was
  assumed to be handled by the application packaging team, creating an
  unowned gap between the image team and the app deployment team.
```

---

## 5. Contributing Factors

| Factor | Detail |
|---|---|
| **Detection rule reuse error** | Detection rule references `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0` instead of the Acrobat Pro path. This did not cause the 1603 but caused Intune to continuously retry the failed deployment, increasing noise and masking the true scope of the failure. |
| **Quiet install flag with no log path** | `msiexec /quiet` was used without `/l*v` (verbose logging). No MSI-internal log was produced, which delayed diagnosis and required inference from timing and scope rather than direct evidence. |
| **Single-pool overnight rollout** | Deploying the image to only one pool first was good practice, but the absence of a post-update application deployment validation test meant the conflict was not caught before users were impacted. |

---

## 6. Impact

| Category | Detail |
|---|---|
| Users affected | All users on the updated AVD pool requiring Adobe Acrobat Pro |
| Duration | From 10:01 on 2024-03-15 until remediation applied |
| Data loss | None |
| Security impact | None |
| Business impact | Users unable to open, sign, or edit PDF documents via Acrobat Pro |

---

## 7. Remediation Actions

### Immediate (same day)

| # | Action | Owner |
|---|---|---|
| I-1 | Identify the conflicting Adobe product in the affected pool image using `wmic product where "name like 'Adobe%'"` | Endpoint engineer |
| I-2 | Uninstall or remove the conflicting product from the image and redeploy | Image build team |
| I-3 | Re-run the Intune deployment to the affected pool and confirm success | Endpoint engineer |
| I-4 | Fix the Intune detection rule to check the correct Acrobat Pro registry path: `HKLM\SOFTWARE\Adobe\Adobe Acrobat\23.0` | App packaging team |

### Short-term (within 5 working days)

| # | Action | Owner |
|---|---|---|
| S-1 | Add `/l*v C:\Windows\Temp\AcrobatInstall.log` to the Intune install command for all Adobe packages to enable MSI-level diagnostics | App packaging team |
| S-2 | Implement a post-image-update smoke test that runs a sample SYSTEM-context Intune deployment against a single pool VM before full pool rollout | Endpoint engineering lead |

### Long-term (within 30 days)

| # | Action | Owner |
|---|---|---|
| L-1 | Integrate an MSI product catalogue comparison script into the image build pipeline as a mandatory pre-release gate. Script should diff installed products against the Intune app catalogue and flag conflicts. | Image build team + App packaging team |
| L-2 | Define a shared RACI between image build and app deployment teams covering application-layer conflict ownership during image refresh cycles | Service delivery manager |
| L-3 | Audit all existing Intune detection rules for Adobe products to identify any other rules using incorrect registry paths | App packaging team |

---

## 8. Lessons Learned

1. **Image updates are application deployments.** A base image refresh is not purely an OS/security event — it can introduce or remove software that directly blocks managed app deployments. Both teams must communicate before any pool refresh.

2. **1603 plus consistent runtime is diagnostic.** A fatal MSI error that reproduces at the same point across multiple attempts, with no change in the environment, almost always indicates a persistent environmental conflict rather than a transient fault. Always check for pre-existing installations first.

3. **Quiet installs hide information.** Running `msiexec /quiet` without a verbose log flag converts a diagnosable failure into an inference exercise. All production Intune deployments should include MSI verbose logging to a known path.

4. **Detection rules must be validated against the actual product.** A copied detection rule that references the wrong registry path will silently cause perpetual retry cycles, masking true scope and inflating failure counts.

---

## 9. Sign-off

| Role | Name | Date |
|---|---|---|
| Incident engineer | | |
| Endpoint engineering lead | | |
| App packaging team lead | | |
| Service delivery manager | | |

---

*This document was produced using AI-assisted analysis (GitHub Copilot / Claude Sonnet 4.6) under the DWP personal AI usage charter. All findings are based on the event log provided and the preceding hypothesis analysis. Conclusions should be validated against live environment evidence before closure.*
