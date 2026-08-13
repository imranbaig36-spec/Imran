#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Master orchestration script for complete AVD provisioning workflow.
.DESCRIPTION
    Runs all provisioning steps in sequence:
    1. Pre-flight checks
    2. Create control plane (host pool, workspace, app group)
    3. Create session host VM
    4. Configure Entra ID join
    5. Install AVD guest agent
    6. Assign user RBAC roles
    7. Verify registration
    
    If any step fails, user is prompted to fix and retry.
.PARAMETER ResourceGroup
    Azure Resource Group name.
.PARAMETER SubscriptionId
    Azure Subscription ID.
.PARAMETER Region
    Azure region.
.PARAMETER HostPoolName
    Host pool name.
.PARAMETER WorkspaceName
    Workspace name.
.PARAMETER VMName
    Session host VM name.
.PARAMETER UserPrincipalName
    Target user UPN.
.EXAMPLE
    .\09-Complete-Provisioning.ps1 -ResourceGroup "dwpai-lab-rg" `
      -SubscriptionId "4e7bcf35-9384-4498-bc21-d9d1221b5faa" `
      -Region "eastus" -HostPoolName "POOL-FIN-01" `
      -WorkspaceName "FinBridge-Workspace" -VMName "pfin01sh63" `
      -UserPrincipalName "p43@zippyops.in"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "eastus",
    
    [Parameter(Mandatory=$true)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    
    [Parameter(Mandatory=$true)]
    [string]$UserPrincipalName,
    
    [Parameter(Mandatory=$false)]
    [string]$VNetName = "dwp-p43-winVNET",
    
    [Parameter(Mandatory=$false)]
    [string]$SubnetName = "dwp-p43-winSubnet"
)

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       AVD COMPLETE PROVISIONING ORCHESTRATION                  ║" -ForegroundColor Cyan
Write-Host "║       Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`nProvision Summary:" -ForegroundColor Yellow
Write-Host "  Subscription: $SubscriptionId" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "  Region: $Region" -ForegroundColor Gray
Write-Host "  Host Pool: $HostPoolName" -ForegroundColor Gray
Write-Host "  Workspace: $WorkspaceName" -ForegroundColor Gray
Write-Host "  VM: $VMName" -ForegroundColor Gray
Write-Host "  User: $UserPrincipalName`n" -ForegroundColor Gray

$steps = @(
    @{
        Num = 1
        Name = "Pre-Flight Checks"
        Script = "01-Pre-Flight-Checks.ps1"
        Args = "-SubscriptionId '$SubscriptionId' -ResourceGroup '$ResourceGroup' -Region '$Region'"
    },
    @{
        Num = 2
        Name = "Create Control Plane"
        Script = "02-Create-ControlPlane.ps1"
        Args = "-ResourceGroup '$ResourceGroup' -HostPoolName '$HostPoolName' -WorkspaceName '$WorkspaceName' -AppGroupName '$HostPoolName-DAG'"
    },
    @{
        Num = 3
        Name = "Create Session Host VM"
        Script = "03-Create-SessionHost-VM.ps1"
        Args = "-ResourceGroup '$ResourceGroup' -VMName '$VMName' -VNetName '$VNetName' -SubnetName '$SubnetName'"
    },
    @{
        Num = 4
        Name = "Configure Entra ID Join"
        Script = "04-Configure-Entra-Join.ps1"
        Args = "-ResourceGroup '$ResourceGroup' -VMName '$VMName'"
    },
    @{
        Num = 5
        Name = "Install AVD Guest Agent"
        Script = "05-Install-AVD-Agent.ps1"
        Args = "-ResourceGroup '$ResourceGroup' -VMName '$VMName' -HostPoolName '$HostPoolName'"
    },
    @{
        Num = 6
        Name = "Assign User RBAC Roles"
        Script = "06-Assign-User-Roles.ps1"
        Args = "-ResourceGroup '$ResourceGroup' -UserPrincipalName '$UserPrincipalName' -HostPoolName '$HostPoolName' -AppGroupName '$HostPoolName-DAG'"
    },
    @{
        Num = 7
        Name = "Verify Registration"
        Script = "07-Verify-Registration.ps1"
        Args = "-ResourceGroup '$ResourceGroup' -HostPoolName '$HostPoolName' -VMName '$VMName' -UserPrincipalName '$UserPrincipalName'"
    }
)

