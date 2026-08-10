Symptom: Finance users on `DESKTOP-FB*` devices in `OU=Finance` did not receive mapped drive `S:` at sign-in. The user-facing symptom was that the expected Finance shared drive was missing after login.

Cause: `Map-FinBridgeDrives.ps1` was migrated from a GPO logon script running in the signed-in user's context to an Intune PowerShell script running as SYSTEM, but the script and delivery design were not reworked for that execution context. The script then attempted to access `\\finbridge-fs01\Finance` and create drive `S:` without the required user-session context, user credentials, and session visibility.

Scope: The confirmed incident affected all Finance users on `DESKTOP-FB*` devices in `OU=Finance`. The incident started at `08:00` on 2024-03-15.

Workaround: Disable or remove the failing SYSTEM-context Intune deployment for `Map-FinBridgeDrives.ps1` and restore the mapping through a user-context method. In the verified incident, this restored access and service was confirmed working at `09:09`.

Permanent fix: Update the GPO-to-Intune migration runbook to require explicit execution-context review for every migrated script, and treat mapped drives and other user-visible session artifacts as user-context actions by default. Add pilot validation, startup dependency checks, bounded retry logic, and rollback steps before broad deployment of context-changing script migrations.

How to spot it: Look for ScriptRunner entries showing `Executing: Map-FinBridgeDrives.ps1`, then `Script context: SYSTEM account`, followed by `Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time` and `Exit code: 1. Error: Network name cannot be found.` On the host, correlate Service Control Manager Event `7036`, GroupPolicy Event `1500`, and Ntfs Event `98` with the message `File system could not map drive letter S: Drive letter has not been assigned.`