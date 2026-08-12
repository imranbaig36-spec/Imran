# Installation Failure Analysis — Adobe Acrobat Pro v23.6
**Date:** 2024-03-15  
**Engineer context:** DWP endpoint / Intune managed pool  
**Key timing clue:** Overnight image update applied to one pool only  
**Observed error:** MSI return code 1603 (both attempt 1 at 10:01 and retry at 11:01)

---

## Scope Facts Summary

| Item | Detail |
|---|---|
| Package | AdobeAcrobatPro.intunewin |
| Install context | SYSTEM |
| Command | `msiexec /i AcrobatPro.msi /quiet` |
| Error code | 1603 — Fatal error during installation |
| Attempts | 2 (identical outcome, ~41–43 s before failure each time) |
| Detection key checked | `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0` *(note: Reader, not Pro)* |
| Detection result | Not found |
| Scope | One pool only (updated overnight); other pools unaffected |

---

## Ranked Causes — Most Probable First

> Ranking is weighted by the overnight single-pool image update as the primary differentiator.  
> 1603 = "Fatal error during installation" — broad code that covers conflicts, permissions, prerequisites, and environment issues.

---

### 1. Conflicting existing Adobe installation baked into the new image

**Why this fits:**  
The overnight image refresh is the single change separating this pool from healthy ones. MSI 1603 is the classic return code when an upgrade or install collides with an already-installed Adobe product (Reader, Acrobat Standard, or an older Acrobat Pro) that was silently included in the new base image. The consistent 41–43 s runtime before failure suggests the MSI begins executing, detects the conflict, and aborts — not a fast permission or path rejection.

**Fastest check:**  
On an affected pool VM, run:
```
wmic product where "name like 'Adobe%'" get name,version
```
If any Adobe product appears, a conflicting installation is present in the image.

---

### 2. SYSTEM account TEMP/working directory permissions tightened by the image update

**Why this fits:**  
Image hardening scripts commonly restrict `C:\Windows\Temp` or redirect `%TEMP%` for the SYSTEM account. 1603 is frequently raised when MSI cannot write to its extraction or working directory. The SYSTEM install context (line 2 of the log) means user-profile temp paths are irrelevant — only system-level temp directories matter. This change would affect all SYSTEM-context installs on the updated pool without touching other pools.

**Fastest check:**  
On an affected VM, verify:
```
icacls C:\Windows\Temp
```
SYSTEM should have full control (`F`). Also check `C:\Windows\Installer` for the same.

---

### 3. Missing or downlevel Visual C++ Redistributable prerequisite

**Why this fits:**  
Adobe Acrobat Pro 23.x requires specific VC++ Redistributable versions. If the overnight image update removed or replaced a VC++ runtime (e.g., as part of a software catalogue cleanup), the MSI dependency check fails with 1603 partway through. This is pool-specific if the base image previously had the runtime installed ad-hoc rather than via the standard software catalogue.

**Fastest check:**  
On an affected VM, run:
```
wmic product where "name like 'Microsoft Visual C++%'" get name,version
```
Compare the output against a VM from a pool that was NOT updated overnight. Missing entries identify the gap.

---

### 4. AppLocker or Software Restriction Policy (SRP) blocking MSI execution for SYSTEM

**Why this fits:**  
A GPO or AppLocker rule update pushed alongside the image refresh could restrict unsigned or path-specific MSI execution under the SYSTEM context. 1603 can be returned when the Windows Installer service itself is blocked from completing by a policy constraint. Because the deployment uses `msiexec /quiet` with no logged path, the Intune agent log gives no MSI-internal detail — consistent with a silent policy block.

**Fastest check:**  
On an affected VM, run:
```
Get-AppLockerPolicy -Effective | Test-AppLockerPolicy -Path "C:\Windows\Temp\AcrobatPro.msi" -User "NT AUTHORITY\SYSTEM"
```
A `Denied` result confirms the policy block.

---

### 5. Detection rule registry path mismatch masking a separate install state

**Why this fits:**  
The detection rule checks `HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0` — this is the **Reader** registry path, not the **Acrobat Pro** path (which typically writes to `HKLM\SOFTWARE\Adobe\Adobe Acrobat\23.0`). This means detection will always return "Not detected" even if Pro installs successfully, and it could cause Intune to incorrectly report failure and trigger retries on a pool where Pro *is* already partially installed from a previous deployment cycle — leaving a broken, incomplete installation that then blocks the new attempt with 1603.

**Fastest check:**  
On an affected VM, query both paths directly:
```
reg query "HKLM\SOFTWARE\Adobe\Adobe Acrobat\23.0"
reg query "HKLM\SOFTWARE\Adobe\Acrobat Reader\23.0"
```
If the first key exists but the second does not, the detection rule is wrong and may be causing retries over a previously installed (possibly broken) instance.

---

## Summary Table

| Rank | Cause | Timing clue fit | 1603 fit | Fastest check |
|---|---|---|---|---|
| 1 | Conflicting Adobe install in new image | Strong — image-baked software | Classic 1603 trigger | `wmic product` on affected VM |
| 2 | SYSTEM TEMP permissions tightened | Strong — image hardening | Common 1603 cause | `icacls C:\Windows\Temp` |
| 3 | Missing VC++ Redistributable | Moderate — image cleanup possible | Known prerequisite failure | `wmic product` VC++ comparison |
| 4 | AppLocker/SRP policy block | Moderate — GPO with image rollout | Silent block maps to 1603 | `Test-AppLockerPolicy` |
| 5 | Detection rule path mismatch | Weak on timing, but log evidence present | Indirect — causes repeated installs | `reg query` both Adobe paths |

---

## Next Step Recommendation

Run checks 1 and 5 first — they require no elevated access and can be completed from a single affected VM within minutes. If check 1 returns any Adobe product, escalate to the image build team to review the base image catalogue before the next pool refresh.

> **Note:** Do not conclude on a single cause until at least checks 1 and 2 are completed. The consistent 1603 across two identical attempts 60 minutes apart, with no environmental change between retries, strongly suggests a persistent image-level condition rather than a transient runtime fault.
