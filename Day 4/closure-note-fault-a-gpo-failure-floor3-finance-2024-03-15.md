# Closure Note — FAULT-A: Group Policy Failure, Floor 3 Finance
**Date:** 2024-03-15  
**Closed:** 09:09  

---

Resolved. Cause: DHCP scope for Floor 3 subnet (`10.10.3.0/24`) was not updated during the overnight DNS migration wave — option-6 continued to assign decommissioned DNS servers (`10.10.3.250`, `172.16.5.5`), making `FINBRIDGE-DC01.finbridge.local` unresolvable and blocking Group Policy processing on three of four Finance machines at startup. Action: DHCP scope option-6 updated to new central DNS `10.10.0.10`; `ipconfig /release`, `/renew`, `/flushdns`, and `gpupdate /force` run on DESKTOP-FB031, FB055, FB056, and FB057; GP Event 1500 and `nltest /sc_verify:FINBRIDGE` confirmed clean on all four machines. Preventive: DNS migration run-book to be updated with a mandatory pre-decommission DHCP scope audit step — no DNS server to be decommissioned until all scopes referencing it are confirmed updated; full scope audit to be run across all subnets from the same migration wave. User confirmed working — affected Floor 3 Finance users logged in to Windows 11 machines at 09:09 with no issues reported.
