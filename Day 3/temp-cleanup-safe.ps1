<#
.SYNOPSIS
Safe temp-file cleanup script for Windows endpoints (PowerShell 5.1).

.DESCRIPTION
- Cleans temp files older than a configurable number of days.
- Supports dry run mode to preview what would be removed.
- Skips locked files and logs all actions without stopping execution.
- Uses per-file try/catch handling.
- Writes actions to a timestamped log file.
- Produces a summary at the end.
- Supports rollback by restoring files from a run manifest.
- Designed to be idempotent (safe to run repeatedly).

.NOTES
Default behavior uses "soft delete" (move to rollback store) to enable rollback.
#>

[CmdletBinding()]
param(
    # When set, the script only lists files that would be cleaned and does not move/delete anything.
    [switch]$DryRun,

    # Only files older than this many days are targeted. Default 0 means "older than now".
    [ValidateRange(0, 3650)]
    [int]$OlderThanDays = 0,

    # Rollback mode restores files from a previous run manifest.
    [switch]$Rollback,

    # Optional manifest path for rollback. If not provided, the latest manifest is used.
    [string]$ManifestPath,

    # Temp paths to scan. Defaults cover user temp and Windows temp.
    [string[]]$TargetPaths = @($env:TEMP, "$env:WINDIR\Temp"),

    # Base path for logs and rollback artifacts.
    [string]$StateRoot = "$env:ProgramData\DWPTempCleanup"
)

# Section: Initialize folders, run identifiers, and output file paths.
$script:RunTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:RunId = "run_$script:RunTimestamp"
$script:LogRoot = Join-Path $StateRoot 'Logs'
$script:RollbackRoot = Join-Path $StateRoot 'Rollback'
$script:ManifestRoot = Join-Path $StateRoot 'Manifests'
$script:LogFile = Join-Path $script:LogRoot ("cleanup_{0}.log" -f $script:RunTimestamp)

foreach ($dir in @($StateRoot, $script:LogRoot, $script:RollbackRoot, $script:ManifestRoot)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Section: Central logging helper to write timestamped records to console and log file.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -Path $script:LogFile -Value $line
}

# Section: Determines whether a file is locked by trying to open with exclusive access.
function Test-FileLocked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $stream.Close()
        return $false
    } catch {
        return $true
    }
}

# Section: Creates a stable hash to build unique backup file names.
function Get-PathHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputPath)
        $hash = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash)).Replace('-', '').Substring(0, 16)
    } finally {
        $sha.Dispose()
    }
}

# Section: Rollback mode restores files from manifest to original locations.
function Invoke-Rollback {
    param(
        [string]$Manifest
    )

    if (-not $Manifest) {
        $latest = Get-ChildItem -Path $script:ManifestRoot -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($null -eq $latest) {
            throw "No rollback manifest found in $script:ManifestRoot"
        }

        $Manifest = $latest.FullName
    }

    if (-not (Test-Path -LiteralPath $Manifest)) {
        throw "Manifest not found: $Manifest"
    }

    Write-Log -Message ("Rollback started. Manifest: {0}" -f $Manifest)

    $entries = Get-Content -Path $Manifest -Raw | ConvertFrom-Json

    if ($null -eq $entries -or $entries.Count -eq 0) {
        Write-Log -Message "Manifest has no entries. Nothing to restore." -Level WARN
        return
    }

    $restored = 0
    $skipped = 0
    $errors = 0

    foreach ($entry in $entries) {
        try {
            $src = $entry.BackupPath
            $dst = $entry.OriginalPath

            if (-not (Test-Path -LiteralPath $src)) {
                Write-Log -Message ("Skip restore (missing backup): {0}" -f $src) -Level WARN
                $skipped++
                continue
            }

            if (Test-Path -LiteralPath $dst) {
                Write-Log -Message ("Skip restore (destination exists): {0}" -f $dst) -Level WARN
                $skipped++
                continue
            }

            $dstDir = Split-Path -Parent $dst
            if (-not (Test-Path -LiteralPath $dstDir)) {
                New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            }

            Move-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
            Write-Log -Message ("Restored: {0}" -f $dst)
            $restored++
        } catch {
            Write-Log -Message ("Restore error for {0}: {1}" -f $entry.OriginalPath, $_.Exception.Message) -Level ERROR
            $errors++
        }
    }

    Write-Log -Message ("Rollback summary -> Restored: {0}, Skipped: {1}, Errors: {2}" -f $restored, $skipped, $errors)
}

