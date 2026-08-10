# Root Cause Analysis — Group Policy Failure, Floor 3 Finance
**Incident Reference:** FAULT-A  
**Date of Incident:** 2024-03-15  
**Date of RCA:** 2024-03-15  
**Analyst:** DWP Engineer  
**Status:** Closed — resolved 09:09, 2024-03-15  
**Severity:** High — 3 workstations unable to receive Group Policy at startup; users unable to access domain-enforced resources

---

## Executive Summary

On the morning of 2024-03-15, three of four Windows 11 workstations in OU=Finance (Floor 3) failed Group Policy processing at startup. The machines could not locate the domain controller `FINBRIDGE-DC01` because their DHCP-assigned DNS server (`10.10.3.250`) had been decommissioned at 02:00 during an overnight DNS migration wave. The Floor 3 DHCP scope was not updated as part of the migration, causing all affected machines to query a non-existent DNS server. The fourth machine was unaffected because it had been manually pre-configured to use the new DNS server before the migration began.

The DHCP scope was corrected, DNS leases were renewed, and Group Policy was successfully re-applied. Full resolution was confirmed at 09:09 when affected users logged in to their Windows 11 machines without issue.

---

## Incident Timeline

| Time | Event |
|---|---|
| 2024-03-14 ~22:00 | DNS migration wave begins. New central DNS server `10.10.0.10` brought online. |
| 2024-03-14 overnight | DHCP scope for Floor 3 subnet (`10.10.3.0/24`) **not updated** — option-6 still references `10.10.3.250` and `172.16.5.5`. |
| 2024-03-15 02:00 | Old DNS servers `10.10.3.250` and `172.16.5.5` decommissioned. Machines still holding leases with these addresses now have no functioning DNS. |
| 2024-03-15 07:40:02 | DESKTOP-FB031 starts. Network Location Awareness enters running state (SCM Event 7036). |
| 2024-03-15 07:40:08 | **Netlogon Event 5719** — secure channel to FINBRIDGE domain fails. DNS query for `FINBRIDGE-DC01.finbridge.local` returns no response. |
| 2024-03-15 07:40:09 | **GroupPolicy Event 1058** — GP fails to access `\\FINBRIDGE-DC01\sysvol\...` Error `0x3` (path not found — hostname unresolvable). |
| 2024-03-15 07:40:10 | **GroupPolicy Event 1030** — cannot query list of GPOs. Error `0x546`. |
| 2024-03-15 07:40:12 | **GroupPolicy Event 1129** — GP failed, no DC connectivity. |
| 2024-03-15 07:40:05 | DESKTOP-FB029 (unaffected) receives DHCP lease with DNS `10.10.0.10`. |
| 2024-03-15 07:40:11 | DESKTOP-FB029 **GroupPolicy Event 1500** — GP processes successfully. |
| 2024-03-15 07:41:05 | **DNS Client Event 1014** on FB031 — name resolution for DC timed out. None of the configured DNS servers responded. |
| 2024-03-15 07:42:18 | **DHCP Client Event 50036** on FB031 — DHCP lease renewed; DNS `10.10.3.250` re-assigned (confirms scope still stale). |
| 2024-03-15 07:44:01 | **GroupPolicy Event 1129** — second GP failure on FB031. |
| 2024-03-15 ~08:00 | Incident reported to DWP engineer. Hypothesis analysis begun. |
| 2024-03-15 ~08:30 | Evidence review confirms H1 (DHCP scope not updated) as root cause. H3, H4, H5 eliminated. |
| 2024-03-15 ~08:45 | DHCP scope option-6 updated to `10.10.0.10` on DHCP server. |
| 2024-03-15 ~08:50 | `ipconfig /release`, `/renew`, `/flushdns` and `gpupdate /force` run on FB031, FB055, FB056, FB057. |
| 2024-03-15 ~08:55 | GroupPolicy Event 1500 confirmed on all four machines post-renewal. |
| 2024-03-15 09:09 | **Incident closed.** Affected users log in to Windows 11 machines successfully. No further GP errors reported. |

---

## Affected Assets

| Machine | IP | DNS Assigned (incident) | DNS Assigned (post-fix) | Status |
|---|---|---|---|---|
| DESKTOP-FB031 | 10.10.3.144 | 10.10.3.250 (decommissioned) | 10.10.0.10 | Resolved |
| DESKTOP-FB055 | — | 172.16.5.5 (decommissioned) | 10.10.0.10 | Resolved |
| DESKTOP-FB056 | — | 172.16.5.5 (decommissioned) | 10.10.0.10 | Resolved |
| DESKTOP-FB057 | — | 172.16.5.5 (decommissioned) | 10.10.0.10 | Resolved |
| DESKTOP-FB029 / FB058 | 10.10.3.141 | 10.10.0.10 (correct) | 10.10.0.10 | Unaffected |

