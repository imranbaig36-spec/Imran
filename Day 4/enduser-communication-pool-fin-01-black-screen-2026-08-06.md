# End-User Communication: POOL-FIN-01 Black Screen Incident (2026-08-06)

## Audience 1 - Non-technical executive
Your access is restored and your data is safe. In the Finance desktop group, an overnight update included a faulty display component (31.0.101.4146), causing black screens for about 40% of users. We paused new sign-ins, returned systems to the prior package (build-20240313, display 31.0.101.4046), restarted them, and confirmed normal sign-ins with no new crashes. We will add blocked-version checks before release. No action needed unless it happens again.

## Audience 2 - Affected end-user team (10 people, non-technical)
Your access is restored and your data is safe. What happened: an overnight update in the Finance desktop group included a faulty display component (31.0.101.4146), which caused black screens for about 40% of users. We paused new sign-ins, moved systems back to the previous package (build-20240313, display 31.0.101.4046), restarted them, and confirmed normal sign-ins with no new crashes. We will add blocked-version checks before release. If you see this again, contact the Service Desk.

## Audience 3 - Engineer-to-engineer internal note
Access restored; no data loss.

Root cause:
- Overnight update in the Finance desktop group introduced faulty display component v31.0.101.4146, causing black screen behavior for ~40% of users.

Exact action taken:
- Paused new sign-ins to affected systems.
- Rolled systems back to previous package build-20240313 with display component v31.0.101.4046.
- Restarted systems after rollback.

Config detail:
- Faulty version: display component v31.0.101.4146.
- Restored version: display component v31.0.101.4046.
- Restored package: build-20240313.

Verification step:
- Normal sign-ins confirmed after rollback/restart.
- No new display crashes observed after restoration.

Preventive action needed:
- Maintain blocked-version list for faulty display components.
- Enforce pre-release validation checks before production rollout.

User direction:
- No action needed unless issue recurs; if it does, contact Service Desk.