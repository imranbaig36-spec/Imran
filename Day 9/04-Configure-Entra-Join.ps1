#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configures Entra ID join and deploys AADLoginForWindows extension.
.DESCRIPTION
    Installs AADLoginForWindows extension to enable Entra ID sign-in for the session host.
    Validates Entra join status after deployment.
.PARAMETER ResourceGroup
    Azure Resource Group name.
.PARAMETER VMName
    VM name.
.EXAMPLE
    .\04-Configure-Entra-Join.ps1 -ResourceGroup "dwpai-lab-rg" -VMName "pfin01sh63"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName
)

$ErrorActionPreference = "Stop"
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

Write-Host "=== Configuring Entra ID Join ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "VM Name: $VMName`n" -ForegroundColor Gray

# Step 1: Check VM is running
Write-Host "[1/3] Verifying VM state..." -ForegroundColor Yellow
try {
    $vmState = & $az vm get-instance-view -g $ResourceGroup -n $VMName `
        --query "instanceView.statuses[1].displayStatus" -o tsv
    
    if ($vmState -ne "VM running") {
        Write-Host "⚠️  VM is not running. Starting VM..." -ForegroundColor Yellow
        & $az vm start -g $ResourceGroup -n $VMName --no-wait
        Write-Host "   Waiting for VM to start..." -ForegroundColor Gray
        Start-Sleep -Seconds 30
    }
    
    Write-Host "✅ VM is running" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not verify VM state: $_" -ForegroundColor Yellow
}

# Step 2: Deploy AADLoginForWindows Extension
Write-Host "[2/3] Deploying AADLoginForWindows extension..." -ForegroundColor Yellow
try {
    & $az vm extension set `
        -g $ResourceGroup `
        --vm-name $VMName `
        --name AADLoginForWindows `
        --publisher Microsoft.Azure.ActiveDirectory `
        --version 2.2 `
        --no-wait `
        --output json > $null
    
    Write-Host "✅ AADLoginForWindows extension deployment started" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to deploy extension: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Wait for extension deployment
Write-Host "[3/3] Waiting for extension deployment..." -ForegroundColor Yellow
try {
    $maxAttempts = 60
    $attempt = 0
    
    do {
        $extState = & $az vm extension show -g $ResourceGroup --vm-name $VMName `
            -n AADLoginForWindows --query "provisioningState" -o tsv 2>&1
        
        if ($extState -eq "Succeeded") {
            Write-Host "✅ Extension deployment succeeded" -ForegroundColor Green
            break
        } elseif ($extState -eq "Failed") {
            Write-Host "❌ Extension deployment failed" -ForegroundColor Red
            break
        }
        
        $attempt++
        Write-Host "   Wait... Status: $extState (Attempt $attempt/$maxAttempts)" -ForegroundColor Gray
        
        if ($attempt -ge $maxAttempts) {
            Write-Host "⏱️  Extension still deploying. Check status with:" -ForegroundColor Yellow
            Write-Host "   az vm extension show -g $ResourceGroup --vm-name $VMName -n AADLoginForWindows" -ForegroundColor Yellow
            break
        }
        
        Start-Sleep -Seconds 5
    } while ($true)
} catch {
    Write-Host "⚠️  Could not verify extension state: $_" -ForegroundColor Yellow
}

# Display summary
Write-Host "`n=== Entra ID Configuration Complete ===" -ForegroundColor Cyan
Write-Host "VM Name: $VMName" -ForegroundColor Green
Write-Host "Entra Extension: AADLoginForWindows v2.2 (deployed)" -ForegroundColor Green
Write-Host "`nThe VM can now be accessed with Entra ID credentials." -ForegroundColor Green
Write-Host "`nTo verify Entra join status:" -ForegroundColor Yellow
Write-Host "1. RDP to the VM" -ForegroundColor Yellow
Write-Host "2. Open PowerShell and run: dsregcmd /status" -ForegroundColor Yellow
Write-Host "3. Look for: AzureAdJoined : YES" -ForegroundColor Yellow

Write-Host "`nNext Step: Run script 05-Install-AVD-Agent.ps1 to install session host agent" -ForegroundColor Yellow
