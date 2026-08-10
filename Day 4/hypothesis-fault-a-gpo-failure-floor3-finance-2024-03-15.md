# Hypothesis Analysis — FAULT-A: Group Policy Failure, Floor 3 Finance
**Date:** 2024-03-15  
**Analyst:** DWP Engineer  
**Status:** Closed — root cause confirmed (H1), resolution documented

---

## Scope Facts

| Item | Detail |
|---|---|
| Symptom | Group Policy processing failed — no domain controller available |
| Affected | 3 of 4 machines, OU=Finance, Floor 3 (DESKTOP-FB031, FB055–FB057) |
| Unaffected | DESKTOP-FB029 / FB058 (same OU) |
| Window | Startup 2024-03-15 07:40–07:55 |
| Change | DNS migration wave completed overnight 2024-03-14 → 03-15 |
| Key event | DHCP assigned 10.10.3.250 (old, decommissioned DNS) to affected machines |
| Unaffected reason noted | FB058/FB029 manually pre-configured to new DNS 10.10.0.10 before migration |

---

## Ranked Hypothesis List

### 1. DHCP scope for Floor 3 subnet not updated — decommissioned DNS server still assigned

**Why this fits:**  
The DHCP comparison in server logs is explicit: DESKTOP-FB031 (and FB055–FB057) were assigned DNS `10.10.3.250` — identified in the DHCP Client event (50036 at 07:42:18) as the old server decommissioned at 02:00 during the migration wave. The Floor 3 DHCP scope option-6 was never updated to point to the new central DNS `10.10.0.10`. Without a working DNS server, `FINBRIDGE-DC01.finbridge.local` cannot be resolved, which directly explains Event 5719 (no secure channel), Events 1058/1030/1129 (GP failure), and DNS Event 1014 (query timeout). The 3-of-4 split maps precisely to the 3 machines that received a DHCP lease with the stale DNS entry vs. the 1 machine manually reconfigured before the wave.

**Fastest check:**  
On the DHCP server, inspect the scope for subnet `10.10.3.0/24` → Scope Options → Option 006 DNS Servers. Confirm it still lists `10.10.3.250`. If yes, this is the primary root cause.

---

### 2. Old DNS server (10.10.3.250) decommissioned while still referenced by live clients

**Why this fits:**  
Even if the DHCP scope had been updated *after* machines booted, the machines that had already leased IPs before 02:00 decommission still held `10.10.3.250` as their DNS server. The machine-side DNS client had no working server to query, causing all `finbridge.local` lookups to time out (Event 1014, 07:41:05). This is a consequence of cause 1 but is a distinct failure point: the decommission happened without first verifying no clients still pointed to that server.

**Fastest check:**  
From an affected machine: `nslookup FINBRIDGE-DC01.finbridge.local 10.10.3.250`. Expect a timeout/no response, confirming the server is unreachable. Cross-check with `ping 10.10.3.250`.

---

### 3. New DNS server (10.10.0.10) missing or incomplete DC locator SRV records for finbridge.local

**Why this fits:**  
If the new DNS zone was migrated without all DC-locator SRV records (`_ldap._tcp.finbridge.local`, `_kerberos._tcp.finbridge.local`, `_gc._tcp.finbridge.local`), machines pointing to `10.10.0.10` could still fail to find a DC even with correct DNS assignment. This would explain a wider or more persistent failure pattern. It is ranked below causes 1–2 because FB029/FB058 (using `10.10.0.10`) processed GP successfully, which suggests the new DNS does hold correct records — but a partial SRV set could cause intermittent failures.

**Fastest check:**  
`nslookup -type=SRV _ldap._tcp.finbridge.local 10.10.0.10` — should return FINBRIDGE-DC01. If missing or incorrect, the new DNS zone is incomplete.

---

### 4. Domain controller (FINBRIDGE-DC01) failed to re-register DNS records on new DNS server post-migration

**Why this fits:**  
During DNS migration, the DC's Netlogon service must re-register its SRV and A records against the new authoritative DNS server. If the DC's own DNS client was not updated to point to `10.10.0.10` before the migration completed, its dynamic DNS registrations may have gone to the old server (now gone) or failed entirely. This would make the DC undiscoverable even for clients with correct DNS, though FB029's success makes this less likely as primary cause.

**Fastest check:**  
On FINBRIDGE-DC01: `ipconfig /all` to confirm its own DNS points to `10.10.0.10`, then `nltest /dsregdns` to force re-registration and check for errors. Review Netlogon.log for registration failures around 02:00–07:00.

---

