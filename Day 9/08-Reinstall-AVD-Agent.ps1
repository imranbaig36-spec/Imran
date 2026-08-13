#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Recovers from provisioning state "Skipped" by reinstalling AVD agent with fresh token.
.DESCRIPTION
    When AVD agent provisioning state is "Skipped", this script:
    1. Generates a fresh registration token
    2. Uninstalls previous MSI packages
    3. Reinstalls MSIs with new token
    4. Verifies provisioning state transitions to "Completed"
.PARAMETER ResourceGroup
    Azure Resource Group name.
.PARAMETER HostPoolName
    Host pool name.
.PARAMETER VMName
    Session host VM name.
.EXAMPLE
    .\08-Reinstall-AVD-Agent.ps1 -ResourceGroup "dwpai-lab-rg" `
      -HostPoolName "POOL-FIN-01" -VMName "pfin01sh63"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName
)

$ErrorActionPreference = "Stop"
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

Write-Host "=== AVD Agent Recovery (Reinstall) ===" -ForegroundColor Cyan
Write-Host "This script recovers from provisioning state 'Skipped'" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "Host Pool: $HostPoolName" -ForegroundColor Gray
Write-Host "VM: $VMName`n" -ForegroundColor Gray

# Step 1: Delete and regenerate registration token
Write-Host "[1/4] Regenerating registration token..." -ForegroundColor Yellow
try {
    # Delete old token
    & $az desktopvirtualization hostpool update `
        -g $ResourceGroup `
        -n $HostPoolName `
        --registration-info "registration-token-operation=Delete" `
        --output json > $null
    
    Write-Host "   Old token deleted" -ForegroundColor Gray
    
    # Generate new token
    $expirationTime = (Get-Date).ToUniversalTime().AddHours(24).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
    & $az desktopvirtualization hostpool update `
        -g $ResourceGroup `
        -n $HostPoolName `
        --registration-info "expiration-time=$expirationTime" "registration-token-operation=Update" `
        --output json > $null
    
    $token = & $az desktopvirtualization hostpool show `
        -g $ResourceGroup `
        -n $HostPoolName `
        --query "registrationInfo.token" -o tsv
    
    Write-Host "✅ New registration token generated" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to regenerate token: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Uninstall previous MSIs
Write-Host "[2/4] Uninstalling previous agent versions..." -ForegroundColor Yellow
try {
    $uninstallScript = @"
msiexec /x `"C:\AVDInstall\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi`" /qn /norestart 2>&1 | Out-Null
msiexec /x `"C:\AVDInstall\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.15008.300.msi`" /qn /norestart 2>&1 | Out-Null
Start-Sleep -Seconds 5
Write-Host "Uninstall complete"
"@

    & $az vm run-command invoke `
        -g $ResourceGroup `
        -n $VMName `
        --command-id RunPowerShellScript `
        --scripts $uninstallScript `
        --query "value[0].message" -o tsv > $null
    
    Write-Host "✅ Previous versions uninstalled" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Uninstall issue: $_" -ForegroundColor Yellow
}

# Step 3: Reinstall with new token
Write-Host "[3/4] Reinstalling with fresh token..." -ForegroundColor Yellow
try {
    $reinstallScript = @"
Write-Host "Installing RDAgent..."
`$p1 = Start-Process msiexec.exe -PassThru -Wait -ArgumentList `/i, `"C:\AVDInstall\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.15008.300.msi`", `/qn, `"REGISTRATIONTOKEN=$token`", `/l*v, `"C:\Windows\Temp\avd-agent-recovery.log`"

Write-Host "Installing RDAgentBootLoader..."
`$p2 = Start-Process msiexec.exe -PassThru -Wait -ArgumentList `/i, `"C:\AVDInstall\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi`", `/qn, `/l*v, `"C:\Windows\Temp\avd-bootloader-recovery.log`"

Start-Sleep -Seconds 3
Write-Host "Restarting RDAgentBootLoader service..."
Restart-Service RDAgentBootLoader -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Get-Service RDAgentBootLoader,RDAgent -ErrorAction SilentlyContinue | Select-Object Name,Status
"@

    $installOutput = & $az vm run-command invoke `
        -g $ResourceGroup `
        -n $VMName `
        --command-id RunPowerShellScript `
        --scripts $reinstallScript `
        --query "value[0].message" -o tsv
    
    Write-Host $installOutput
    Write-Host "✅ Reinstallation complete" -ForegroundColor Green
} catch {
    Write-Host "❌ Reinstall failed: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Verify new state
Write-Host "[4/4] Verifying provisioning state..." -ForegroundColor Yellow
try {
    Start-Sleep -Seconds 10
    
    $verifyScript = @"
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning" `
  -Name "AVDAgentProvisioningState" -ErrorAction SilentlyContinue | `
  Select-Object -ExpandProperty AVDAgentProvisioningState
"@

    $state = & $az vm run-command invoke `
        -g $ResourceGroup `
        -n $VMName `
        --command-id RunPowerShellScript `
        --scripts $verifyScript `
        --query "value[0].message" -o tsv
    
    Write-Host "   Provisioning State: $state" -ForegroundColor Gray
    
    if ($state -eq "Completed") {
        Write-Host "✅ Provisioning state: COMPLETED" -ForegroundColor Green
    } elseif ($state -eq "Skipped") {
        Write-Host "❌ Still SKIPPED - token may still be invalid" -ForegroundColor Red
    } else {
        Write-Host "⚠️  State: $state" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "⚠️  Verification: $_" -ForegroundColor Yellow
}

Write-Host "`n=== Recovery Complete ===" -ForegroundColor Cyan
Write-Host "Next: Run 07-Verify-Registration.ps1 to check full status" -ForegroundColor Yellow
Write-Host "If still issues, check Event Log on VM or escalate to Azure Support" -ForegroundColor Yellow