# Section: Main cleanup mode scans temp files, filters by age, and moves candidates to rollback store.
function Invoke-Cleanup {
    $cutoff = (Get-Date).AddDays(-1 * $OlderThanDays)
    $runRollbackDir = Join-Path $script:RollbackRoot $script:RunId

    if (-not (Test-Path -LiteralPath $runRollbackDir)) {
        New-Item -ItemType Directory -Path $runRollbackDir -Force | Out-Null
    }

    $manifestEntries = New-Object System.Collections.Generic.List[object]

    $summary = [ordered]@{
        PathsScanned = 0
        FilesDiscovered = 0
        FilesEligible = 0
        DryRunListed = 0
        FilesMoved = 0
        LockedSkipped = 0
        MissingSkipped = 0
        Errors = 0
    }

    Write-Log -Message ("Cleanup started. OlderThanDays={0}, Cutoff={1}, DryRun={2}" -f $OlderThanDays, $cutoff, [bool]$DryRun)

    foreach ($targetPath in $TargetPaths) {
        if ([string]::IsNullOrWhiteSpace($targetPath)) {
            continue
        }

        $summary.PathsScanned++

        if (-not (Test-Path -LiteralPath $targetPath)) {
            Write-Log -Message ("Target path not found, skipped: {0}" -f $targetPath) -Level WARN
            continue
        }

        Write-Log -Message ("Scanning path: {0}" -f $targetPath)

        $files = Get-ChildItem -LiteralPath $targetPath -File -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $summary.FilesDiscovered++

            # Idempotency guard: if file is already absent by the time we handle it, skip safely.
            if (-not (Test-Path -LiteralPath $file.FullName)) {
                $summary.MissingSkipped++
                Write-Log -Message ("Skip missing file: {0}" -f $file.FullName) -Level WARN
                continue
            }

            if ($file.LastWriteTime -ge $cutoff) {
                continue
            }

            $summary.FilesEligible++

            if ($DryRun) {
                Write-Log -Message ("DRY-RUN candidate: {0}" -f $file.FullName)
                $summary.DryRunListed++
                continue
            }

            try {
                if (Test-FileLocked -Path $file.FullName) {
                    $summary.LockedSkipped++
                    Write-Log -Message ("Skip locked file: {0}" -f $file.FullName) -Level WARN
                    continue
                }

                $ext = [System.IO.Path]::GetExtension($file.Name)
                $hash = Get-PathHash -InputPath $file.FullName
                $safeName = "{0}_{1}{2}" -f $file.LastWriteTime.ToString('yyyyMMddHHmmss'), $hash, $ext
                $backupPath = Join-Path $runRollbackDir $safeName

                Move-Item -LiteralPath $file.FullName -Destination $backupPath -Force -ErrorAction Stop

                $manifestEntries.Add([PSCustomObject]@{
                    OriginalPath = $file.FullName
                    BackupPath = $backupPath
                    LastWriteTime = $file.LastWriteTime
                    Length = $file.Length
                    RunId = $script:RunId
                    MovedAt = Get-Date
                })

                $summary.FilesMoved++
                Write-Log -Message ("Moved to rollback store: {0} -> {1}" -f $file.FullName, $backupPath)
            } catch {
                $summary.Errors++
                Write-Log -Message ("Error handling file {0}: {1}" -f $file.FullName, $_.Exception.Message) -Level ERROR
            }
        }
    }

    # Section: Persist manifest for rollback and print summary output.
    if (-not $DryRun -and $manifestEntries.Count -gt 0) {
        $manifestPath = Join-Path $script:ManifestRoot ("manifest_{0}.json" -f $script:RunTimestamp)
        $manifestEntries | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding UTF8
        Write-Log -Message ("Rollback manifest saved: {0}" -f $manifestPath)
    } elseif (-not $DryRun) {
        Write-Log -Message "No files moved. Manifest not created."
    }

    Write-Log -Message (
        "Cleanup summary -> PathsScanned: {0}, FilesDiscovered: {1}, FilesEligible: {2}, DryRunListed: {3}, FilesMoved: {4}, LockedSkipped: {5}, MissingSkipped: {6}, Errors: {7}" -f
        $summary.PathsScanned,
        $summary.FilesDiscovered,
        $summary.FilesEligible,
        $summary.DryRunListed,
        $summary.FilesMoved,
        $summary.LockedSkipped,
        $summary.MissingSkipped,
        $summary.Errors
    )
}

# Section: Entry point selects cleanup or rollback mode.
try {
    Write-Log -Message ("Script start. Mode={0}" -f ($(if ($Rollback) { 'Rollback' } else { 'Cleanup' })))

    if ($Rollback) {
        Invoke-Rollback -Manifest $ManifestPath
    } else {
        Invoke-Cleanup
    }

    Write-Log -Message "Script completed successfully."
} catch {
    Write-Log -Message ("Fatal error: {0}" -f $_.Exception.Message) -Level ERROR
    throw
}
