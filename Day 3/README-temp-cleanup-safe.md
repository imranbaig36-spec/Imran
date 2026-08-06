# DWP Temp Cleanup Script README

## Script Location
- [Day 3/temp-cleanup-safe.ps1](Day%203/temp-cleanup-safe.ps1)

## Purpose
This script safely cleans temporary files on Windows endpoints using PowerShell 5.1.

It is designed for enterprise use with:
- Dry-run preview
- Age-based targeting
- Locked-file skip handling
- Per-file error handling
- Full action logging
- End-of-run summary
- Rollback support
- Idempotent behavior

## Modes
### Cleanup mode (default)
Runs temp cleanup logic. By default, files are moved to rollback storage (soft-delete) rather than permanently deleted.

### Rollback mode
Restores files from a manifest created during a cleanup run.

## Parameters
### -DryRun
- Type: switch
- Default: Off
- Behavior: Lists files that would be cleaned. No file moves or deletions occur.

### -OlderThanDays
- Type: int
- Default: 0
- Behavior: Targets only files older than this many days.

### -Rollback
- Type: switch
- Default: Off
- Behavior: Enables restore workflow from a cleanup manifest.

### -ManifestPath
- Type: string
- Default: empty
- Behavior: In rollback mode, restores using the specified manifest. If omitted, the script uses the latest manifest.

### -TargetPaths
- Type: string[]
- Default: $env:TEMP and $env:WINDIR\Temp
- Behavior: Paths scanned for temp files.

### -StateRoot
- Type: string
- Default: $env:ProgramData\DWPTempCleanup
- Behavior: Base path for logs, rollback storage, and manifests.

## Logging and Artifacts
Under StateRoot, the script creates:
- Logs: ProgramData\DWPTempCleanup\Logs
- Rollback files: ProgramData\DWPTempCleanup\Rollback\run_yyyyMMdd_HHmmss
- Manifests: ProgramData\DWPTempCleanup\Manifests\manifest_yyyyMMdd_HHmmss.json

Each log line includes:
- Date and time
- Severity level (INFO, WARN, ERROR)
- Action message

## Example Commands
### 1) Preview only (safe test)
```powershell
& 'c:\Users\labuser\Documents\AI Training\Day 3\temp-cleanup-safe.ps1' -DryRun -OlderThanDays 3
```

### 2) Cleanup files older than 7 days
```powershell
& 'c:\Users\labuser\Documents\AI Training\Day 3\temp-cleanup-safe.ps1' -OlderThanDays 7
```

### 3) Cleanup with custom target paths
```powershell
& 'c:\Users\labuser\Documents\AI Training\Day 3\temp-cleanup-safe.ps1' -OlderThanDays 2 -TargetPaths @('C:\Windows\Temp','C:\Users\Public\Temp')
```

### 4) Roll back latest cleanup run
```powershell
& 'c:\Users\labuser\Documents\AI Training\Day 3\temp-cleanup-safe.ps1' -Rollback
```

### 5) Roll back from a specific manifest
```powershell
& 'c:\Users\labuser\Documents\AI Training\Day 3\temp-cleanup-safe.ps1' -Rollback -ManifestPath 'C:\ProgramData\DWPTempCleanup\Manifests\manifest_20260805_113000.json'
```

## Safety Notes
- The script does not stop on a single file error.
- Locked files are skipped and logged.
- Dry-run is recommended before live cleanup.
- Rollback is only possible for files moved by this script and present in rollback storage.

## Idempotency Behavior
- Re-running cleanup does not fail if files are already gone.
- Re-running rollback skips already-restored destinations and missing backup files with warnings.

## Summary Output
At run end, cleanup mode reports:
- Paths scanned
- Files discovered
- Eligible files
- Dry-run listed files
- Files moved
- Locked files skipped
- Missing files skipped
- Errors
