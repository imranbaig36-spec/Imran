<#
Endpoint Health Diagnostic (Read-Only)
PowerShell target: Windows PowerShell 5.1

This script gathers endpoint health indicators without changing system state.
No remediation, writes, registry modifications, or service changes are performed.

TO CONFIRM BEFORE RUNNING:
- Run context: Some event log and user-session queries may need elevated rights.
- Internet speed: This script uses built-in network transfer timing only. If your standard is Ookla speedtest, validate that `speedtest` CLI is approved and installed.
- Logged-in user count: Session tooling can vary between physical devices and VDI.
#>

Write-Host "=== DWP Endpoint Health Report (Read-Only) ==="
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host ""

# 1) System uptime: Calculates uptime from last OS boot timestamp.
Write-Host "[1] System Uptime"
$os = Get-CimInstance Win32_OperatingSystem
$lastBoot = $os.LastBootUpTime
$uptime = (Get-Date) - $lastBoot
Write-Host ("Last Boot: {0}" -f $lastBoot)
Write-Host ("Uptime: {0} days {1} hours {2} minutes" -f [int]$uptime.TotalDays, $uptime.Hours, $uptime.Minutes)
Write-Host ""

# 2) Free disk space: Reports total/free GB and percent free for local fixed drives.
Write-Host "[2] Free Disk Space"
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
    Select-Object DeviceID,
                  @{Name='SizeGB';Expression={[math]::Round($_.Size / 1GB, 2)}},
                  @{Name='FreeGB';Expression={[math]::Round($_.FreeSpace / 1GB, 2)}},
                  @{Name='FreePercent';Expression={if ($_.Size -gt 0) {[math]::Round(($_.FreeSpace / $_.Size) * 100, 2)} else {0}}} |
    Format-Table -AutoSize
Write-Host ""

# 3) Pending reboot: Checks common registry keys that indicate reboot pending state.
Write-Host "[3] Pending Reboot Status"
$pendingRebootPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
)

$pendingReboot = $false
$pendingFlags = @()

if (Test-Path $pendingRebootPaths[0]) { $pendingReboot = $true; $pendingFlags += 'CBS RebootPending key exists' }
if (Test-Path $pendingRebootPaths[1]) { $pendingReboot = $true; $pendingFlags += 'WindowsUpdate RebootRequired key exists' }

$sessionManager = Get-ItemProperty -Path $pendingRebootPaths[2] -ErrorAction SilentlyContinue
if ($sessionManager -and $sessionManager.PendingFileRenameOperations) {
    $pendingReboot = $true
    $pendingFlags += 'PendingFileRenameOperations present'
}

Write-Host ("Pending reboot: {0}" -f $pendingReboot)
if ($pendingFlags.Count -gt 0) {
    $pendingFlags | ForEach-Object { Write-Host ("- {0}" -f $_) }
}
Write-Host ""

# 4) Top 5 processes by memory working set: Highest current RAM consumers.
Write-Host "[4] Top 5 Processes by Memory (Working Set)"
Get-Process |
    Sort-Object WorkingSet -Descending |
    Select-Object -First 5 Name, Id,
        @{Name='WorkingSetMB';Expression={[math]::Round($_.WorkingSet / 1MB, 2)}} |
    Format-Table -AutoSize
Write-Host ""

# 5) Top 5 processes by CPU: Highest cumulative CPU time consumers.
Write-Host "[5] Top 5 Processes by CPU"
Get-Process |
    Sort-Object CPU -Descending |
    Select-Object -First 5 Name, Id,
        @{Name='CPUSeconds';Expression={if ($_.CPU) {[math]::Round($_.CPU, 2)} else {0}}} |
    Format-Table -AutoSize
Write-Host ""

# 6) Last 5 System log errors: Pulls recent error entries from the System log.
Write-Host "[6] Last 5 System Log Errors"
try {
    Get-WinEvent -FilterHashtable @{LogName='System'; Level=2} -MaxEvents 5 |
        Select-Object TimeCreated, Id, ProviderName, Message |
        Format-Table -Wrap -AutoSize
} catch {
    Write-Host "Unable to read System log errors (to confirm permissions)."
    Write-Host $_.Exception.Message
}
Write-Host ""

# 7) Internet speed: Uses transfer timing to estimate download throughput.
# TO CONFIRM: If all public endpoints are blocked, use an approved internal test URL.
Write-Host "[7] Internet Speed (Estimated Download Throughput)"
$testEndpoints = @(
    @{ Name = 'OVH'; Url = 'https://proof.ovh.net/files/10Mb.dat' },
    @{ Name = 'ThinkBroadband'; Url = 'https://ipv4.download.thinkbroadband.com/10MB.zip' },
    @{ Name = 'CacheFly'; Url = 'https://cachefly.cachefly.net/10mb.test' }
)