### 5. SYSVOL share on FINBRIDGE-DC01 unavailable or DFS-R replication lag post-migration

**Why this fits:**  
Event 1058 (07:40:09) specifically references the SYSVOL UNC path (`\\FINBRIDGE-DC01\sysvol\...`) with error `0x3` (path not found). While the DNS failure would prevent the UNC path from resolving at all, a secondary possibility is that SYSVOL itself was temporarily unavailable — for example, if the DC was rebooted as part of the migration wave and DFS Replication had not yet completed a full sync. This would cause GP failure even if DNS resolved correctly.

**Fastest check:**  
From an unaffected machine (FB029): `net view \\FINBRIDGE-DC01\sysvol` — if this succeeds, SYSVOL is healthy and cause 5 is eliminated. Also check DC Event Log for DFSR Event 4612 (initial sync) or Netlogon Event 3095/3096.

---

## Summary Table

| Rank | Cause | Confidence | Fastest Check |
|---|---|---|---|
| 1 | DHCP scope not updated — old DNS assigned | Very High | DHCP console → scope option 006 |
| 2 | Old DNS server decommissioned with live clients still pointing to it | High | `ping 10.10.3.250` / `nslookup` against it |
| 3 | New DNS missing DC SRV records | Medium | `nslookup -type=SRV _ldap._tcp.finbridge.local 10.10.0.10` |
| 4 | DC failed to re-register records on new DNS | Medium-Low | `nltest /dsregdns` on DC; check Netlogon.log |
| 5 | SYSVOL unavailable / DFS-R replication lag | Low | `net view \\FINBRIDGE-DC01\sysvol` from healthy machine |

---

---

## Evidence Assessment — DESKTOP-FB031 Event Log (07:40–07:55)

Evidence was reviewed against each hypothesis in ranked order. No winner is selected at this stage.

---

### H1 — DHCP scope not updated: decommissioned DNS still assigned
**Verdict: SUPPORTS — direct, explicit evidence**

| Event | Time | Relevance |
|---|---|---|
| DHCP Client Event 50036 | 07:42:18 | DHCP server assigned DNS `10.10.3.250` — annotated in log as the server decommissioned at 02:00. Scope option-6 was not updated. |
| DHCP server log (FB055–057) | — | Confirms `172.16.5.5` (Floor 3 local DNS, also decommissioned) assigned to the other three affected machines. |
| DHCP Client Event 50036 (FB029) | 07:40:05 | Comparison machine received `10.10.0.10` (correct) and processed GP successfully — directly inverts the affected pattern. |

The 3-of-4 affected split and the 1-of-4 unaffected split map with zero ambiguity to DHCP DNS assignment. This evidence is not circumstantial; it is recorded in the DHCP lease event itself.

---

### H2 — Old DNS server decommissioned while clients still held it
**Verdict: SUPPORTS — confirms the mechanism that makes H1 destructive**

| Event | Time | Relevance |
|---|---|---|
| Netlogon Event 5719 | 07:40:08 | "DNS query for FINBRIDGE-DC01.finbridge.local returned no response" — the assigned DNS server produced no reply, not a NXDOMAIN. |
| DNS Client Event 1014 | 07:41:05 | "None of the configured DNS servers responded" — explicit confirmation that `10.10.3.250` is not answering queries at all, consistent with a decommissioned host. |

Note the timeline: GP failure events begin at 07:40:08 — *before* the DHCP renewal is logged at 07:42:18. This means the machine held the old DNS from a prior lease and had already been using the dead server since boot. The 07:42:18 event is a renewal that re-issued the same bad address, not the original assignment.

---

### H3 — New DNS (10.10.0.10) missing or incomplete DC SRV records
**Verdict: CONTRADICTS**

| Event | Time | Relevance |
|---|---|---|
| GroupPolicy Event 1500 (FB029) | 07:40:11 | FB029, using `10.10.0.10`, successfully processed Group Policy six seconds after the Network Location Awareness service started. |

If the new DNS server lacked `_ldap._tcp.finbridge.local` or the DC's A record, FB029 would have failed to locate the domain controller identically to FB031. It did not. The new DNS is serving DC locator records correctly. H3 is eliminated by the comparison machine's success.

---

### H4 — DC failed to re-register DNS records on new DNS server post-migration
**Verdict: CONTRADICTS**

| Event | Time | Relevance |
|---|---|---|
| GroupPolicy Event 1500 (FB029) | 07:40:11 | FB029 resolved FINBRIDGE-DC01 via `10.10.0.10` and accessed SYSVOL without error at startup. |
| Netlogon Event 5719 (FB031) | 07:40:08 | Failure message states DNS query "returned no response" — characteristic of a dead DNS server, not a missing record on a live one (which would return NXDOMAIN). |

