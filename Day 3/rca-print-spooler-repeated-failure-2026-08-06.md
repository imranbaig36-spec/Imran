# Root Cause Analysis (RCA): Print Spooler Repeated Failure

## Incident Summary
- Incident type: Service instability and startup failure
- Affected service: `Print Spooler` (`spoolsv.exe`)
- Observation window: ~3 minutes (10:01:14 to 10:03:50)
- Log source: `System` log, `Service Control Manager`
- Date analyzed: 2026-08-06

## Event ID Explanation

### Event ID 7034 (Service terminated unexpectedly)
Records that a service crashed/stopped without a clean, expected shutdown path. The event includes a running counter ("It has done this N time(s)") showing repeat failures.

In this incident:
- 10:01:14 -> unexpected termination #1
- 10:01:45 -> unexpected termination #2
- 10:02:16 -> unexpected termination #3

### Event ID 7031 (Service terminated unexpectedly; recovery action scheduled)
Also records unexpected service termination, but additionally logs the configured Service Recovery action and delay.

In this incident:
- 10:02:47 -> unexpected termination #4
- SCM states it will attempt corrective action: `Restart the service` after `60000 ms` (60 seconds).

### Event ID 7023 (Service terminated with a specific error)
Records that the service stopped and returned a concrete error code/message rather than only "unexpectedly terminated."

In this incident:
- 10:03:49 -> `The specified module could not be found.`
- This strongly indicates a missing or inaccessible binary/DLL/module required by Print Spooler or one of its loaded print components (such as a print driver/monitor/provider module).

### Event ID 7038 (Service unable to log on with configured account)
Records that SCM could not start the service because the configured service account failed logon due to rights/policy.

In this incident:
- 10:03:50 -> could not log on as `NT AUTHORITY\SYSTEM`
- Error: `the user has not been granted the requested logon type at this computer`
- This indicates a service logon-right/policy issue during startup attempt.

## Reconstructed Sequence (Plain English)
1. The Print Spooler starts crashing repeatedly every ~31 seconds (7034 at 10:01:14, 10:01:45, 10:02:16).
2. On the 4th crash at 10:02:47, SCM records the same unexpected termination and confirms it will run service recovery by restarting after 60 seconds (7031).
3. When recovery/startup proceeds, the service reports a concrete failure at 10:03:49: a required module is missing (7023).
4. Immediately after, at 10:03:50, SCM also logs that Print Spooler cannot log on as LocalSystem due to logon-right failure (7038), preventing successful restart.

## Most Likely Cause of Failure (with Evidence)
Most likely primary cause: a missing/corrupt Print Spooler-related module (commonly a print driver component, print monitor/provider DLL, or dependency) caused repeated spooler crashes, and the service then failed to recover cleanly.

Evidence:
- Repeated abrupt crashes are confirmed by `7034`/`7031` (4 terminations in quick succession).
- `7023` provides the strongest causal indicator: `The specified module could not be found`.
- The cadence (multiple crashes first, then explicit module-not-found) is consistent with a broken print component loaded by Spooler.

Secondary/compounding issue:
- `7038` indicates a startup-rights/policy problem for `NT AUTHORITY\SYSTEM` during restart, which likely worsened recovery (service could not come back even after crash cycle).

## Analyst Conclusion
The incident was driven primarily by Print Spooler component integrity/dependency failure (missing module), producing repeated unexpected terminations. A subsequent service-logon-rights error for LocalSystem further blocked normal recovery, extending impact.

## Recommended Next Checks
1. Validate Spooler dependencies and component paths
- Confirm `spoolsv.exe` and required spooler modules exist and are accessible.
- Review loaded third-party print drivers/monitors/providers for missing DLL references.

2. Inspect print subsystem additions/changes
- Check recent printer driver installs/updates/removals prior to 10:01.
- Remove or update suspect third-party drivers.

3. Verify service account and rights policy
- Confirm Print Spooler is configured for `LocalSystem` as intended.
- Review local/domain policy for `Log on as a service` and deny assignments affecting `SYSTEM`.

4. Repair OS component integrity
- Run system file/integrity checks and servicing (`sfc`, `DISM`) as per support playbook.

5. Correlate with policy and change timeline
- Check GPO application and security baseline changes around incident time.

## Evidence Table

| Time     | Event ID | Meaning | Incident Signal |
|----------|----------|---------|-----------------|
| 10:01:14 | 7034 | Service terminated unexpectedly (#1) | Start of crash loop |
| 10:01:45 | 7034 | Service terminated unexpectedly (#2) | Repeat crash |
| 10:02:16 | 7034 | Service terminated unexpectedly (#3) | Persistent instability |
| 10:02:47 | 7031 | Unexpected termination (#4) + restart action in 60s | Recovery workflow triggered |
| 10:03:49 | 7023 | Service terminated: module not found | Strong root-cause evidence |
| 10:03:50 | 7038 | Service cannot log on as SYSTEM due to logon type rights | Recovery/startup blocked |
