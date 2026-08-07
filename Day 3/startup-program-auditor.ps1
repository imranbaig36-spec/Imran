<#
.SYNOPSIS
Startup Program Auditor for Windows endpoints (PowerShell 5.1).

.DESCRIPTION
- Lists all programs configured to run at startup.
- Supports dry run mode to preview startup programs without making changes.
- Supports a disable flag that accepts a program name and disables matching entries.
- Skips inaccessible or protected entries and logs all actions without stopping execution.
- Uses per-entry try/catch handling.
- Writes actions to a timestamped log file.
- Produces a summary at the end.
- Designed to be idempotent (safe to run repeatedly).
#>

[CmdletBinding()]
param(
    # Preview mode only. No registry or file changes are made.
    [switch]$DryRun,

    # Program name filter used to disable matching startup entries.
    [string]$DisableProgramName,

    # Base path for logs and state artifacts.
    [string]$StateRoot = "$env:ProgramData\DWPStartupAuditor"
)

$script:RunTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$script:RunId = "run_$script:RunTimestamp"
$script:LogRoot = Join-Path $StateRoot 'Logs'
$script:DisabledRoot = Join-Path $StateRoot 'DisabledStartup'
$script:LogFile = Join-Path $script:LogRoot ("startup_audit_{0}.log" -f $script:RunTimestamp)

foreach ($dir in @($StateRoot, $script:LogRoot, $script:DisabledRoot)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
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

function Get-PathHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputPath)
        $hash = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash)).Replace('-', '').Substring(0, 12)
    } finally {
        $sha.Dispose()
    }
}

function New-StartupEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Location,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [string]$RegistryValueName,

        [string]$FilePath
    )

    [PSCustomObject]@{
        Type = $Type
        Name = $Name
        Location = $Location
        Command = $Command
        RegistryValueName = $RegistryValueName
        FilePath = $FilePath
    }
}

function Get-RegistryStartupEntries {
    param(
        [System.Collections.Generic.List[object]]$Entries,
        [hashtable]$Summary
    )

    $registryPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
    )

    foreach ($regPath in $registryPaths) {
        try {
            if (-not (Test-Path -LiteralPath $regPath)) {
                continue
            }

            $item = Get-Item -LiteralPath $regPath -ErrorAction Stop
            $valueNames = $item.GetValueNames()

            foreach ($valueName in $valueNames) {
                try {
                    $valueData = $item.GetValue($valueName, $null, 'DoNotExpandEnvironmentNames')
                    if ($null -eq $valueData) {
                        continue
                    }

                    $entry = New-StartupEntry -Type 'Registry' -Name $valueName -Location $regPath -Command ([string]$valueData) -RegistryValueName $valueName
                    $Entries.Add($entry)
                    $Summary.EntriesDiscovered++
                } catch {
                    $Summary.Errors++
                    Write-Log -Message ("Registry value read failed [{0}] {1}: {2}" -f $regPath, $valueName, $_.Exception.Message) -Level ERROR
                }
            }
        } catch {
            $Summary.SkippedInaccessible++
            Write-Log -Message ("Registry path inaccessible or protected, skipped: {0}. {1}" -f $regPath, $_.Exception.Message) -Level WARN
        }
    }
}

function Get-StartupFolderEntries {
    param(
        [System.Collections.Generic.List[object]]$Entries,
        [hashtable]$Summary
    )

    $startupFolders = @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Startup')
    )

    foreach ($folder in $startupFolders) {
        try {
            if (-not (Test-Path -LiteralPath $folder)) {
                continue
            }

            $files = Get-ChildItem -LiteralPath $folder -File -Force -ErrorAction Stop
            foreach ($file in $files) {
                try {
                    $entry = New-StartupEntry -Type 'StartupFolder' -Name $file.BaseName -Location $folder -Command $file.FullName -FilePath $file.FullName
                    $Entries.Add($entry)
                    $Summary.EntriesDiscovered++
                } catch {
                    $Summary.Errors++
                    Write-Log -Message ("Startup folder entry read failed [{0}] {1}: {2}" -f $folder, $file.Name, $_.Exception.Message) -Level ERROR
                }
            }
        } catch {
            $Summary.SkippedInaccessible++
            Write-Log -Message ("Startup folder inaccessible or protected, skipped: {0}. {1}" -f $folder, $_.Exception.Message) -Level WARN
        }
    }
}

function Disable-RegistryEntry {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry,

        [hashtable]$Summary
    )

    $disabledKeyPath = Join-Path $Entry.Location 'DisabledByDWP'

    try {
        if (-not (Test-Path -LiteralPath $Entry.Location)) {
            $Summary.SkippedNotFound++
            Write-Log -Message ("Registry entry no longer present, skipped: {0}::{1}" -f $Entry.Location, $Entry.RegistryValueName) -Level WARN
            return
        }

        if (-not (Test-Path -LiteralPath $disabledKeyPath)) {
            New-Item -Path $disabledKeyPath -Force | Out-Null
        }

        $existing = Get-ItemProperty -LiteralPath $Entry.Location -Name $Entry.RegistryValueName -ErrorAction SilentlyContinue
        if ($null -eq $existing) {
            $alreadyDisabled = Get-ItemProperty -LiteralPath $disabledKeyPath -Name $Entry.RegistryValueName -ErrorAction SilentlyContinue
            if ($null -ne $alreadyDisabled) {
                $Summary.AlreadyDisabled++
                Write-Log -Message ("Already disabled (registry): {0}::{1}" -f $Entry.Location, $Entry.RegistryValueName)
                return
            }

            $Summary.SkippedNotFound++
            Write-Log -Message ("Registry entry missing and not in disabled store: {0}::{1}" -f $Entry.Location, $Entry.RegistryValueName) -Level WARN
            return
        }

        if ($DryRun) {
            $Summary.DryRunWouldDisable++
            Write-Log -Message ("DRY-RUN disable (registry): {0}::{1}" -f $Entry.Location, $Entry.RegistryValueName)
            return
        }

        New-ItemProperty -LiteralPath $disabledKeyPath -Name $Entry.RegistryValueName -PropertyType String -Value $Entry.Command -Force | Out-Null
        Remove-ItemProperty -LiteralPath $Entry.Location -Name $Entry.RegistryValueName -Force -ErrorAction Stop

        $Summary.Disabled++
        Write-Log -Message ("Disabled (registry): {0}::{1}" -f $Entry.Location, $Entry.RegistryValueName)
    } catch {
        $Summary.Errors++
        Write-Log -Message ("Disable failed (registry) {0}::{1}: {2}" -f $Entry.Location, $Entry.RegistryValueName, $_.Exception.Message) -Level ERROR
    }
}

