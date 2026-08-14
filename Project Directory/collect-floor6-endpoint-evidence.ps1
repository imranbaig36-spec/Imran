<#
.SYNOPSIS
Collects read-only endpoint evidence for Floor 6 deployment impact triage.

.DESCRIPTION
This script collects incident evidence to test the hypothesis that a Friday
Document Management System (DMS) deployment caused Monday login, performance,
profile, and shortcut anomalies.

The script is read-only:
- No software uninstall
- No registry writes
- No service/process manipulation
- No policy or configuration changes

Artifacts are written to a timestamped output folder as JSON, CSV, and TXT.

.PARAMETER OutputRoot
Parent directory where the evidence folder will be created.

.PARAMETER IncidentTag
Tag included in summary and transcript metadata.

.PARAMETER DmsNamePatterns
Name fragments used to identify deployment-related software, services,
scheduled tasks, and event records.

.PARAMETER DeploymentWindowStart
Start of the suspected deployment impact window.

.PARAMETER DeploymentWindowEnd
End of the suspected deployment impact window.

.PARAMETER EventHoursBack
How many hours of event history to collect.

.PARAMETER DryRun
Shows exactly what would be collected and where output would be written,
without collecting data or writing artifacts.

.EXAMPLE
.\collect-floor6-endpoint-evidence.ps1 -OutputRoot C:\IR -IncidentTag Floor6-DMS

.EXAMPLE
.\collect-floor6-endpoint-evidence.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputRoot = $PSScriptRoot,

    [Parameter()]
    [string]$IncidentTag = "Floor6-DMS-Incident",

    [Parameter()]
    [string[]]$DmsNamePatterns = @(
        "document",
        "management",
        "dms",
        "legal",
        "matter",
        "copilot"
    ),

    [Parameter()]
    [datetime]$DeploymentWindowStart = (Get-Date).Date.AddDays(-3),

    [Parameter()]
    [datetime]$DeploymentWindowEnd = (Get-Date),

    [Parameter()]
    [ValidateRange(1, 720)]
    [int]$EventHoursBack = 96,

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = (Get-Location).Path
}

$script:CollectorErrors = New-Object System.Collections.Generic.List[object]

function Write-Info {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$stamp] $Message"
}

function Add-CollectorError {
    param(
        [string]$Step,
        [string]$ErrorMessage
    )
    $script:CollectorErrors.Add([pscustomobject]@{
        TimeUtc  = (Get-Date).ToUniversalTime().ToString("o")
        Step     = $Step
        Error    = $ErrorMessage
    }) | Out-Null
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Convert-UninstallDate {
    param([string]$InstallDateRaw)
    if ([string]::IsNullOrWhiteSpace($InstallDateRaw)) { return $null }
    if ($InstallDateRaw -match "^\d{8}$") {
        try {
            return [datetime]::ParseExact($InstallDateRaw, "yyyyMMdd", $null)
        }
        catch {
            return $null
        }
    }
    try {
        return [datetime]::Parse($InstallDateRaw)
    }
    catch {
        return $null
    }
}

function Invoke-Collector {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Script
    )

    try {
        Write-Info "Collecting: $Name"
        & $Script
    }
    catch {
        Add-CollectorError -Step $Name -ErrorMessage $_.Exception.Message
        Write-Warning "Collector failed: $Name - $($_.Exception.Message)"
        return $null
    }
}

function Export-JsonFile {
    param(
        [Parameter(Mandatory = $true)]$Data,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Depth = 8
    )

    if ($DryRun) {
        Write-Info "[DryRun] Would write JSON: $Path"
        return
    }

    $Data | ConvertTo-Json -Depth $Depth | Out-File -FilePath $Path -Encoding UTF8
}