---

## Supporting Evidence

### Key Event Log Entries — DESKTOP-FB031

| Event ID | Source | Level | Time | Summary |
|---|---|---|---|---|
| 7036 | Service Control Manager | Information | 07:40:02 | Network Location Awareness started |
| 5719 | Netlogon | Error | 07:40:08 | No DC available; DNS query returned no response |
| 1058 | GroupPolicy | Error | 07:40:09 | GP failed; SYSVOL path unreachable; error `0x3` |
| 1030 | GroupPolicy | Warning | 07:40:10 | Cannot query GPO list; error `0x546` |
| 1129 | GroupPolicy | Error | 07:40:12 | GP failed — no DC connectivity |
| 1014 | DNS Client | Warning | 07:41:05 | DNS query timed out; no DNS servers responded |
| 50036 | DHCP Client | Information | 07:42:18 | Lease renewed; DNS re-assigned as `10.10.3.250` (old, decommissioned) |
| 1129 | GroupPolicy | Error | 07:44:01 | GP failed again — no DC connectivity |

### Comparison — DESKTOP-FB029 (unaffected)

| Event ID | Source | Level | Time | Summary |
|---|---|---|---|---|
| 50036 | DHCP Client | Information | 07:40:05 | Lease issued; DNS assigned `10.10.0.10` (correct) |
| 1500 | GroupPolicy | Information | 07:40:11 | Group Policy processed successfully |

### DHCP Server Log — Floor 3 Subnet

| Machine(s) | DNS Assigned | Server Status |
|---|---|---|
| FB055–FB057 | 172.16.5.5 | Decommissioned 2024-03-14 overnight |
| FB031 | 10.10.3.250 | Decommissioned 2024-03-15 02:00 |
| FB029 / FB058 | 10.10.0.10 | Active — correct new central DNS |

---

## Root Cause

**The DHCP scope for the Floor 3 subnet (`10.10.3.0/24`) was not updated during the DNS migration wave. DHCP option-6 continued to reference the old DNS servers (`10.10.3.250` and `172.16.5.5`), both of which were decommissioned as part of the same migration. Affected machines that obtained or renewed leases after decommission received a DNS server address that produced no response, making it impossible to resolve `FINBRIDGE-DC01.finbridge.local` and therefore impossible to locate a domain controller for Group Policy processing.**

Contributing factor: the decommission of the old DNS servers proceeded without first verifying that no active DHCP scopes still referenced them.

---

## 5-Why Analysis

| Why | Finding |
|---|---|
| **Why did Group Policy fail?** | The machines could not reach a domain controller — Netlogon Event 5719 confirmed no DC was available and all GP events (1058, 1030, 1129) followed directly from that. |
| **Why could the machines not reach the domain controller?** | DNS resolution for `FINBRIDGE-DC01.finbridge.local` failed — DNS Event 1014 confirmed none of the configured DNS servers responded, so the DC hostname could not be resolved to an IP. |
| **Why did DNS resolution fail?** | The DNS servers assigned to the affected machines (`10.10.3.250`, `172.16.5.5`) had been decommissioned at 02:00 during the overnight migration wave — they were offline and not answering queries. |
| **Why were the machines still using the decommissioned DNS servers?** | The DHCP scope for the Floor 3 subnet (`10.10.3.0/24`) was not updated during the migration — option-6 still listed the old server addresses, so every DHCP lease renewal re-issued the dead DNS addresses. |
| **Why was the DHCP scope not updated?** | The DNS migration run-book did not include a step to audit and update all affected DHCP scopes before or during decommission. The migration wave was executed without a pre-decommission dependency check confirming zero active DHCP scopes still referenced the old servers. |

**Root cause statement:** The migration run-book lacked a DHCP scope audit step, allowing the old DNS server to be decommissioned while three Floor 3 machines (and their DHCP scope) still depended on it.

---

## Hypothesis Elimination Record

