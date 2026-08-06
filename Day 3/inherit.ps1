<#
.SYNOPSIS
    Endpoint Health Diagnostic Script

.DESCRIPTION
    Collects and displays a snapshot of the local machine's health, including:
      - Computer name and total physical RAM
      - Free disk space on the C: drive
      - Top 5 processes by memory usage
      - Recent System event log errors (last 10 entries, errors only)
      - Count of stale local user profiles (unused for 90+ days)

    This script is READ-ONLY and makes no changes to the system.

.AUTHOR
    IT Support Team

.HOW TO RUN
    1. Open PowerShell (no elevated/admin rights required for most checks)
    2. Navigate to the folder containing this script:
           cd "C:\Path\To\Script"
    3. Run the script:
           .\inherit.ps1
    4. Review the output in the console window.

.NOTES
    Tested on: Windows 10 / Windows 11
    PowerShell Version: 5.1 or later
#>

# ---------------------------------------------------------------
# DATA COLLECTION
# ---------------------------------------------------------------

# Query WMI for general computer system information (name, total RAM, manufacturer)
$computerSystem = Get-CimInstance Win32_ComputerSystem

# Get the amount of free disk space (in bytes) on the C: drive
$freeDiskSpaceBytes = Get-PSDrive C | Select-Object -ExpandProperty Free

# Get all running processes, sort by Working Set memory (highest first), keep top 5
$topMemoryProcesses = Get-Process | Sort-Object WS -Descending | Select-Object -First 5

# Read the last 10 entries from the System event log and filter to errors only (Level 2 = Error)
$recentSystemErrors = Get-WinEvent -LogName System -MaxEvents 10 | Where-Object { $_.Level -eq 2 }

# Get all local user profiles, exclude built-in/special accounts, keep only those
# not used in the last 90 days (potential candidates for cleanup)
$staleUserProfiles = Get-CimInstance Win32_UserProfile | Where-Object {
    -not $_.Special -and $_.LastUseTime -lt (Get-Date).AddDays(-90)
}

# ---------------------------------------------------------------
# OUTPUT
# ---------------------------------------------------------------

# Display the computer name and total physical RAM in bytes
Write-Host $computerSystem.Name $computerSystem.TotalPhysicalMemory

# Convert free disk space from bytes to GB (rounded to 2 decimal places) and display it
Write-Host ([math]::Round($freeDiskSpaceBytes / 1GB, 2)) 'GB free'

# Loop through the top 5 memory-consuming processes and display each name and memory usage
$topMemoryProcesses | ForEach-Object { Write-Host $_.Name $_.WS }

# Loop through recent system errors and display the timestamp and event message for each
$recentSystemErrors | ForEach-Object { Write-Host $_.TimeCreated $_.Message }

# If any stale user profiles were found, display the total count
if ($staleUserProfiles.Count -gt 0) { Write-Host 'Stale profiles:' $staleUserProfiles.Count }