If the DC had not registered its records on `10.10.0.10`, FB029 would be unable to locate it. The "no response" wording on FB031 further indicates the DNS server itself is unreachable, not that it lacks the required records. H4 is eliminated.

---

### H5 — SYSVOL unavailable or DFS-R replication lag
**Verdict: CONTRADICTS**

| Event | Time | Relevance |
|---|---|---|
| GroupPolicy Event 1058 (FB031) | 07:40:09 | Error `0x3` (path not found) on `\\FINBRIDGE-DC01\sysvol\...` — this is a UNC path resolution failure, not a share or replication error. `0x3` means the path could not be reached at the network layer, consistent with DNS never resolving the hostname. |
| GroupPolicy Event 1500 (FB029) | 07:40:11 | FB029 accessed the same SYSVOL path successfully at the same time — SYSVOL is online and healthy. |

Had SYSVOL been down or DFS-R incomplete, FB029 would have also received Event 1058. It did not. The `0x3` error on FB031 is a downstream symptom of DNS failure (the hostname never resolved), not an independent SYSVOL fault. H5 is eliminated.

---

## Evidence Summary Table

| Rank | Hypothesis | Evidence Verdict | Key Event(s) |
|---|---|---|---|
| 1 | DHCP scope not updated — old DNS assigned | **SUPPORTS** | Event 50036 (FB031, 07:42:18); DHCP server log (FB055–057); Event 50036 (FB029, 07:40:05) |
| 2 | Old DNS decommissioned while clients still held it | **SUPPORTS** | Netlogon Event 5719 (07:40:08); DNS Event 1014 (07:41:05) |
| 3 | New DNS missing DC SRV records | **CONTRADICTS** | GroupPolicy Event 1500 (FB029, 07:40:11) |
| 4 | DC failed to re-register on new DNS | **CONTRADICTS** | GroupPolicy Event 1500 (FB029, 07:40:11); "no response" wording in Event 5719 |
| 5 | SYSVOL unavailable / DFS-R lag | **CONTRADICTS** | GroupPolicy Event 1500 (FB029, 07:40:11); Event 1058 error code `0x3` is DNS-layer failure |

H3, H4, and H5 are eliminated by the comparison machine evidence. H1 and H2 are both supported and are causally linked — H1 is the configuration failure, H2 is the operational failure that H1 enables.

---

## Confirmed Surviving Hypothesis

**H1 — DHCP scope not updated: decommissioned DNS server assigned to Floor 3 machines.**

H2 (old DNS decommissioned while clients held it) is the operational expression of H1, not a separate cause. Fixing H1 resolves both. H3, H4, and H5 are eliminated by evidence.

---

## Resolution Steps

### Phase 1 — Immediate: restore DNS to affected machines (live fix, no reboot required)

**Step 1 — Confirm the DHCP scope fault**
On the DHCP server (run as administrator):
```
Get-DhcpServerv4OptionValue -ScopeId 10.10.3.0 -OptionId 6
```
Expected bad output: `Value: {10.10.3.250}` (or `172.16.5.5` for Floor 3 scope).  
Expected good output would be `10.10.0.10`. Do not proceed past this step until confirmed.

**Step 2 — Update the DHCP scope DNS option**
```
Set-DhcpServerv4OptionValue -ScopeId 10.10.3.0 -OptionId 6 -Value 10.10.0.10
```
Verify the change:
```
Get-DhcpServerv4OptionValue -ScopeId 10.10.3.0 -OptionId 6
```

**Step 3 — Force lease renewal on each affected machine**  
Run on DESKTOP-FB031, FB055, FB056, FB057 (remotely via PSExec or direct console):
```
ipconfig /release
ipconfig /renew
ipconfig /all
```
Confirm the `DNS Servers` line now shows `10.10.0.10`.

**Step 4 — Flush DNS cache and force Group Policy refresh**
```
ipconfig /flushdns
gpupdate /force
```
Expected outcome: no GP errors. Event log should show GroupPolicy Event 1500 (success) within 90 seconds.

**Step 5 — Verify domain connectivity**
```
nltest /sc_verify:FINBRIDGE
```
Expected: `Flags: ... WRITABLE ... DC connection status: STATUS_SUCCESS`

---

### Phase 2 — Validation: confirm full resolution

