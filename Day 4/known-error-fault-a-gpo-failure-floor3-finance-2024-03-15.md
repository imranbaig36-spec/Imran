# Known-Error Record — DWP Knowledge Base
**Reference:** FAULT-A  
**Date raised:** 2024-03-15  
**Status:** Active  
**Source RCA:** rca-fault-a-gpo-failure-floor3-finance-2024-03-15.md

---

**Symptom:** Users on affected machines cannot log in normally and domain-enforced settings fail to apply at startup. Group Policy processing fails with no domain controller available, reported within the first few minutes of machine startup.

**Cause:** A DHCP scope was not updated during a DNS migration wave, causing the scope to assign a decommissioned DNS server address to client machines. With the old DNS server offline, the domain controller hostname (`FINBRIDGE-DC01.finbridge.local`) cannot be resolved, blocking Netlogon secure-channel establishment and all subsequent Group Policy processing.

**Scope:** Windows 11 workstations that obtain their DNS address via DHCP from a scope that was not updated before the old DNS server was decommissioned. In the confirmed incident, three of four machines in OU=Finance (Floor 3, subnet `10.10.3.0/24`) were affected; the fourth was unaffected because it had been manually pre-configured to the new DNS server before the migration.

**Workaround:** On the DHCP server, update the affected scope's option-6 to the new DNS server (`10.10.0.10`): `Set-DhcpServerv4OptionValue -ScopeId <subnet> -OptionId 6 -Value 10.10.0.10`. Then on each affected machine run `ipconfig /release`, `ipconfig /renew`, `ipconfig /flushdns`, and `gpupdate /force` to obtain the correct DNS address and re-apply Group Policy without a reboot.

**Permanent fix:** Update the DNS migration run-book to include a mandatory pre-decommission gate: enumerate all DHCP scopes and confirm option-6 has been changed to the new DNS server before the old server is taken offline. Audit all remaining subnets from the same migration wave using the scope-check script in the RCA to identify and correct any further stale scopes.

**How to spot it:** On the affected machine, look for the following cluster of events within the startup window — Netlogon Event 5719 ("no domain controller available; DNS query returned no response"), GroupPolicy Event 1058 (error `0x3` on the SYSVOL UNC path), GroupPolicy Event 1129 ("no network connectivity to a domain controller"), and DNS Client Event 1014 ("none of the configured DNS servers responded"). The "no response" wording in Event 5719 and Event 1014 is the key signal: it indicates an unreachable DNS server, not a missing DNS record. Confirm by running `ipconfig /all` on the affected machine and checking that the `DNS Servers` value matches a known-live server.