$completedSteps = 0
$failedSteps = 0

foreach ($step in $steps) {
    Write-Host "`n$('─' * 70)" -ForegroundColor Gray
    Write-Host "STEP $($step.Num)/7: $($step.Name)" -ForegroundColor Cyan
    Write-Host "Script: $($step.Script)" -ForegroundColor Gray
    Write-Host "─" * 70 -ForegroundColor Gray
    
    $scriptPath = Join-Path $scriptDir $step.Script
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host "❌ Script not found: $scriptPath" -ForegroundColor Red
        $failedSteps++
        
        $response = Read-Host "Continue to next step? (y/n)"
        if ($response -ne "y") { exit 1 }
        continue
    }
    
    try {
        # Execute script with arguments
        $cmd = "$scriptPath $($step.Args)"
        Invoke-Expression $cmd
        
        Write-Host "`n✅ Step $($step.Num) COMPLETED" -ForegroundColor Green
        $completedSteps++
        
    } catch {
        Write-Host "`n❌ Step $($step.Num) FAILED: $_" -ForegroundColor Red
        $failedSteps++
        
        Write-Host "`nFix the issue and select action:" -ForegroundColor Yellow
        Write-Host "  [R] Retry this step" -ForegroundColor Yellow
        Write-Host "  [S] Skip to next step" -ForegroundColor Yellow
        Write-Host "  [E] Exit provisioning" -ForegroundColor Yellow
        
        $action = Read-Host "Action (R/S/E)"
        
        if ($action -eq "R") {
            # Retry
            Write-Host "Retrying step $($step.Num)..." -ForegroundColor Yellow
            try {
                Invoke-Expression $cmd
                Write-Host "✅ Step $($step.Num) COMPLETED after retry" -ForegroundColor Green
                $completedSteps++
                $failedSteps--
            } catch {
                Write-Host "❌ Retry failed" -ForegroundColor Red
            }
        } elseif ($action -eq "E") {
            Write-Host "`nProvisioning aborted at step $($step.Num)" -ForegroundColor Red
            exit 1
        } else {
            Write-Host "Skipping to next step..." -ForegroundColor Yellow
        }
    }
    
    if ($step.Num -lt $steps.Count) {
        Write-Host "`nWaiting before next step..." -ForegroundColor Gray
        Start-Sleep -Seconds 5
    }
}

# Final Summary
Write-Host "`n$('═' * 70)" -ForegroundColor Cyan
Write-Host "PROVISIONING COMPLETE" -ForegroundColor Cyan
Write-Host "═" * 70 -ForegroundColor Cyan

Write-Host "`nResults:" -ForegroundColor Yellow
Write-Host "  ✅ Completed: $completedSteps/7" -ForegroundColor Green
Write-Host "  ❌ Failed: $failedSteps/7" -ForegroundColor Red

if ($completedSteps -eq 7) {
    Write-Host "`n🎉 All steps completed successfully!" -ForegroundColor Green
} elseif ($completedSteps -ge 5) {
    Write-Host "`n⚠️  Most steps completed. Review failures and troubleshoot." -ForegroundColor Yellow
} else {
    Write-Host "`n❌ Multiple failures. Review errors and restart provisioning." -ForegroundColor Red
}

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "1. Verify all resources in Azure Portal" -ForegroundColor Yellow
Write-Host "2. Test RDP access to VM using Entra ID credentials" -ForegroundColor Yellow
Write-Host "3. Verify session host registered in host pool" -ForegroundColor Yellow
Write-Host "4. If registration fails, run 08-Reinstall-AVD-Agent.ps1" -ForegroundColor Yellow

Write-Host "`nLog files for reference:" -ForegroundColor Gray
Write-Host "  - Provisioning steps: This terminal output" -ForegroundColor Gray
Write-Host "  - VM Guest logs: See 07-Verify-Registration.ps1 for locations" -ForegroundColor Gray

Write-Host "`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Provisioning workflow ended`n" -ForegroundColor Gray