function Export-CsvFile {
    param(
        [Parameter(Mandatory = $true)]$Data,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ($DryRun) {
        Write-Info "[DryRun] Would write CSV: $Path"
        return
    }

    if ($null -eq $Data) {
        @() | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        return
    }

    @($Data) | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

function Get-InstalledSoftware {
    $uninstallRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $items = foreach ($root in $uninstallRoots) {
        if (Test-Path ($root -replace "\\\*$", "")) {
            Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.DisplayName) } |
                ForEach-Object {
                    $installDate = Convert-UninstallDate -InstallDateRaw $_.InstallDate
                    [pscustomobject]@{
                        DisplayName     = $_.DisplayName
                        DisplayVersion  = $_.DisplayVersion
                        Publisher       = $_.Publisher
                        InstallDate     = $installDate
                        InstallDateRaw  = $_.InstallDate
                        InstallLocation = $_.InstallLocation
                        UninstallString = $_.UninstallString
                        QuietUninstall  = $_.QuietUninstallString
                        RegistryPath    = $_.PSPath
                    }
                }
        }
    }

    $items | Sort-Object DisplayName, DisplayVersion -Unique
}

function Get-StartupApplications {
    $entries = @()

    $runLocations = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($loc in $runLocations) {
        if (Test-Path $loc) {
            $props = Get-ItemProperty -Path $loc
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -in "PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider") { continue }
                $entries += [pscustomobject]@{
                    Source       = "RegistryRun"
                    Location     = $loc
                    Name         = $p.Name
                    Command      = [string]$p.Value
                    LastWriteTime = (Get-Item -Path $loc).LastWriteTime
                }
            }
        }
    }

    $startupFolders = @(
        [Environment]::GetFolderPath("CommonStartup"),
        [Environment]::GetFolderPath("Startup")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($folder in $startupFolders) {
        if (Test-Path $folder) {
            Get-ChildItem -Path $folder -File -ErrorAction SilentlyContinue | ForEach-Object {
                $entries += [pscustomobject]@{
                    Source       = "StartupFolder"
                    Location     = $folder
                    Name         = $_.Name
                    Command      = $_.FullName
                    LastWriteTime = $_.LastWriteTime
                }
            }
        }
    }

    $entries
}

function Get-ScheduledTaskEvidence {
    $regex = ($DmsNamePatterns | ForEach-Object { [regex]::Escape($_) }) -join "|"

    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
    if ($null -eq $tasks) { return @() }

    foreach ($t in $tasks) {
        $info = $null
        try {
            $info = Get-ScheduledTaskInfo -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction Stop
        }
        catch {
            $info = $null
        }

        $actions = @($t.Actions | ForEach-Object {
            if ($_.Arguments) {
                "$($_.Execute) $($_.Arguments)"
            }
            else {
                [string]$_.Execute
            }
        }) -join "; "

        $isRelated = $false
        if ($regex) {
            if ($t.TaskName -match $regex -or $actions -match $regex) {
                $isRelated = $true
            }
        }

        [pscustomobject]@{
            TaskName       = $t.TaskName
            TaskPath       = $t.TaskPath
            State          = $t.State
            LastRunTime    = if ($info) { $info.LastRunTime } else { $null }
            LastTaskResult = if ($info) { $info.LastTaskResult } else { $null }
            NextRunTime    = if ($info) { $info.NextRunTime } else { $null }
            Author         = $t.Author
            Actions        = $actions
            IsDmsRelated   = $isRelated
        }
    }
}

function Get-ProcessEvidence {
    $wmi = @{}
    Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | ForEach-Object {
        $wmi[[int]$_.ProcessId] = $_
    }

    foreach ($p in Get-Process -ErrorAction SilentlyContinue) {
        $cmd = $null
        if ($wmi.ContainsKey([int]$p.Id)) {
            $cmd = $wmi[[int]$p.Id].CommandLine
        }

        [pscustomobject]@{
            Name        = $p.ProcessName
            Id          = $p.Id
            CPUSeconds  = $p.CPU
            WorkingSetMB = [math]::Round($p.WorkingSet64 / 1MB, 2)
            PMMB        = [math]::Round($p.PM / 1MB, 2)
            StartTime   = (try { $p.StartTime } catch { $null })
            Path        = (try { $p.Path } catch { $null })
            CommandLine = $cmd
        }
    }
}

