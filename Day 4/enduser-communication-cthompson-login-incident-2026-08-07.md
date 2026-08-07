# End User Communication - cthompson Login Incident (2026-08-07)

## Audience 1 - Non-technical executive
Your access is restored and your data is safe. This was a single-person sign-in issue affecting FINBRIDGE\cthompson only, starting around 08:40. Repeated incorrect saved password attempts from DESKTOP-FB022 and 10.10.8.112 locked the account at 08:44:56. Helpdesk-admin re-enabled the account at 09:08:14, and successful sign-in on DESKTOP-FB022 was confirmed at 09:09:01. The issue was resolved at 09:09 with no further user issues reported. You do not need to take action unless it happens again.

## Audience 2 - Affected end-user team (10 people, non-technical)
Quick update: access is restored and data is safe. Only FINBRIDGE\cthompson was affected, starting around 08:40. What happened: repeated incorrect saved password attempts from DESKTOP-FB022 and 10.10.8.112 locked the account at 08:44:56. Helpdesk-admin re-enabled the account at 09:08:14, and a successful sign-in on DESKTOP-FB022 was confirmed at 09:09:01; the issue was resolved at 09:09 with no further issues reported. If you see the same problem, contact the Service Desk immediately and report your device name and time of failure.

## Audience 3 - Engineer-to-engineer internal note
Incident facts: data safe, single-user scope only (FINBRIDGE\cthompson), start around 08:40.

Root cause: account lockout due to repeated bad credential submissions.
- Source chain: DESKTOP-FB022 plus secondary source 10.10.8.112.
- Lockout point: 08:44:56.

Supporting evidence:
1. 08:44:01 - Event 4776, 0xC000006A (wrong password), source workstation DESKTOP-FB022.
2. 08:44:03 / 08:44:28 / 08:44:55 - Event 4625 bad password, logon type 2, source DESKTOP-FB022.
3. 08:44:56 - Event 4740 account locked out, caller DESKTOP-FB022.
4. 08:45:10 - Event 4625 account locked out, logon type 7, source DESKTOP-FB022.
5. 08:45:44 / 08:46:01 / 08:46:33 - Event 4771, failure 0x18 (wrong password), source IP 10.10.8.112.
6. 09:08:14 - Event 4722 account enabled, actor FINBRIDGE\helpdesk-admin.
7. 09:09:01 - Event 4624 successful interactive logon (type 2), source DESKTOP-FB022.

Exact action taken:
1. Service desk performed account recovery via enable/unlock path (confirmed by 4722 at 09:08:14).
2. Post-recovery login validated (4624 at 09:09:01 from DESKTOP-FB022).
3. User confirmed no further issues; incident resolved 09:09.

Config/detail context:
1. Domain account: FINBRIDGE\cthompson.
2. Primary host: DESKTOP-FB022.
3. Additional auth source observed: 10.10.8.112.
4. Failure codes observed: 0xC000006A and 0x18.

Verification step used for closure:
1. Positive auth event 4624 at 09:09:01 from DESKTOP-FB022 after account enable at 09:08:14.
2. User confirmation of normal access.

Preventive action needed:
1. Find and remediate stale credential source behind 10.10.8.112.
2. Clear/update saved credentials across endpoints/apps after any password/account recovery.
3. Add alerting for repeated 4776/4771 followed by 4740 for same user across multiple sources.
4. Keep short monitoring window after recovery for repeat bad-password/lockout patterns.
