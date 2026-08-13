#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs AVD guest agent (RDAgent + RDAgentBootLoader) on session host.
.DESCRIPTION
    Downloads or uses local AVD installer MSIs and installs RDAgent and RDAgentBootLoader
    with registration token for broker connectivity.
.PARAMETER ResourceGroup
    Azure Resource Group name.
.PARAMETER VMName
    VM name.
.PARAMETER RegistrationToken
    Host pool registration token (from broker). If not provided, will fetch from host pool.
.PARAMETER HostPoolName
    Host pool name (used to fetch token if not provided).
.EXAMPLE
    .\05-Install-AVD-Agent.ps1 -ResourceGroup "dwpai-lab-rg" -VMName "pfin01sh63" `
      -HostPoolName "POOL-FIN-01"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    
    [Parameter(Mandatory=$false)]
    [string]$RegistrationToken,
    
    [Parameter(Mandatory=$false)]
    [string]$HostPoolName
)

$ErrorActionPreference = "Stop"
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

Write-Host "=== Installing AVD Guest Agent ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "VM Name: $VMName`n" -ForegroundColor Gray

# Step 1: Fetch registration token if not provided
if (-not $RegistrationToken) {
    if (-not $HostPoolName) {
        Write-Host "❌ Either -RegistrationToken or -HostPoolName must be provided" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[1/4] Fetching registration token..." -ForegroundColor Yellow
    try {
        $RegistrationToken = & $az desktopvirtualization hostpool show `
            -g $ResourceGroup -n $HostPoolName `
            --query "registrationInfo.token" -o tsv
        
        if (-not $RegistrationToken) {
            Write-Host "❌ No valid registration token found" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "✅ Registration token retrieved (length: $($RegistrationToken.Length))" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to fetch token: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[1/4] Using provided registration token" -ForegroundColor Yellow
    Write-Host "✅ Token length: $($RegistrationToken.Length)" -ForegroundColor Green
}

# Step 2: Download MSI files (or use local cache)
Write-Host "[2/4] Preparing MSI installers..." -ForegroundColor Yellow
try {
    # Check if MSIs already exist locally
    $agentMsi = "C:\AVDInstall\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.15008.300.msi"
    $bootloaderMsi = "C:\AVDInstall\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi"
    
    if ((Test-Path $agentMsi) -and (Test-Path $bootloaderMsi)) {
        Write-Host "✅ Using cached MSI files from C:\AVDInstall" -ForegroundColor Green
    } else {
        Write-Host "   Note: MSI files should be pre-downloaded to VM" -ForegroundColor Yellow
        Write-Host "   Location: C:\AVDInstall\" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Could not verify MSI files: $_" -ForegroundColor Yellow
}

# Step 3: Create and run installation script on VM
Write-Host "[3/4] Creating installation script on VM..." -ForegroundColor Yellow
try {
    # Escape backslashes for script content
    $agentMsiEscaped = $agentMsi -replace '\\', '\\'
    $bootloaderMsiEscaped = $bootloaderMsi -replace '\\', '\\'
    
    # Create inline script for VM run-command
    $installScript = @"
`$ErrorActionPreference = 'Stop'
Write-Host 'Uninstalling previous agent versions...'
msiexec /x `"$agentMsiEscaped`" /qn /norestart 2>&1 | Out-Null
msiexec /x `"$bootloaderMsiEscaped`" /qn /norestart 2>&1 | Out-Null
Start-Sleep -Seconds 5

Write-Host 'Installing RDAgent...'
`$p1 = Start-Process msiexec.exe -PassThru -Wait -ArgumentList `/i, `"`"$agentMsiEscaped`"`", `/qn, `"REGISTRATIONTOKEN=$RegistrationToken`", `/l*v, `"C:\Windows\Temp\avd-agent.log`"
Write-Host "RDAgent exit code: `$(`$p1.ExitCode)"

Write-Host 'Installing RDAgentBootLoader...'
`$p2 = Start-Process msiexec.exe -PassThru -Wait -ArgumentList `/i, `"`"$bootloaderMsiEscaped`"`", `/qn, `/l*v, `"C:\Windows\Temp\avd-bootloader.log`"
Write-Host "RDAgentBootLoader exit code: `$(`$p2.ExitCode)"

Start-Sleep -Seconds 3
Write-Host 'Checking service status...'
Get-Service -Name RDAgentBootLoader,RDAgent -ErrorAction SilentlyContinue | Select-Object Name,Status
"@

    # Run the script via az vm run-command
    Write-Host "   Invoking installation on VM..." -ForegroundColor Gray
    
    & $az vm run-command invoke `
        -g $ResourceGroup `
        -n $VMName `
        --command-id RunPowerShellScript `
        --scripts $installScript `
        --query "value[0].message" -o tsv | Write-Host
    
    Write-Host "✅ Installation script executed" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Failed to run installation: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Verify installation
Write-Host "[4/4] Verifying installation..." -ForegroundColor Yellow
try {
    Start-Sleep -Seconds 10
    
    $verifyScript = @"
Get-Service -Name RDAgentBootLoader,RDAgent -ErrorAction SilentlyContinue | Select-Object Name,Status
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning" -Name "AVDAgentProvisioningState" -ErrorAction SilentlyContinue | Select-Object AVDAgentProvisioningState
"@

    $result = & $az vm run-command invoke `
        -g $ResourceGroup `
        -n $VMName `
        --command-id RunPowerShellScript `
        --scripts $verifyScript `
        --query "value[0].message" -o tsv
    
    Write-Host $result
    
    if ($result -match "RDAgentBootLoader.*Running" -and $result -match "RDAgent.*Running") {
        Write-Host "✅ Both services installed and running" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Services may not be running. Check VM manually." -ForegroundColor Yellow
    }
    
    if ($result -match "AVDAgentProvisioningState.*Completed") {
        Write-Host "✅ Provisioning state: COMPLETED" -ForegroundColor Green
    } elseif ($result -match "AVDAgentProvisioningState.*Skipped") {
        Write-Host "⚠️  Provisioning state: SKIPPED (token may be invalid)" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️  Could not determine provisioning state" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "⚠️  Verification check failed: $_" -ForegroundColor Yellow
}

# Display summary
Write-Host "`n=== AVD Agent Installation Complete ===" -ForegroundColor Cyan
Write-Host "VM Name: $VMName" -ForegroundColor Green
Write-Host "RDAgent: Installed" -ForegroundColor Green
Write-Host "RDAgentBootLoader: Installed" -ForegroundColor Green
Write-Host "`nServices should be running. If not:" -ForegroundColor Yellow
Write-Host "1. RDP to VM manually" -ForegroundColor Yellow
Write-Host "2. Check Event Log: Application -> RDAgent events" -ForegroundColor Yellow
Write-Host "3. Verify C:\AVDInstall MSI files exist" -ForegroundColor Yellow

Write-Host "`nNext Step: Run script 06-Assign-User-Roles.ps1 to assign user RBAC" -ForegroundColor Yellow