| Hypothesis | Verdict | Eliminated By |
|---|---|---|
| H1: DHCP scope not updated — old DNS assigned | **Confirmed root cause** | DHCP Event 50036 (07:42:18); DHCP server log |
| H2: Old DNS decommissioned while clients held it | **Confirmed contributing factor** | DNS Event 1014 (07:41:05); Netlogon Event 5719 (07:40:08) |
| H3: New DNS missing DC SRV records | Eliminated | FB029 GP Event 1500 (07:40:11) — new DNS served records correctly |
| H4: DC failed to re-register on new DNS | Eliminated | FB029 GP Event 1500 (07:40:11); "no response" (not NXDOMAIN) in Event 5719 |
| H5: SYSVOL unavailable / DFS-R lag | Eliminated | FB029 GP Event 1500 (07:40:11); Event 1058 error `0x3` is a DNS-layer failure, not a SYSVOL fault |

---

## Resolution Applied

| Step | Action | Outcome |
|---|---|---|
| 1 | Confirmed DHCP scope option-6 listed `10.10.3.250` | Fault confirmed on DHCP server |
| 2 | Updated scope option-6 to `10.10.0.10` on DHCP server | Scope corrected |
| 3 | Ran `ipconfig /release && ipconfig /renew` on FB031, FB055, FB056, FB057 | Machines received DNS `10.10.0.10` |
| 4 | Ran `ipconfig /flushdns && gpupdate /force` on all four machines | GP processed; Event 1500 observed on all machines |
| 5 | Ran `nltest /sc_verify:FINBRIDGE` | Secure channel confirmed: `STATUS_SUCCESS` |
| 6 | Users logged in to Windows 11 machines | No errors reported — incident closed 09:09 |

---

## Preventive Actions

| # | Action | Owner | Priority | Due |
|---|---|---|---|---|
| PA-1 | **Update DNS migration run-book** to include a mandatory pre-decommission step: enumerate all DHCP scopes and confirm option-6 has been updated to new DNS before the old server is taken offline. | Network / Change team | Critical | Before next migration wave |
| PA-2 | **Add DHCP scope audit to migration wave sign-off checklist.** No DNS server should be decommissioned without a signed-off confirmation that zero DHCP scopes reference it. | Change Manager | Critical | Before next migration wave |
| PA-3 | **Run DHCP-wide scope audit now** using the PowerShell script below to identify any remaining scopes still referencing `10.10.3.250` or `172.16.5.5` across all subnets. | DWP Engineer | High | Within 24 hours |
| PA-4 | **Implement DHCP scope change validation in monitoring.** Alert when a DHCP scope's DNS option references a server that is no longer reachable (ICMP/DNS probe). | Infrastructure | Medium | Next sprint |
| PA-5 | **Document manual pre-configuration as a migration pre-requisite.** Machines that cannot have DHCP scopes updated in advance should be individually pre-configured (as FB029/FB058 were) and tracked in the change record. | Change Manager | Medium | Next migration wave planning |

### PA-3 — Audit Script: find DHCP scopes still referencing old DNS servers

```powershell
$oldServers = '10.10.3.250', '172.16.5.5'

Get-DhcpServerv4Scope | ForEach-Object {
    $dns = Get-DhcpServerv4OptionValue -ScopeId $_.ScopeId -OptionId 6 -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Scope  = $_.ScopeId
        Name   = $_.Name
        DNS    = ($dns.Value -join ', ')
        AtRisk = (($dns.Value | Where-Object { $oldServers -contains $_ }).Count -gt 0)
    }
} | Where-Object { $_.AtRisk } | Format-Table -AutoSize
```

Any scope flagged as `AtRisk: True` should be updated immediately:
```powershell
Set-DhcpServerv4OptionValue -ScopeId <ScopeId> -OptionId 6 -Value 10.10.0.10
```

---

## Lessons Learned

1. **Decommission order matters.** DNS servers must not be taken offline until all DHCP scopes, static configurations, and client references to those servers have been verified as updated. The DHCP scope is a hidden dependency that is easy to miss in a wave migration.

2. **The comparison machine was decisive.** The fact that FB029 (same OU, same time) succeeded immediately eliminated three of five hypotheses. Always include a working baseline machine in incident scope — it dramatically accelerates root cause identification.

3. **"No response" vs NXDOMAIN is a meaningful distinction.** Event 5719 and DNS Event 1014 both indicated the DNS server produced *no response*, not a negative answer. This pointed to an unreachable server rather than a missing record, which is what directed the investigation toward DHCP and away from DNS zone content.

4. **GP Event 1058 error `0x3` is not a SYSVOL problem.** Error code `0x3` (path not found) on a UNC path means the hostname could not be resolved at the network layer — it is a DNS symptom, not a file-share symptom. This distinction is important for rapid triage.

---

*RCA prepared by DWP Engineer | 2024-03-15 | Incident closed 09:09*