function Get-PerformanceSnapshot {
    $cpu = $null
    try {
        $cpuSample = Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 3
        $vals = $cpuSample.CounterSamples | Select-Object -ExpandProperty CookedValue
        if ($vals) {
            $cpu = [math]::Round((($vals | Measure-Object -Average).Average), 2)
        }
    }
    catch {
        Add-CollectorError -Step "PerformanceSnapshot.CPU" -ErrorMessage $_.Exception.Message
    }

    $os = Get-CimInstance Win32_OperatingSystem
    $totalMB = [math]::Round($os.TotalVisibleMemorySize / 1024, 2)
    $freeMB = [math]::Round($os.FreePhysicalMemory / 1024, 2)
    $usedMB = [math]::Round($totalMB - $freeMB, 2)
    $usedPct = if ($totalMB -gt 0) { [math]::Round((($usedMB / $totalMB) * 100), 2) } else { $null }

    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $sizeGB = if ($_.Size) { [math]::Round($_.Size / 1GB, 2) } else { $null }
        $freeGB = if ($_.FreeSpace) { [math]::Round($_.FreeSpace / 1GB, 2) } else { $null }
        $usedPctDisk = if ($_.Size -and $_.Size -gt 0) {
            [math]::Round(((($_.Size - $_.FreeSpace) / $_.Size) * 100), 2)
        }
        else {
            $null
        }

        [pscustomobject]@{
            Drive      = $_.DeviceID
            VolumeName = $_.VolumeName
            FileSystem = $_.FileSystem
            SizeGB     = $sizeGB
            FreeGB     = $freeGB
            UsedPct    = $usedPctDisk
        }
    }

    [pscustomobject]@{
        CpuPercentAverage = $cpu
        MemoryTotalMB     = $totalMB
        MemoryUsedMB      = $usedMB
        MemoryFreeMB      = $freeMB
        MemoryUsedPct     = $usedPct
        Disks             = $disks
    }
}

function Get-ServiceEvidence {
    $regex = ($DmsNamePatterns | ForEach-Object { [regex]::Escape($_) }) -join "|"

    Get-CimInstance Win32_Service | ForEach-Object {
        $related = $false
        if ($regex) {
            if ($_.Name -match $regex -or $_.DisplayName -match $regex -or $_.PathName -match $regex) {
                $related = $true
            }
        }

        [pscustomobject]@{
            Name        = $_.Name
            DisplayName = $_.DisplayName
            State       = $_.State
            StartMode   = $_.StartMode
            StartName   = $_.StartName
            PathName    = $_.PathName
            ProcessId   = $_.ProcessId
            IsDmsRelated = $related
        }
    }
}

function Get-WinEventSafe {
    param(
        [Parameter(Mandatory = $true)][string]$LogName,
        [int[]]$Ids,
        [datetime]$StartTime,
        [int]$MaxEvents = 500
    )

    try {
        $logMeta = Get-WinEvent -ListLog $LogName -ErrorAction Stop
        if (-not $logMeta.IsEnabled) {
            return @()
        }

        $fh = @{
            LogName = $LogName
        }
        if ($StartTime) {
            $fh.StartTime = $StartTime
        }
        if ($Ids -and $Ids.Count -gt 0) {
            $fh.Id = $Ids
        }

        Get-WinEvent -FilterHashtable $fh -ErrorAction Stop -MaxEvents $MaxEvents |
            Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, MachineName, Message
    }
    catch {
        Add-CollectorError -Step ("EventLog." + $LogName) -ErrorMessage $_.Exception.Message
        return @()
    }
}

function Get-GroupPolicyResult {
    param([string]$OutHtmlPath)

    if ($DryRun) {
        Write-Info "[DryRun] Would run gpresult and write: $OutHtmlPath"
        return [pscustomobject]@{ Success = $true; Path = $OutHtmlPath; Message = "DryRun" }
    }

    try {
        & gpresult.exe /H $OutHtmlPath /F | Out-Null
        return [pscustomobject]@{ Success = $true; Path = $OutHtmlPath; Message = "gpresult completed" }
    }
    catch {
        Add-CollectorError -Step "GroupPolicyResult" -ErrorMessage $_.Exception.Message
        return [pscustomobject]@{ Success = $false; Path = $OutHtmlPath; Message = $_.Exception.Message }
    }
}

