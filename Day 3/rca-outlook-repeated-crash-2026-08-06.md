# Root Cause Analysis (RCA): Outlook Repeated Crash

## Incident Summary
- Incident type: Repeated application crash
- Affected application: `OUTLOOK.EXE` (Microsoft Outlook)
- Observation window: ~4 minutes (09:14:22 to 09:18:05)
- Log source: `Application` log
- Date analyzed: 2026-08-06

## Event ID Explanation

### Source: `Application Error` | Event ID 1000
Records an application crash/fault at process level. It captures:
- Faulting application and version
- Faulting module and version
- Exception code and fault offset
- Process ID, start time, and binary paths

In this incident, both crashes identify:
- App: `OUTLOOK.EXE` version `16.0.17126.20132`
- Module: `KERNELBASE.dll` version `10.0.22621.3155`
- Exception code: `0xc0000005` (access violation)
- Same fault offset: `0x000000000003a4b2`

This consistency indicates repeatable failure in the same execution path.

### Source: `Windows Error Reporting` | Event ID 1001
Records crash telemetry packaging/classification by Windows Error Reporting (WER), including:
- Event class (`APPCRASH`)
- Fault bucket ID used for grouping similar failures
- Response/CAB metadata

This is corroborative evidence that Windows grouped and reported the crash signature.

### Source: `.NET Runtime` | Event ID 1026
Records an unhandled .NET exception terminating the process.

In this incident:
- Application: `OUTLOOK.EXE`
- Runtime: `.NET Framework v4.0.30319`
- Exception: `System.AccessViolationException`

This indicates the process encountered invalid memory access that was not handled by app/runtime code.

## Reconstructed Sequence (Plain English)
1. Outlook started at 09:13:44.
2. At 09:14:22, Outlook crashed (`Event 1000`) with access violation (`0xc0000005`) in `KERNELBASE.dll`.
3. User (or an automated restart behavior) launched Outlook again.
4. At 09:17:45, Outlook crashed again (`Event 1000`) with the same module and same fault offset, showing a repeatable fault pattern.
5. At 09:18:01, Windows Error Reporting logged `Event 1001` (`APPCRASH`) and assigned a bucket ID for this recurring crash signature.
6. At 09:18:05, `.NET Runtime` logged `Event 1026`, confirming process termination due to unhandled `System.AccessViolationException`.

## Most Likely Cause of the Crash (with Evidence)
Most likely cause: a deterministic memory access violation in Outlook execution flow, likely triggered by a specific loaded component/path (for example add-in interaction, corrupted profile/data path, or Office/runtime component mismatch), causing repeated unhandled exceptions.

Evidence:
- Two separate `1000` crashes show identical signature: same app version, same module (`KERNELBASE.dll`), same exception (`0xc0000005`), same fault offset (`0x000000000003a4b2`).
- `.NET Runtime` `1026` confirms unhandled `System.AccessViolationException`, matching access-violation behavior.
- WER `1001` (`APPCRASH`) confirms this was recognized as a consistent crash pattern and bucketed accordingly.

What this strongly suggests:
- Not a random transient glitch; the repeated identical offset indicates reproducible execution path failure.
- `KERNELBASE.dll` as faulting module is often where the crash is surfaced, not necessarily the original business-logic defect location. Root trigger is commonly upstream (add-in, plugin, malformed data, profile corruption, or component incompatibility).

## Analyst Conclusion
Outlook experienced repeatable, deterministic process crashes driven by an access violation path (`0xc0000005`) that surfaced in `KERNELBASE.dll` and terminated with an unhandled `.NET` access violation exception. The repeated identical crash signature points to a persistent trigger in Outlook runtime context rather than one-off instability.

## Recommended Follow-Up Checks
1. Run Outlook in safe mode and retest
- Isolate third-party COM add-ins; disable all non-Microsoft add-ins, then re-enable one-by-one.

2. Validate Office build integrity
- Perform Office Quick Repair/Online Repair and verify build consistency.

3. Check profile/data-path integrity
- Test with new Outlook profile; inspect OST/PST health and mailbox mode behavior.

4. Review correlated crash data
- Collect WER dump for the bucket and inspect call stack around fault offset.

5. Verify platform consistency
- Confirm Windows and Office patch alignment; check recent updates immediately prior to incident.

## Evidence Table

| Time     | Source | Event ID | Outcome | Key Detail |
|----------|--------|----------|---------|------------|
| 09:14:22 | Application Error | 1000 | Failure | `OUTLOOK.EXE` crash, `KERNELBASE.dll`, `0xc0000005`, offset `0x3a4b2` |
| 09:17:45 | Application Error | 1000 | Failure | Same crash signature repeated |
| 09:18:01 | Windows Error Reporting | 1001 | Info | `APPCRASH` bucketed (`Fault bucket 1847362910`) |
| 09:18:05 | .NET Runtime | 1026 | Failure | Unhandled `System.AccessViolationException` terminated process |
