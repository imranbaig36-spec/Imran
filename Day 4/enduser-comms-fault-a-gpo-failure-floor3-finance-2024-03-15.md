# End-User Communications — FAULT-A: Group Policy Failure, Floor 3 Finance
**Incident date:** 2024-03-15  
**Resolved:** 09:09  
**Prepared by:** DWP Engineer

---

## Version 1 — Non-Technical Executive

**Subject: IT Issue This Morning — Resolved**

Your access and data are safe and were not affected at any point.

This morning, three computers on Floor 3 were temporarily unable to load their work settings after an overnight system update. The issue lasted approximately 90 minutes and was fully resolved by 09:09. Engineers have identified what was missed in the update process and a check is being put in place to prevent it from happening again.

No action is required from you.

---

## Version 2 — Affected End-User Team (Floor 3 Finance)

**Subject: This Morning's Login Issue — Fixed**

Hi team,

Your computers and files are safe — nothing was lost or changed.

This morning, three machines on our floor couldn't load your work settings at startup because an overnight network update accidentally left them pointing to a server address that no longer existed. The issue was fixed by 09:09 and everything is back to normal.

If you experience any login problems or your settings look wrong, please restart your machine. If that doesn't help, contact the DWP Service Desk and reference **FAULT-A**.

Thanks for your patience.

---

## Version 3 — Engineer-to-Engineer Internal Note

**Subject: FAULT-A Post-Fix Handover — GPO Failure Floor 3, DNS Migration Gap**

**Incident window:** 2024-03-15 07:40–09:09  
**Affected:** DESKTOP-FB031, FB055, FB056, FB057 (OU=Finance, Floor 3) — 3 of 4 machines  
**Unaffected:** DESKTOP-FB029 / FB058 (same OU) — manually pre-configured to new DNS pre-migration

---

### Root Cause

DHCP scope `10.10.3.0/24` option-6 was not updated during the overnight DNS migration wave (2024-03-14 → 2024-03-15). The scope continued to assign:

- `10.10.3.250` — decommissioned 2024-03-15 02:00
- `172.16.5.5` — decommissioned 2024-03-14 overnight (Floor 3 local DNS)

Affected machines held these addresses from prior leases going into startup. Lease renewals at 07:42 re-issued the same dead addresses. With no functioning DNS server, `FINBRIDGE-DC01.finbridge.local` could not be resolved → Netlogon could not establish a secure channel → GP processing failed across the board.

FB029/FB058 were unaffected because they were manually pointed at `10.10.0.10` (correct new central DNS) before the migration wave ran.

---

### Key Evidence

| Event | Source | Time | Detail |
|---|---|---|---|
| 5719 | Netlogon | 07:40:08 | No DC available; DNS query returned *no response* (not NXDOMAIN — confirms dead server, not missing record) |
| 1058 | GroupPolicy | 07:40:09 | SYSVOL UNC path unreachable; error `0x3` — DNS-layer failure, not a SYSVOL fault |
| 1014 | DNS Client | 07:41:05 | None of the configured DNS servers responded |
| 50036 | DHCP Client | 07:42:18 | Lease renewed; DNS re-assigned as `10.10.3.250` — scope still stale |
| 1500 | GroupPolicy (FB029) | 07:40:11 | GP succeeded on comparison machine using `10.10.0.10` — eliminates H3 (SRV missing), H4 (DC not registered), H5 (SYSVOL down) |

---

### Action Taken

**1. DHCP scope corrected (DHCP server, run as administrator):**
```powershell
Set-DhcpServerv4OptionValue -ScopeId 10.10.3.0 -OptionId 6 -Value 10.10.0.10
Get-DhcpServerv4OptionValue -ScopeId 10.10.3.0 -OptionId 6  # verified
```

**2. Lease renewal and GP force on all four affected machines (FB031, FB055–057):**
```cmd
ipconfig /release
ipconfig /renew
ipconfig /flushdns
gpupdate /force
```

**3. DNS verified post-renewal:**
```cmd
ipconfig /all   # DNS Servers: 10.10.0.10 confirmed on all four
```

**4. Secure channel verified:**
```cmd
nltest /sc_verify:FINBRIDGE
# Result: STATUS_SUCCESS on all four machines
```

**5. GP success confirmed:** GroupPolicy Event 1500 logged on all four machines within 90 seconds of `gpupdate /force`.  
**6. User validation:** Affected users logged in to Windows 11 machines at 09:09 — no issues reported. Incident closed.

---

### If This Recurs

Symptom pattern to watch for:
- Netlogon 5719 + GP 1058 (`0x3`) + GP 1129 cluster at startup
- DNS 1014 "none of the configured DNS servers responded" (no response, not NXDOMAIN)
- Subset of machines on same subnet affected, others on same OU unaffected

First check: `ipconfig /all` on affected machine → inspect `DNS Servers` line. If it shows a decommissioned address, go straight to DHCP scope on that subnet.

---

### Preventive Action Required

The migration run-book is missing a pre-decommission dependency check. Before the next wave:

1. **Audit all DHCP scopes** for stale DNS references using:

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

Run this **now** — other subnets from the same wave may still be at risk.

2. **Update run-book:** Add a mandatory gate — no DNS server is decommissioned until all DHCP scopes have been confirmed updated and the change signed off by the network team.

3. **Change record:** Raise an emergency change record for the DHCP scope fix already applied and link to RCA `rca-fault-a-gpo-failure-floor3-finance-2024-03-15.md`.

---

*Internal note prepared by DWP Engineer | 2024-03-15 | Closed 09:09*