function Get-UserProfileEvidence {
    $profiles = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | ForEach-Object {
        $lastUse = $null
        if ($_.LastUseTime) {
            try {
                $lastUse = [Management.ManagementDateTimeConverter]::ToDateTime($_.LastUseTime)
            }
            catch {
                $lastUse = $null
            }
        }

        [pscustomobject]@{
            SID       = $_.SID
            LocalPath = $_.LocalPath
            Loaded    = $_.Loaded
            Special   = $_.Special
            Status    = $_.Status
            LastUseTime = $lastUse
        }
    }

    $desktopRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    $desktopRaw = $null
    $desktopExpanded = $null
    if (Test-Path $desktopRegPath) {
        try {
            $desktopRaw = (Get-ItemProperty -Path $desktopRegPath -Name Desktop -ErrorAction Stop).Desktop
            $desktopExpanded = [Environment]::ExpandEnvironmentVariables($desktopRaw)
        }
        catch {
            Add-CollectorError -Step "UserProfile.DesktopRegistry" -ErrorMessage $_.Exception.Message
        }
    }

    $defaultDesktop = Join-Path -Path $env:USERPROFILE -ChildPath "Desktop"
    $folderRedirection = $false
    if ($desktopExpanded) {
        $folderRedirection = ($desktopExpanded -ne $defaultDesktop)
    }

    $isOneDriveDesktop = $false
    if ($desktopExpanded -and $desktopExpanded -match "OneDrive") {
        $isOneDriveDesktop = $true
    }

    $tempProfileIndicators = @()
    $tempProfiles = $profiles | Where-Object { $_.LocalPath -match "\\TEMP($|\\)" }
    foreach ($tp in $tempProfiles) {
        $tempProfileIndicators += "Temporary-like profile path detected: $($tp.LocalPath)"
    }

    [pscustomobject]@{
        CurrentUser                = [Environment]::UserName
        CurrentUserDomain          = $env:USERDOMAIN
        UserProfilePath            = $env:USERPROFILE
        DesktopPathRegistryRaw     = $desktopRaw
        DesktopPathExpanded        = $desktopExpanded
        ExpectedDesktopPath        = $defaultDesktop
        DesktopPathExists          = if ($desktopExpanded) { Test-Path $desktopExpanded } else { $false }
        FolderRedirectionDetected  = $folderRedirection
        OneDriveDesktopDetected    = $isOneDriveDesktop
        TemporaryProfileIndicators = $tempProfileIndicators
        Profiles                   = $profiles
    }
}

function Get-ShortcutInventory {
    param(
        [datetime]$WindowStart,
        [datetime]$WindowEnd
    )

    $desktopPaths = @()

    $userDesktop = Join-Path -Path $env:USERPROFILE -ChildPath "Desktop"
    if (Test-Path $userDesktop) { $desktopPaths += $userDesktop }

    $publicDesktop = Join-Path -Path $env:PUBLIC -ChildPath "Desktop"
    if (Test-Path $publicDesktop) { $desktopPaths += $publicDesktop }

    $regDesktop = $null
    try {
        $regDesktop = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name Desktop -ErrorAction SilentlyContinue).Desktop
        if ($regDesktop) {
            $expanded = [Environment]::ExpandEnvironmentVariables($regDesktop)
            if ($expanded -and (Test-Path $expanded) -and ($desktopPaths -notcontains $expanded)) {
                $desktopPaths += $expanded
            }
        }
    }
    catch {
        Add-CollectorError -Step "ShortcutInventory.DesktopPath" -ErrorMessage $_.Exception.Message
    }

    $wshell = New-Object -ComObject WScript.Shell

    $items = foreach ($path in ($desktopPaths | Select-Object -Unique)) {
        Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in ".lnk", ".url" } |
            ForEach-Object {
                $target = $null
                if ($_.Extension -eq ".lnk") {
                    try {
                        $shortcut = $wshell.CreateShortcut($_.FullName)
                        $target = $shortcut.TargetPath
                    }
                    catch {
                        $target = $null
                    }
                }

                [pscustomobject]@{
                    ShortcutName        = $_.Name
                    FullPath            = $_.FullName
                    Extension           = $_.Extension
                    TargetPath          = $target
                    CreatedTime         = $_.CreationTime
                    LastWriteTime       = $_.LastWriteTime
                    InDeploymentWindow  = ($_.LastWriteTime -ge $WindowStart -and $_.LastWriteTime -le $WindowEnd)
                    DesktopRoot         = $path
                }
            }
    }

    $items
}

