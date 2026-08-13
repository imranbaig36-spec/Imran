#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies AVD provisioning and troubleshoots registration issues.
.DESCRIPTION
    Validates:
    - Host pool configuration and registration token
    - VM state and extensions
    - Entra join status
    - AVD agent installation and services
    - Session host registration in broker
    - User RBAC assignments
    - Broker network connectivity
.PARAMETER ResourceGroup
    Azure Resource Group name.
.PARAMETER HostPoolName
    Host pool name.
.PARAMETER VMName
    Session host VM name.
.PARAMETER UserPrincipalName
    User email/UPN for RBAC verification.
.EXAMPLE
    .\07-Verify-Registration.ps1 -ResourceGroup "dwpai-lab-rg" `
      -HostPoolName "POOL-FIN-01" -VMName "pfin01sh63" `
      -UserPrincipalName "p43@zippyops.in"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    
    [Parameter(Mandatory=$false)]
    [string]$UserPrincipalName
)

$ErrorActionPreference = "Continue"
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

$results = @()

Write-Host "=== AVD Registration Verification ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "Host Pool: $HostPoolName" -ForegroundColor Gray
Write-Host "VM: $VMName`n" -ForegroundColor Gray

# Check 1: Host Pool Configuration
Write-Host "[1/8] Checking host pool..." -ForegroundColor Yellow
try {
    $hp = & $az desktopvirtualization hostpool show -g $ResourceGroup -n $HostPoolName | ConvertFrom-Json
    Write-Host "✅ Host pool exists" -ForegroundColor Green
    Write-Host "   Type: $($hp.hostPoolType) | LB: $($hp.loadBalancerType) | Max Sessions: $($hp.maxSessionLimit)" -ForegroundColor Gray
    
    if ($hp.registrationInfo) {
        Write-Host "✅ Registration token active (expires: $($hp.registrationInfo.expirationTime))" -ForegroundColor Green
    } else {
        Write-Host "⚠️  No active registration token" -ForegroundColor Yellow
    }
    
    $results += @{Check="Host Pool"; Status="✅"}
} catch {
    Write-Host "❌ Host pool check failed: $_" -ForegroundColor Red
    $results += @{Check="Host Pool"; Status="❌"}
}

# Check 2: VM State
Write-Host "[2/8] Checking VM state..." -ForegroundColor Yellow
try {
    $vm = & $az vm get-instance-view -g $ResourceGroup -n $VMName -o json | ConvertFrom-Json
    $power = $vm.instanceView.statuses[1].displayStatus
    $prov = $vm.provisioningState
    
    Write-Host "✅ VM found" -ForegroundColor Green
    Write-Host "   Power: $power | Provisioning: $prov" -ForegroundColor Gray
    
    if ($power -eq "VM running" -and $prov -eq "Succeeded") {
        Write-Host "✅ VM is running and provisioned" -ForegroundColor Green
        $results += @{Check="VM State"; Status="✅"}
    } else {
        Write-Host "⚠️  VM state not optimal" -ForegroundColor Yellow
        $results += @{Check="VM State"; Status="⚠️"}
    }
} catch {
    Write-Host "❌ VM check failed: $_" -ForegroundColor Red
    $results += @{Check="VM State"; Status="❌"}
}

# Check 3: Extensions
Write-Host "[3/8] Checking extensions..." -ForegroundColor Yellow
try {
    $exts = & $az vm extension list -g $ResourceGroup --vm-name $VMName | ConvertFrom-Json
    
    $aad = $exts | Where-Object { $_.name -eq "AADLoginForWindows" }
    if ($aad) {
        Write-Host "✅ AADLoginForWindows: $($aad.provisioningState)" -ForegroundColor Green
    }
    
    $avd = $exts | Where-Object { $_.name -like "AVD*" -or $_.name -eq "CustomScriptExtension" }
    if ($avd) {
        Write-Host "✅ AVD Extension: $($avd.name) - $($avd.provisioningState)" -ForegroundColor Green
    }
    
    $results += @{Check="Extensions"; Status="✅"}
} catch {
    Write-Host "⚠️  Extension check: $_" -ForegroundColor Yellow
    $results += @{Check="Extensions"; Status="⚠️"}
}

# Check 4: Entra Join Status
Write-Host "[4/8] Checking Entra join status..." -ForegroundColor Yellow
try {
    $dsregStatus = & $az vm run-command invoke -g $ResourceGroup -n $VMName `
        --command-id RunPowerShellScript `
        --scripts 'dsregcmd /status' `
        --query "value[0].message" -o tsv 2>&1
    
    if ($dsregStatus -match "AzureAdJoined\s*:\s*YES") {
        Write-Host "✅ Entra AD joined: YES" -ForegroundColor Green
        $results += @{Check="Entra Join"; Status="✅"}
    } else {
        Write-Host "⚠️  Entra join status unclear" -ForegroundColor Yellow
        $results += @{Check="Entra Join"; Status="⚠️"}
    }
} catch {
    Write-Host "⚠️  Could not verify Entra join: $_" -ForegroundColor Yellow
    $results += @{Check="Entra Join"; Status="⚠️"}
}

# Check 5: AVD Agent Services
Write-Host "[5/8] Checking AVD agent services..." -ForegroundColor Yellow
try {
    $services = & $az vm run-command invoke -g $ResourceGroup -n $VMName `
        --command-id RunPowerShellScript `
        --scripts 'Get-Service RDAgentBootLoader,RDAgent -ErrorAction SilentlyContinue | Select-Object Name,Status' `
        --query "value[0].message" -o tsv 2>&1
    
    if ($services -match "RDAgent.*Running" -and $services -match "RDAgentBootLoader.*Running") {
        Write-Host "✅ Both services running" -ForegroundColor Green
        Write-Host "   $services" -ForegroundColor Gray
        $results += @{Check="AVD Services"; Status="✅"}
    } else {
        Write-Host "⚠️  Services may not be running" -ForegroundColor Yellow
        $results += @{Check="AVD Services"; Status="⚠️"}
    }
} catch {
    Write-Host "⚠️  Service check failed: $_" -ForegroundColor Yellow
    $results += @{Check="AVD Services"; Status="⚠️"}
}

