# Triage Summary: T-1008 VPN Connected but No Internal Access

## Summary (one line)
User reports VPN connects but internal resources are not reachable after Windows 11 upgrade.

## Impact (who/how many/business urgency)
- Who is affected: user on ticket T-1008 (to-verify)
- How many affected: one reported user/device so far (to-verify broader trend)
- Business urgency: to-verify

## Known Facts
- Ticket reference: T-1008
- Reported state: VPN connects
- Reported symptom: no internal resources reachable
- Timing context: after Windows 11 upgrade

## Missing Information to Gather
- Which internal resources fail (file shares, intranet, remote apps, name-based only, IP-based only) (to-verify)
- Whether issue occurs on all networks or one network only (to-verify)
- Whether other upgraded users report same VPN behavior (to-verify)
- Whether DNS resolution changes once VPN is connected (to-verify)
- Whether any endpoint firewall/security policy changes coincided with upgrade (to-verify)

## Likely Category
- Remote access/networking incident: VPN routing or name-resolution path after OS upgrade (to-verify service taxonomy mapping)

## First Diagnostic Step
- With VPN connected, test one known internal resource by both hostname and IP address to quickly distinguish likely name-resolution issues from broader VPN routing/connectivity issues.