function Get-NetworkEvidence {
    $ipConfig = @()
    if (Get-Command Get-NetIPConfiguration -ErrorAction SilentlyContinue) {
        $ipConfig = Get-NetIPConfiguration -Detailed -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{
                InterfaceAlias   = $_.InterfaceAlias
                InterfaceIndex   = $_.InterfaceIndex
                IPv4Address      = ($_.IPv4Address | ForEach-Object { $_.IPv4Address.IPAddressToString }) -join ","
                IPv4DefaultGateway = ($_.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join ","
                DnsServers       = ($_.DNSServer.ServerAddresses) -join ","
                NetProfile       = $_.NetProfile.Name
            }
        }
    }

    $dnsServers = @()
    if (Get-Command Get-DnsClientServerAddress -ErrorAction SilentlyContinue) {
        $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{
                InterfaceAlias = $_.InterfaceAlias
                ServerAddresses = ($_.ServerAddresses -join ",")
            }
        }
    }

    $domain = $env:USERDNSDOMAIN
    if ([string]::IsNullOrWhiteSpace($domain)) {
        try {
            $cs = Get-CimInstance Win32_ComputerSystem
            $domain = $cs.Domain
        }
        catch {
            $domain = $null
        }
    }

    $secureChannel = $null
    try {
        $secureChannel = Test-ComputerSecureChannel -ErrorAction Stop
    }
    catch {
        Add-CollectorError -Step "Network.SecureChannel" -ErrorMessage $_.Exception.Message
    }

    $dcDiscovery = $null
    if ($domain -and $domain -ne $env:COMPUTERNAME) {
        try {
            $dcDiscovery = (& nltest.exe /dsgetdc:$domain 2>&1) | Out-String
        }
        catch {
            $dcDiscovery = "nltest unavailable or failed"
        }
    }

    [pscustomobject]@{
        DomainName          = $domain
        ComputerName        = $env:COMPUTERNAME
        UserName            = "$env:USERDOMAIN\$env:USERNAME"
        SecureChannelOK     = $secureChannel
        NetIpConfiguration  = $ipConfig
        DnsConfiguration    = $dnsServers
        DomainControllerDiscovery = $dcDiscovery
    }
}

