# Triage B: Floor 6 Login Failures / Slow Sign-In

**Date:** 2026-08-14  
**Incident Type:** Availability / Access  
**Priority:** High (Major Incident Candidate)

## What Was Reported
At least a dozen users on Floor 6 cannot sign in or are experiencing very slow sign-in.

## Why This Is Urgent
Broad productivity impact and potential business disruption across a full floor.

## What To Check First (In Order, And Why)
1. **Define scope and pattern**: Floor 6 only, wired/wireless, device model, user role, new vs existing profile.  
Why: quickly distinguishes localized issue from broader platform issue.
2. **Check identity/auth health**: Entra sign-in logs, CA failures, lockouts, MFA prompts/errors.  
Why: validates whether authentication policy/credential flows are failing.
3. **Check network dependencies**: DNS, DHCP, proxy, auth endpoints, DC connectivity (if hybrid).  
Why: sign-in slowness commonly tracks dependency latency/failures.
4. **Review endpoint/policy changes** affecting Floor 6 OU/group.  
Why: misapplied policy/scripts can cause mass sign-in delays.
5. **Correlate with Friday app rollout timing**.  
Why: login-time agents/plugins can delay shell/profile initialization.

## Immediate Actions (Right Now)
- Declare **major incident candidate** and open an incident bridge.
- Run rapid sampling (5-10 users) to classify failure types.
- Provide temporary workarounds (alternate VDI pool, known-good devices, mobile access where possible).
- Increase service desk floor support and publish short status updates.

## What To Tell Non-Technical Stakeholders
“We are managing a concentrated sign-in disruption on Floor 6. We are isolating whether the issue is authentication, network, or a recent change interaction, while providing immediate workarounds to keep teams operating.”

## Owner Handoff
- Incident Lead: Service Desk Duty Manager
- Supporting Teams: Identity, Endpoint Engineering, Network Operations
