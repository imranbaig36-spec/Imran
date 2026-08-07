Symptom: User FINBRIDGE\cthompson could not log in, with reported start around 08:40. The observed user impact was blocked interactive access.

Cause: The verified root cause was account lockout triggered by repeated wrong-password authentication attempts for FINBRIDGE\cthompson from DESKTOP-FB022. RCA evidence also showed continued wrong-password attempts from source IP 10.10.8.112 after lockout.

Scope: The incident affected a single user only (FINBRIDGE\cthompson). No multi-user or platform-wide impact was identified in the RCA.

Workaround: Perform account recovery by enabling/unlocking the user account, then validate an immediate interactive sign-in on the primary host. In this incident, account enable was logged at 09:08:14 and successful interactive logon followed at 09:09:01 from DESKTOP-FB022.

Permanent fix: Identify and remediate the stale credential source behind 10.10.8.112, and clear or update saved credentials across endpoints and apps after recovery. Implement lockout early-warning alerting and multi-source bad-password correlation as defined in preventive actions.

How to spot it: Look for a chain of Event 4776 with error 0xC000006A, repeated Event 4625 bad-password failures (logon type 2), then Event 4740 lockout, and optionally Event 4625 with "Account locked out" (logon type 7). In this case, recurring Event 4771 with failure code 0x18 from 10.10.8.112 after lockout was a key secondary signal, and recovery confirmation was Event 4722 followed by Event 4624 interactive success.