function Get-DmsTimelineSignals {
    param(
        [array]$InstalledSoftware,
        [array]$ShortcutInventory,
        [datetime]$WindowStart,
        [datetime]$WindowEnd
    )

    $regex = ($DmsNamePatterns | ForEach-Object { [regex]::Escape($_) }) -join "|"

    $relatedInstalled = @($InstalledSoftware | Where-Object {
        $_.DisplayName -match $regex -or $_.Publisher -match $regex
    })

    $installedInWindow = @($relatedInstalled | Where-Object {
        $_.InstallDate -and $_.InstallDate -ge $WindowStart -and $_.InstallDate -le $WindowEnd
    })

    $shortcutChangesInWindow = @($ShortcutInventory | Where-Object { $_.InDeploymentWindow })

    [pscustomobject]@{
        DeploymentWindowStart     = $WindowStart
        DeploymentWindowEnd       = $WindowEnd
        RelatedInstalledAppsCount = $relatedInstalled.Count
        RelatedInstalledAppsWindowCount = $installedInWindow.Count
        ShortcutChangesWindowCount = $shortcutChangesInWindow.Count
        RelatedInstalledApps      = $relatedInstalled
        ShortcutChangesInWindow   = $shortcutChangesInWindow
    }
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$computerName = $env:COMPUTERNAME
$outputFolder = Join-Path -Path $OutputRoot -ChildPath ("Evidence-Floor6-{0}-{1}" -f $computerName, $timestamp)

$plannedArtifacts = @(
    "SystemInfo.json",
    "InstalledSoftware.csv",
    "InstalledSoftware.json",
    "RecentlyInstalledSoftware.csv",
    "StartupApplications.csv",
    "ScheduledTasks.csv",
    "RunningProcesses.csv",
    "PerformanceSnapshot.json",
    "Services.csv",
    "Event-AppMan.csv",
    "Event-Login.csv",
    "Event-GroupPolicy.csv",
    "Event-UserProfileService.csv",
    "Event-ApplicationErrors.csv",
    "GroupPolicyResult.html",
    "UserProfile.json",
    "DesktopShortcuts.csv",
    "NetworkInfo.json",
    "IpConfigAll.txt",
    "CollectorErrors.json",
    "SummaryReport.json",
    "Transcript.log"
)

if ($DryRun) {
    Write-Info "DryRun requested. No evidence will be collected and no files will be written."
    Write-Info "Would create output folder: $outputFolder"
    $plannedArtifacts | ForEach-Object { Write-Info "Would create artifact: $_" }

    [pscustomobject]@{
        DryRun = $true
        OutputFolder = $outputFolder
        PlannedArtifacts = $plannedArtifacts
        IncidentTag = $IncidentTag
        DeploymentWindowStart = $DeploymentWindowStart
        DeploymentWindowEnd = $DeploymentWindowEnd
        EventHoursBack = $EventHoursBack
    } | Format-List

    return
}

Ensure-Directory -Path $outputFolder
$transcriptPath = Join-Path -Path $outputFolder -ChildPath "Transcript.log"
Start-Transcript -Path $transcriptPath -Force | Out-Null

try {
    Write-Info "Output folder: $outputFolder"

    $windowStart = (Get-Date).AddHours(-1 * $EventHoursBack)

    $systemInfo = Invoke-Collector -Name "SystemIdentity" -Script {
        $cs = Get-CimInstance Win32_ComputerSystem
        $os = Get-CimInstance Win32_OperatingSystem
        $bios = Get-CimInstance Win32_BIOS

        [pscustomobject]@{
            CollectionUtc      = (Get-Date).ToUniversalTime().ToString("o")
            IncidentTag        = $IncidentTag
            ComputerName       = $env:COMPUTERNAME
            Domain             = $cs.Domain
            IsDomainJoined     = $cs.PartOfDomain
            Manufacturer       = $cs.Manufacturer
            Model              = $cs.Model
            LoggedOnUser       = $cs.UserName
            OsCaption          = $os.Caption
            OsVersion          = $os.Version
            BuildNumber        = $os.BuildNumber
            InstallDate        = $os.InstallDate
            LastBootUpTime     = $os.LastBootUpTime
            BiosSerialNumber   = $bios.SerialNumber
            TimeZone           = (Get-TimeZone).Id
        }
    }
    Export-JsonFile -Data $systemInfo -Path (Join-Path $outputFolder "SystemInfo.json")

    $installedSoftware = Invoke-Collector -Name "InstalledSoftware" -Script { Get-InstalledSoftware }
    Export-CsvFile -Data $installedSoftware -Path (Join-Path $outputFolder "InstalledSoftware.csv")
    Export-JsonFile -Data $installedSoftware -Path (Join-Path $outputFolder "InstalledSoftware.json") -Depth 6

    $recentSoftware = Invoke-Collector -Name "RecentlyInstalledSoftware" -Script {
        @($installedSoftware | Where-Object {
            $_.InstallDate -and $_.InstallDate -ge $DeploymentWindowStart.AddDays(-2) -and $_.InstallDate -le (Get-Date)
        } | Sort-Object InstallDate -Descending)
    }
    Export-CsvFile -Data $recentSoftware -Path (Join-Path $outputFolder "RecentlyInstalledSoftware.csv")

    $startupApps = Invoke-Collector -Name "StartupApplications" -Script { Get-StartupApplications }
    Export-CsvFile -Data $startupApps -Path (Join-Path $outputFolder "StartupApplications.csv")

    $tasks = Invoke-Collector -Name "ScheduledTasks" -Script { Get-ScheduledTaskEvidence }
    Export-CsvFile -Data $tasks -Path (Join-Path $outputFolder "ScheduledTasks.csv")

    $procs = Invoke-Collector -Name "RunningProcesses" -Script { Get-ProcessEvidence }
    Export-CsvFile -Data $procs -Path (Join-Path $outputFolder "RunningProcesses.csv")

    $perf = Invoke-Collector -Name "PerformanceSnapshot" -Script { Get-PerformanceSnapshot }
    Export-JsonFile -Data $perf -Path (Join-Path $outputFolder "PerformanceSnapshot.json") -Depth 6

    $services = Invoke-Collector -Name "ServiceInventory" -Script { Get-ServiceEvidence }
    Export-CsvFile -Data $services -Path (Join-Path $outputFolder "Services.csv")

    $eventsAppMan = Invoke-Collector -Name "EventLog.AppMan" -Script {
        Get-WinEventSafe -LogName "Microsoft-Windows-AppMan/Admin" -StartTime $windowStart -MaxEvents 800
    }
    Export-CsvFile -Data $eventsAppMan -Path (Join-Path $outputFolder "Event-AppMan.csv")

    $eventsLogin = Invoke-Collector -Name "EventLog.LoginAndAuth" -Script {
        $security = Get-WinEventSafe -LogName "Security" -Ids @(4624, 4625, 4634, 4648, 4672, 4771, 4776) -StartTime $windowStart -MaxEvents 1200
        $system = Get-WinEventSafe -LogName "System" -Ids @(5719, 5722, 6005, 6006, 6008, 7000, 7001, 7011) -StartTime $windowStart -MaxEvents 600
        @($security + $system) | Sort-Object TimeCreated -Descending
    }
    Export-CsvFile -Data $eventsLogin -Path (Join-Path $outputFolder "Event-Login.csv")

    $eventsGp = Invoke-Collector -Name "EventLog.GroupPolicy" -Script {
        Get-WinEventSafe -LogName "Microsoft-Windows-GroupPolicy/Operational" -StartTime $windowStart -MaxEvents 1000
    }
    Export-CsvFile -Data $eventsGp -Path (Join-Path $outputFolder "Event-GroupPolicy.csv")

    $eventsProfileSvc = Invoke-Collector -Name "EventLog.UserProfileService" -Script {
        Get-WinEventSafe -LogName "Microsoft-Windows-User Profile Service/Operational" -StartTime $windowStart -MaxEvents 1000
    }
    Export-CsvFile -Data $eventsProfileSvc -Path (Join-Path $outputFolder "Event-UserProfileService.csv")

    $eventsAppErrors = Invoke-Collector -Name "EventLog.ApplicationErrors" -Script {
        @(
            Get-WinEventSafe -LogName "Application" -Ids @(1000, 1001, 1002, 1026, 1033, 11707, 11708) -StartTime $windowStart -MaxEvents 1000
        ) | Sort-Object TimeCreated -Descending
    }
    Export-CsvFile -Data $eventsAppErrors -Path (Join-Path $outputFolder "Event-ApplicationErrors.csv")

    $gpResult = Invoke-Collector -Name "GroupPolicyResult" -Script {
        Get-GroupPolicyResult -OutHtmlPath (Join-Path $outputFolder "GroupPolicyResult.html")
    }

    $profile = Invoke-Collector -Name "UserProfileEvidence" -Script { Get-UserProfileEvidence }
    Export-JsonFile -Data $profile -Path (Join-Path $outputFolder "UserProfile.json") -Depth 8

    $shortcuts = Invoke-Collector -Name "DesktopShortcutInventory" -Script {
        Get-ShortcutInventory -WindowStart $DeploymentWindowStart -WindowEnd $DeploymentWindowEnd
    }
    Export-CsvFile -Data $shortcuts -Path (Join-Path $outputFolder "DesktopShortcuts.csv")

    $network = Invoke-Collector -Name "NetworkEvidence" -Script { Get-NetworkEvidence }
    Export-JsonFile -Data $network -Path (Join-Path $outputFolder "NetworkInfo.json") -Depth 8

    Invoke-Collector -Name "IpConfigAll" -Script {
        & ipconfig.exe /all > (Join-Path $outputFolder "IpConfigAll.txt")
    } | Out-Null

    $timeline = Invoke-Collector -Name "DeploymentTimelineSignals" -Script {
        Get-DmsTimelineSignals -InstalledSoftware $installedSoftware -ShortcutInventory $shortcuts -WindowStart $DeploymentWindowStart -WindowEnd $DeploymentWindowEnd
    }

    $signals = @()
    if ($timeline.RelatedInstalledAppsWindowCount -gt 0) {
        $signals += "DMS-related installed software detected in deployment window"
    }
    if (@($eventsAppMan).Count -gt 0) {
        $signals += "AppMan events present in event window"
    }
    if (@($services | Where-Object { $_.IsDmsRelated }).Count -gt 0) {
        $signals += "DMS-related services present"
    }
    if (@($tasks | Where-Object { $_.IsDmsRelated }).Count -gt 0) {
        $signals += "DMS-related scheduled tasks present"
    }
    if ($timeline.ShortcutChangesWindowCount -gt 0) {
        $signals += "Desktop shortcut changes detected in deployment window"
    }
    if (@($eventsProfileSvc).Count -gt 0) {
        $signals += "User profile service activity detected"
    }

    $summary = [pscustomobject]@{
        IncidentTag             = $IncidentTag
        CollectionUtc           = (Get-Date).ToUniversalTime().ToString("o")
        ComputerName            = $env:COMPUTERNAME
        DeploymentWindowStart   = $DeploymentWindowStart
        DeploymentWindowEnd     = $DeploymentWindowEnd
        EventWindowStart        = $windowStart
        EventHoursBack          = $EventHoursBack
        GroupPolicyResult       = $gpResult
        ArtifactCounts          = [pscustomobject]@{
            InstalledSoftware        = @($installedSoftware).Count
            RecentlyInstalledSoftware = @($recentSoftware).Count
            StartupApplications      = @($startupApps).Count
            ScheduledTasks           = @($tasks).Count
            RunningProcesses         = @($procs).Count
            Services                 = @($services).Count
            EventAppMan              = @($eventsAppMan).Count
            EventLogin               = @($eventsLogin).Count
            EventGroupPolicy         = @($eventsGp).Count
            EventUserProfileService  = @($eventsProfileSvc).Count
            EventApplicationErrors   = @($eventsAppErrors).Count
            DesktopShortcuts         = @($shortcuts).Count
            CollectorErrors          = @($script:CollectorErrors).Count
        }
        DeploymentSignals      = $signals
        TimelineSignals        = $timeline
        CollectorErrors        = $script:CollectorErrors
        ReadOnlyStatement      = "No system changes were performed by this script. Evidence collection only."
    }

    Export-JsonFile -Data $script:CollectorErrors -Path (Join-Path $outputFolder "CollectorErrors.json") -Depth 6
    Export-JsonFile -Data $summary -Path (Join-Path $outputFolder "SummaryReport.json") -Depth 10

    Write-Info "Evidence collection complete."
    Write-Info "Summary: $(Join-Path $outputFolder "SummaryReport.json")"
}
finally {
    Stop-Transcript | Out-Null
}
