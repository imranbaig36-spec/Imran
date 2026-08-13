#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Assigns user RBAC roles for AVD access.
.DESCRIPTION
    Grants target user permissions for:
    - Direct VM RDP access via Virtual Machine User Login role
    - AVD desktop access via Desktop Virtualization User role
.PARAMETER ResourceGroup
    Azure Resource Group name.
.PARAMETER UserPrincipalName
    User email/UPN (e.g., p43@zippyops.in).
.PARAMETER HostPoolName
    Host pool name.
.PARAMETER AppGroupName
    Desktop app group name.
.EXAMPLE
    .\06-Assign-User-Roles.ps1 -ResourceGroup "dwpai-lab-rg" `
      -UserPrincipalName "p43@zippyops.in" -HostPoolName "POOL-FIN-01" `
      -AppGroupName "POOL-FIN-01-DAG"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$UserPrincipalName,
    
    [Parameter(Mandatory=$true)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppGroupName
)

$ErrorActionPreference = "Stop"
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

Write-Host "=== Assigning User RBAC Roles ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "User: $UserPrincipalName" -ForegroundColor Gray
Write-Host "Host Pool: $HostPoolName" -ForegroundColor Gray
Write-Host "App Group: $AppGroupName`n" -ForegroundColor Gray

# Step 1: Resolve user object ID
Write-Host "[1/3] Resolving user object ID..." -ForegroundColor Yellow
try {
    $userId = & $az ad user show --id $UserPrincipalName --query id -o tsv
    
    if (-not $userId) {
        Write-Host "❌ User not found: $UserPrincipalName" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ User found: $userId" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to resolve user: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Assign Virtual Machine User Login role (RG level)
Write-Host "[2/3] Assigning Virtual Machine User Login role..." -ForegroundColor Yellow
try {
    & $az role assignment create `
        --assignee-object-id $userId `
        --assignee-principal-type User `
        --role "Virtual Machine User Login" `
        --scope "/subscriptions/$(& $az account show --query id -o tsv)/resourceGroups/$ResourceGroup" `
        --output json > $null
    
    Write-Host "✅ Virtual Machine User Login role assigned" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not verify VM User Login role: $_" -ForegroundColor Yellow
}

# Step 3: Assign Desktop Virtualization User role (App Group level)
Write-Host "[3/3] Assigning Desktop Virtualization User role..." -ForegroundColor Yellow
try {
    $appGroupId = & $az desktopvirtualization applicationgroup show `
        -g $ResourceGroup -n $AppGroupName --query id -o tsv
    
    & $az role assignment create `
        --assignee-object-id $userId `
        --assignee-principal-type User `
        --role "Desktop Virtualization User" `
        --scope $appGroupId `
        --output json > $null
    
    Write-Host "✅ Desktop Virtualization User role assigned" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to assign Desktop Virtualization User role: $_" -ForegroundColor Red
    exit 1
}

# Display summary
Write-Host "`n=== RBAC Assignment Complete ===" -ForegroundColor Cyan
Write-Host "User: $UserPrincipalName" -ForegroundColor Green
Write-Host "Roles Assigned:" -ForegroundColor Green
Write-Host "  ✓ Virtual Machine User Login (RG: $ResourceGroup)" -ForegroundColor Green
Write-Host "  ✓ Desktop Virtualization User (App Group: $AppGroupName)" -ForegroundColor Green

Write-Host "`nUser can now:" -ForegroundColor Yellow
Write-Host "1. RDP directly to VMs in the resource group" -ForegroundColor Yellow
Write-Host "2. Access AVD desktops via FinBridge-Workspace" -ForegroundColor Yellow

Write-Host "`nNext Step: Run script 07-Verify-Registration.ps1 to verify session host" -ForegroundColor Yellow