| Check | Command / Location | Pass Condition |
|---|---|---|
| DNS resolution | `nslookup FINBRIDGE-DC01.finbridge.local` | Returns correct IP, no timeout |
| Secure channel | `nltest /sc_verify:FINBRIDGE` | `STATUS_SUCCESS` |
| Group Policy | Event Viewer → System → GroupPolicy | Event 1500 present, no 1058/1129 after `gpupdate` |
| SYSVOL access | `dir \\FINBRIDGE-DC01\sysvol` | Lists domain policy folders without error |
| All 4 machines | Repeat steps 3–5 on FB055, FB056, FB057 | All return Event 1500 |

---

### Phase 3 — Scope check: prevent recurrence on other subnets

The DNS migration wave may have affected multiple subnets. Audit all DHCP scopes before closing:

```powershell
# List all scopes and their DNS option — flag any still referencing old servers
Get-DhcpServerv4Scope | ForEach-Object {
    $dns = Get-DhcpServerv4OptionValue -ScopeId $_.ScopeId -OptionId 6 -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Scope   = $_.ScopeId
        Name    = $_.Name
        DNS     = ($dns.Value -join ', ')
    }
} | Where-Object { $_.DNS -notmatch '10\.10\.0\.10' } | Format-Table -AutoSize
```

Any scope not returning `10.10.0.10` should be updated using Step 2 above with its specific `-ScopeId`.

---

### Phase 4 — Change record and post-incident actions

1. Raise a change record documenting the DHCP scope update as an emergency fix.
2. Update the DNS migration run-book to include a mandatory pre/post check: enumerate all DHCP scopes and confirm option-6 is updated *before* the old DNS server is decommissioned.
3. Add a DHCP scope audit step to the migration wave sign-off checklist.
4. Confirm with the network team that `10.10.3.250` and `172.16.5.5` are permanently decommissioned and their DNS entries removed from any remaining scope.
5. Schedule follow-up GP audit on all Floor 3 machines to confirm no policy gaps remain from the failed startup window.

---

## Appendix — Source Event Log Evidence

### DESKTOP-FB031 (affected) — Startup window 2024-03-15 07:40–07:55

```
07:40:02  Service Control Manager  Event 7036
          The Network Location Awareness service entered running state.

07:40:08  Netlogon  Event 5719  Level: Error
          This computer was unable to set up a secure channel to domain
          FINBRIDGE — no domain controller available.
          DNS query for FINBRIDGE-DC01.finbridge.local returned no response.

07:40:09  GroupPolicy  Event 1058  Level: Error
          Group Policy processing failed. Cannot access:
          \\FINBRIDGE-DC01\sysvol\finbridge.local\Policies\
          {3A1B2C4D-E5F6-7890-ABCD-EF1234567890}\gpt.ini
          Error code: 0x3 (The system cannot find the path specified)

07:40:10  GroupPolicy  Event 1030  Level: Warning
          Cannot query list of Group Policy objects.
          Error code: 0x546

07:40:11  GroupPolicy  Event 1058  Level: Error
          Group Policy processing failed. Same as above.

07:40:12  GroupPolicy  Event 1129  Level: Error
          Group Policy failed — no network connectivity to a domain
          controller. A success message will be generated once
          connectivity is restored.

07:41:05  DNS Client Events  Event 1014  Level: Warning
          Name resolution for FINBRIDGE-DC01.finbridge.local timed out.
          None of the configured DNS servers responded.

07:42:18  DHCP Client  Event 50036  Level: Information
          IP address 10.10.3.144 leased from server 10.10.0.1.
          DNS servers assigned by DHCP: 10.10.3.250
          (NOTE: 10.10.3.250 is the OLD DNS server.
           It was decommissioned at 02:00 in the migration wave.
           The correct new DNS server is 10.10.0.10.
           The DHCP scope for this subnet was not updated.)

07:44:01  GroupPolicy  Event 1129  Level: Error
          Group Policy processing failed again — no DC connectivity.
```

### DESKTOP-FB029 (unaffected, same OU) — comparison

```
07:40:05  DHCP Client  Event 50036
          IP: 10.10.3.141
          DNS servers assigned: 10.10.0.10  (correct new DNS)

07:40:11  GroupPolicy  Event 1500  Level: Information
          Group Policy settings processed successfully.
          (FB029 was manually reconfigured before migration wave)
```

### DHCP server log — Floor 3 subnet comparison

```
FB055-057 DNS assigned: 172.16.5.5
  (Floor 3 local DNS — decommissioned 2024-03-14 overnight)
FB058 DNS:              10.10.0.10
  (Central DNS — correct, manually set before migration)
Root cause: DHCP scope for Floor 3 subnet still references
the old DNS server. FB058 was manually pre-configured and
therefore unaffected.
```
