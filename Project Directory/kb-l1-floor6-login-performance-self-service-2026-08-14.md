# L1 Self-Service: Floor 6 Slow Sign-In or Login Failure
Version: 1.0
Last Updated: 2026-08-14
Derived From: Legal Floor 6 Login/Performance Remediation Runbook v1.0

Runbook Traceability (single source assurance):
- This guide is a simplified user-facing re-expression of the source runbook.
- Runbook Step 1-3 -> L1 Steps 1-3 (confirm pattern, route correctly, keep device reachable).
- Runbook Step 4-8 -> Support-side action summarized in "What support will do next."
- Runbook Step 9 + verification -> L1 Step 4 (retry only after confirmed fix).

If your Floor 6 PC is slow to sign in, fails to sign in, or becomes slow after login, do these steps.

1. Note what happened.
Action: Write down the time, your PC name, and whether the issue was login failure, long sign-in, or poor performance after sign-in.
Expected result: Service Desk has the basics needed to match your issue to the known incident.

2. Report it to Service Desk.
Action: Say you are on Legal Floor 6 and mention the login/performance recurrence.
Expected result: Your ticket is routed for the correct remediation path.

3. Leave the PC on and connected.
Action: Keep it on the network if possible.
Expected result: Engineers can push the app assignment change and policy sync.

4. Retry sign-in after support confirms the fix was applied.
Expected result: You avoid repeated failed sign-ins while the device is being updated.

What support will do next: they will stop the app rollout for impacted Floor 6 devices, remove it where supported, force a sync, and verify sign-in works again.