function Disable-StartupFolderEntry {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Entry,

        [hashtable]$Summary
    )

    try {
        if (-not (Test-Path -LiteralPath $Entry.FilePath)) {
            $Summary.AlreadyDisabled++
            Write-Log -Message ("Already disabled or moved (startup folder): {0}" -f $Entry.FilePath)
            return
        }

        $leaf = Split-Path -Path $Entry.FilePath -Leaf
        $hash = Get-PathHash -InputPath $Entry.FilePath
        $destination = Join-Path $script:DisabledRoot ("{0}_{1}" -f $hash, $leaf)

        if (Test-Path -LiteralPath $destination) {
            if ($DryRun) {
                $Summary.DryRunWouldDisable++
                Write-Log -Message ("DRY-RUN disable (startup folder): {0} -> {1}" -f $Entry.FilePath, $destination)
                return
            }

            $Summary.AlreadyDisabled++
            Write-Log -Message ("Already disabled (startup folder destination exists): {0}" -f $destination)
            return
        }

        if ($DryRun) {
            $Summary.DryRunWouldDisable++
            Write-Log -Message ("DRY-RUN disable (startup folder): {0} -> {1}" -f $Entry.FilePath, $destination)
            return
        }

        Move-Item -LiteralPath $Entry.FilePath -Destination $destination -Force -ErrorAction Stop
        $Summary.Disabled++
        Write-Log -Message ("Disabled (startup folder): {0} -> {1}" -f $Entry.FilePath, $destination)
    } catch {
        $Summary.Errors++
        Write-Log -Message ("Disable failed (startup folder) {0}: {1}" -f $Entry.FilePath, $_.Exception.Message) -Level ERROR
    }
}

function Invoke-StartupAudit {
    $summary = [ordered]@{
        EntriesDiscovered = 0
        EntriesListed = 0
        MatchesForDisable = 0
        DryRunWouldDisable = 0
        Disabled = 0
        AlreadyDisabled = 0
        SkippedInaccessible = 0
        SkippedNotFound = 0
        Errors = 0
    }

    $entries = New-Object System.Collections.Generic.List[object]

    Write-Log -Message ("Audit started. DryRun={0}, DisableProgramName={1}" -f [bool]$DryRun, $(if ([string]::IsNullOrWhiteSpace($DisableProgramName)) { '<none>' } else { $DisableProgramName }))

    Get-RegistryStartupEntries -Entries $entries -Summary $summary
    Get-StartupFolderEntries -Entries $entries -Summary $summary

    if ($entries.Count -eq 0) {
        Write-Log -Message 'No startup entries discovered.' -Level WARN
    }

    foreach ($entry in $entries) {
        try {
            $summary.EntriesListed++
            Write-Log -Message ("Startup entry [{0}] Name='{1}' Location='{2}' Command='{3}'" -f $entry.Type, $entry.Name, $entry.Location, $entry.Command)

            if ([string]::IsNullOrWhiteSpace($DisableProgramName)) {
                continue
            }

            if (($entry.Name -like "*$DisableProgramName*") -or ($entry.Command -like "*$DisableProgramName*")) {
                $summary.MatchesForDisable++

                if ($entry.Type -eq 'Registry') {
                    Disable-RegistryEntry -Entry $entry -Summary $summary
                } elseif ($entry.Type -eq 'StartupFolder') {
                    Disable-StartupFolderEntry -Entry $entry -Summary $summary
                }
            }
        } catch {
            $summary.Errors++
            Write-Log -Message ("Unexpected entry processing error [{0}] {1}: {2}" -f $entry.Type, $entry.Name, $_.Exception.Message) -Level ERROR
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($DisableProgramName) -and $summary.MatchesForDisable -eq 0) {
        Write-Log -Message ("No startup entries matched disable filter: {0}" -f $DisableProgramName) -Level WARN
    }

    Write-Log -Message (
        "Summary -> EntriesDiscovered: {0}, EntriesListed: {1}, MatchesForDisable: {2}, DryRunWouldDisable: {3}, Disabled: {4}, AlreadyDisabled: {5}, SkippedInaccessible: {6}, SkippedNotFound: {7}, Errors: {8}" -f
        $summary.EntriesDiscovered,
        $summary.EntriesListed,
        $summary.MatchesForDisable,
        $summary.DryRunWouldDisable,
        $summary.Disabled,
        $summary.AlreadyDisabled,
        $summary.SkippedInaccessible,
        $summary.SkippedNotFound,
        $summary.Errors
    )
}

try {
    Write-Log -Message ("Script start. RunId={0}" -f $script:RunId)
    Invoke-StartupAudit
    Write-Log -Message 'Script completed successfully.'
} catch {
    Write-Log -Message ("Fatal error: {0}" -f $_.Exception.Message) -Level ERROR
    throw
}
