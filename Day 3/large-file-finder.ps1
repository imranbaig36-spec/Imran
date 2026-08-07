<#
.SYNOPSIS
Large File Finder for Windows endpoints (PowerShell 5.1).

.DESCRIPTION
- Read-only script that finds and reports large files.
- Accepts a size threshold as input, defaulting to 100 MB.
- Skips locked or inaccessible files and logs all actions without stopping execution.
- Uses per-file try/catch handling.
- Writes actions to a timestamped log file.
- Produces a summary at the end.
- Designed to be idempotent (safe to run repeatedly).
#>

[CmdletBinding()]
param(
    # Minimum file size in MB to report.
    [ValidateRange(1, 1048576)]
    [int]$SizeThresholdMB = 100,

    # Paths to scan recursively.
    [string[]]$TargetPaths = @($env:USERPROFILE, "$env:WINDIR\Temp"),

    # Base path for logs and optional report output.
    [string]$StateRoot = "$env:ProgramData\DWPLargeFileFinder",

    # Optional CSV report output path. If omitted, report is saved under StateRoot.
    [string]$ReportPath
)

$script:RunTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:RunId = "run_$script:RunTimestamp"
$script:LogRoot = Join-Path $StateRoot 'Logs'
$script:ReportRoot = Join-Path $StateRoot 'Reports'
$script:LogFile = Join-Path $script:LogRoot ("large_file_finder_{0}.log" -f $script:RunTimestamp)

foreach ($dir in @($StateRoot, $script:LogRoot, $script:ReportRoot)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $script:ReportFile = Join-Path $script:ReportRoot ("large_files_{0}.csv" -f $script:RunTimestamp)
} else {
    $script:ReportFile = $ReportPath
    $reportDir = Split-Path -Path $script:ReportFile -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDir) -and -not (Test-Path -LiteralPath $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
    }
}

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

function Test-FileLocked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
        $stream.Close()
        return $false
    } catch {
        return $true
    }
}

function Format-Bytes {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Bytes
    )

    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "{0:N0} B" -f $Bytes
}

function Invoke-LargeFileScan {
    $thresholdBytes = [int64]$SizeThresholdMB * 1MB

    $summary = [ordered]@{
        PathsScanned = 0
        PathsMissing = 0
        FilesDiscovered = 0
        FilesChecked = 0
        MatchesFound = 0
        LockedSkipped = 0
        InaccessibleSkipped = 0
        MissingDuringProcessing = 0
        Errors = 0
    }

    $results = New-Object System.Collections.Generic.List[object]

    Write-Log -Message ("Scan started. RunId={0}, ThresholdMB={1}, ThresholdBytes={2}" -f $script:RunId, $SizeThresholdMB, $thresholdBytes)

    foreach ($targetPath in $TargetPaths) {
        if ([string]::IsNullOrWhiteSpace($targetPath)) {
            continue
        }

        $summary.PathsScanned++

        if (-not (Test-Path -LiteralPath $targetPath)) {
            $summary.PathsMissing++
            Write-Log -Message ("Target path not found, skipped: {0}" -f $targetPath) -Level WARN
            continue
        }

        Write-Log -Message ("Scanning path: {0}" -f $targetPath)

        $files = Get-ChildItem -LiteralPath $targetPath -File -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $summary.FilesDiscovered++

            try {
                if (-not (Test-Path -LiteralPath $file.FullName)) {
                    $summary.MissingDuringProcessing++
                    Write-Log -Message ("Skip missing file: {0}" -f $file.FullName) -Level WARN
                    continue
                }

                if (Test-FileLocked -Path $file.FullName) {
                    $summary.LockedSkipped++
                    Write-Log -Message ("Skip locked file: {0}" -f $file.FullName) -Level WARN
                    continue
                }

                $refreshedFile = Get-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $summary.FilesChecked++

                if ($refreshedFile.Length -ge $thresholdBytes) {
                    $summary.MatchesFound++

                    $record = [PSCustomObject]@{
                        FullName = $refreshedFile.FullName
                        LengthBytes = $refreshedFile.Length
                        LengthHuman = Format-Bytes -Bytes $refreshedFile.Length
                        LastWriteTime = $refreshedFile.LastWriteTime
                    }

                    $results.Add($record)
                    Write-Log -Message ("MATCH: {0} ({1})" -f $refreshedFile.FullName, (Format-Bytes -Bytes $refreshedFile.Length))
                }
            } catch [System.UnauthorizedAccessException] {
                $summary.InaccessibleSkipped++
                Write-Log -Message ("Skip inaccessible file: {0}. {1}" -f $file.FullName, $_.Exception.Message) -Level WARN
            } catch {
                $summary.Errors++
                Write-Log -Message ("Error processing file {0}: {1}" -f $file.FullName, $_.Exception.Message) -Level ERROR
            }
        }
    }

    if ($results.Count -gt 0) {
        $results |
            Sort-Object LengthBytes -Descending |
            Export-Csv -Path $script:ReportFile -NoTypeInformation -Encoding UTF8

        Write-Log -Message ("Report saved: {0}" -f $script:ReportFile)
    } else {
        Write-Log -Message 'No files matched the threshold. Report not generated.' -Level WARN
    }

    Write-Log -Message (
        "Summary -> PathsScanned: {0}, PathsMissing: {1}, FilesDiscovered: {2}, FilesChecked: {3}, MatchesFound: {4}, LockedSkipped: {5}, InaccessibleSkipped: {6}, MissingDuringProcessing: {7}, Errors: {8}" -f
        $summary.PathsScanned,
        $summary.PathsMissing,
        $summary.FilesDiscovered,
        $summary.FilesChecked,
        $summary.MatchesFound,
        $summary.LockedSkipped,
        $summary.InaccessibleSkipped,
        $summary.MissingDuringProcessing,
        $summary.Errors
    )
}

try {
    Write-Log -Message 'Script start. Mode=ReadOnlyScan'
    Invoke-LargeFileScan
    Write-Log -Message 'Script completed successfully.'
} catch {
    Write-Log -Message ("Fatal error: {0}" -f $_.Exception.Message) -Level ERROR
    throw
}