$speedMeasured = $false
$speedErrors = @()

foreach ($endpoint in $testEndpoints) {
    $uri = [Uri]$endpoint.Url

    try {
        [void][System.Net.Dns]::GetHostAddresses($uri.Host)
    } catch {
        $speedErrors += ("{0}: DNS resolution failed for {1} ({2})" -f $endpoint.Name, $uri.Host, $_.Exception.Message)
        continue
    }

    $tempFile = Join-Path $env:TEMP (("dwp-speedtest-{0}.bin" -f ([System.IO.Path]::GetRandomFileName())))
    try {
        $result = Measure-Command {
            Invoke-WebRequest -Uri $endpoint.Url -OutFile $tempFile -UseBasicParsing -ErrorAction Stop
        }

        $sizeBytes = (Get-Item $tempFile -ErrorAction Stop).Length
        $mbits = ($sizeBytes * 8) / 1MB
        $seconds = [math]::Max($result.TotalSeconds, 0.001)
        $mbps = [math]::Round($mbits / $seconds, 2)

        Write-Host ("Endpoint: {0}" -f $endpoint.Name)
        Write-Host ("URL: {0}" -f $endpoint.Url)
        Write-Host ("Test file size: {0} MB" -f [math]::Round($sizeBytes / 1MB, 2))
        Write-Host ("Elapsed: {0} sec" -f [math]::Round($seconds, 2))
        Write-Host ("Estimated throughput: {0} Mbps" -f $mbps)

        $speedMeasured = $true
        break
    } catch {
        $speedErrors += ("{0}: Download failed ({1})" -f $endpoint.Name, $_.Exception.Message)
    } finally {
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not $speedMeasured) {
    Write-Host "Internet speed estimate could not be measured (to confirm network/proxy/URL access)."
    if ($speedErrors.Count -gt 0) {
        Write-Host "Attempt summary:"
        $speedErrors | ForEach-Object { Write-Host ("- {0}" -f $_) }
    }
    Write-Host "to confirm: provide an approved internal test download URL for managed network measurement."
}
Write-Host ""

# 8) Microsoft Defender service state: Checks if WinDefend service is running.
Write-Host "[8] Microsoft Defender Service State"
$defenderService = Get-Service -Name WinDefend -ErrorAction SilentlyContinue
if ($null -eq $defenderService) {
    Write-Host "WinDefend service not found (to confirm endpoint security stack/policy)."
} else {
    Write-Host ("Service Name: {0}" -f $defenderService.Name)
    Write-Host ("Status: {0}" -f $defenderService.Status)
    Write-Host ("StartType: {0}" -f $defenderService.StartType)
}
Write-Host ""

# 9) Logged-in users count: Counts active user sessions returned by quser.
# TO CONFIRM: VDI/RDS environments may show service/disconnected sessions differently.
Write-Host "[9] Logged-In Users Count"
try {
    $quserOutput = quser 2>$null
    if ($LASTEXITCODE -eq 0 -and $quserOutput) {
        $sessionLines = $quserOutput | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne '' }
        $users = @()
        foreach ($line in $sessionLines) {
            $normalized = ($line -replace '^\s*>?\s*', '')
            $username = ($normalized -split '\s+')[0]
            if ($username) { $users += $username }
        }
        $uniqueUsers = $users | Sort-Object -Unique
        Write-Host ("Logged-in users count: {0}" -f $uniqueUsers.Count)
        if ($uniqueUsers.Count -gt 0) {
            Write-Host ("Users: {0}" -f ($uniqueUsers -join ', '))
        }
    } else {
        Write-Host "Unable to query sessions with quser (to confirm permissions/environment)."
    }
} catch {
    Write-Host "Failed to determine logged-in users count (to confirm)."
    Write-Host $_.Exception.Message
}
Write-Host ""

# 10) Last Windows update: Reports most recently installed hotfix/update entry.
Write-Host "[10] Last Windows Update Installed"
try {
    $lastUpdate = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
    if ($lastUpdate) {
        Write-Host ("HotFixID: {0}" -f $lastUpdate.HotFixID)
        Write-Host ("InstalledOn: {0}" -f $lastUpdate.InstalledOn)
        Write-Host ("Description: {0}" -f $lastUpdate.Description)
    } else {
        Write-Host "No hotfix records returned (to confirm WMI history availability)."
    }
} catch {
    Write-Host "Unable to read update history from Get-HotFix (to confirm permissions)."
    Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "=== End of Read-Only Report ==="