# Check 6: Provisioning State
Write-Host "[6/8] Checking provisioning state..." -ForegroundColor Yellow
try {
    $provState = & $az vm run-command invoke -g $ResourceGroup -n $VMName `
        --command-id RunPowerShellScript `
        --scripts 'Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning" -Name "AVDAgentProvisioningState" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty AVDAgentProvisioningState' `
        --query "value[0].message" -o tsv 2>&1
    
    Write-Host "   Provisioning State: $provState" -ForegroundColor Gray
    
    if ($provState -eq "Completed") {
        Write-Host "✅ Provisioning COMPLETED" -ForegroundColor Green
        $results += @{Check="Provisioning State"; Status="✅"}
    } elseif ($provState -eq "Skipped") {
        Write-Host "❌ Provisioning SKIPPED (token issue)" -ForegroundColor Red
        $results += @{Check="Provisioning State"; Status="❌"}
    } else {
        Write-Host "⚠️  Unknown state: $provState" -ForegroundColor Yellow
        $results += @{Check="Provisioning State"; Status="⚠️"}
    }
} catch {
    Write-Host "⚠️  Could not check provisioning state: $_" -ForegroundColor Yellow
    $results += @{Check="Provisioning State"; Status="⚠️"}
}

# Check 7: Session Host Registration
Write-Host "[7/8] Checking session host registration..." -ForegroundColor Yellow
try {
    $hosts = & $az resource list -g $ResourceGroup `
        --resource-type Microsoft.DesktopVirtualization/hostPools/sessionHosts `
        --query "[].{name:name,status:properties.status,heartbeat:properties.lastHeartBeat}" | ConvertFrom-Json
    
    if ($hosts -and $hosts.Count -gt 0) {
        Write-Host "✅ Session host(s) registered: $($hosts.Count)" -ForegroundColor Green
        $hosts | ForEach-Object {
            Write-Host "   Name: $($_.name) | Status: $($_.status) | LastHB: $($_.heartbeat)" -ForegroundColor Gray
        }
        $results += @{Check="Session Host Registration"; Status="✅"}
    } else {
        Write-Host "❌ NO session hosts registered" -ForegroundColor Red
        Write-Host "   Broker registration still pending (see troubleshooting guide)" -ForegroundColor Gray
        $results += @{Check="Session Host Registration"; Status="❌"}
    }
} catch {
    Write-Host "⚠️  Could not check registration: $_" -ForegroundColor Yellow
    $results += @{Check="Session Host Registration"; Status="⚠️"}
}

# Check 8: Network Connectivity
Write-Host "[8/8] Checking broker connectivity..." -ForegroundColor Yellow
try {
    $connectivity = Test-NetConnection -ComputerName "rdbroker-g-us-r1.wvd.microsoft.com" -Port 443 -WarningAction SilentlyContinue
    
    if ($connectivity.TcpTestSucceeded) {
        Write-Host "✅ Broker reachable" -ForegroundColor Green
        $results += @{Check="Broker Connectivity"; Status="✅"}
    } else {
        Write-Host "❌ Cannot reach broker" -ForegroundColor Red
        $results += @{Check="Broker Connectivity"; Status="❌"}
    }
} catch {
    Write-Host "⚠️  Connectivity check: $_" -ForegroundColor Yellow
    $results += @{Check="Broker Connectivity"; Status="⚠️"}
}

# Optional: Check User RBAC
if ($UserPrincipalName) {
    Write-Host "[+] Checking user RBAC..." -ForegroundColor Yellow
    try {
        $roles = & $az role assignment list --assignee $UserPrincipalName `
            --resource-group $ResourceGroup | ConvertFrom-Json
        
        if ($roles -and $roles.Count -gt 0) {
            Write-Host "✅ User has roles assigned:" -ForegroundColor Green
            $roles | ForEach-Object {
                Write-Host "   $($_.roleDefinitionName)" -ForegroundColor Gray
            }
        } else {
            Write-Host "⚠️  No roles found for user" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "⚠️  Could not check RBAC: $_" -ForegroundColor Yellow
    }
}

# Summary
Write-Host "`n=== Verification Summary ===" -ForegroundColor Cyan
$results | ForEach-Object {
    Write-Host "$($_.Status) $($_.Check)" -ForegroundColor Green
}

$passCount = ($results | Where-Object { $_.Status -eq "✅" }).Count
$warnCount = ($results | Where-Object { $_.Status -eq "⚠️" }).Count
$failCount = ($results | Where-Object { $_.Status -eq "❌" }).Count

Write-Host "`nTotal: $passCount passed, $warnCount warnings, $failCount failed" -ForegroundColor Gray

if ($failCount -gt 0) {
    Write-Host "`n⚠️  Issues detected. See troubleshooting guide in AVD-PROVISIONING-GUIDE.md" -ForegroundColor Yellow
}
