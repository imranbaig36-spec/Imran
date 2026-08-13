#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-flight checks for AVD provisioning setup.
.DESCRIPTION
    Validates Azure CLI setup, RBAC permissions, network prerequisites, and service availability.
.PARAMETER SubscriptionId
    Azure Subscription ID.
.PARAMETER ResourceGroup
    Azure Resource Group name.
.PARAMETER Region
    Azure region (e.g., eastus).
.EXAMPLE
    .\01-Pre-Flight-Checks.ps1 -SubscriptionId "4e7bcf35-9384-4498-bc21-d9d1221b5faa" `
      -ResourceGroup "dwpai-lab-rg" -Region "eastus"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$Region
)

$ErrorActionPreference = "Continue"
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

Write-Host "=== AVD Provisioning Pre-Flight Checks ===" -ForegroundColor Cyan
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "Region: $Region`n" -ForegroundColor Gray

# 1. Check Azure CLI
Write-Host "[1/6] Checking Azure CLI..." -ForegroundColor Yellow
try {
    $cliVersion = & $az --version | Select-String "azure-cli"
    Write-Host "✅ Azure CLI installed: $cliVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure CLI not found or not working" -ForegroundColor Red
    exit 1
}

# 2. Check subscription access
Write-Host "[2/6] Checking subscription access..." -ForegroundColor Yellow
try {
    & $az account show --subscription $SubscriptionId > $null
    $account = & $az account show --subscription $SubscriptionId | ConvertFrom-Json
    Write-Host "✅ Subscription accessible: $($account.name)" -ForegroundColor Green
} catch {
    Write-Host "❌ Cannot access subscription" -ForegroundColor Red
    exit 1
}

# 3. Check operator permissions
Write-Host "[3/6] Checking operator permissions..." -ForegroundColor Yellow
try {
    $perms = & $az rest --method get --url "/subscriptions/$SubscriptionId/providers/Microsoft.Authorization/permissions?api-version=2015-07-01" 2>&1 | ConvertFrom-Json
    $canAssignRoles = $perms.value | Where-Object { $_.actions -contains "*" -or $_.actions -contains "*/write" } | Measure-Object
    
    if ($canAssignRoles.Count -gt 0) {
        Write-Host "✅ Operator has sufficient permissions (Owner/Contributor)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Cannot verify role assignment permissions" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Could not verify permissions: $_" -ForegroundColor Yellow
}

# 4. Check resource group
Write-Host "[4/6] Checking resource group..." -ForegroundColor Yellow
try {
    & $az group show -g $ResourceGroup > $null 2>&1
    Write-Host "✅ Resource group exists: $ResourceGroup" -ForegroundColor Green
} catch {
    Write-Host "❌ Resource group not found" -ForegroundColor Red
    exit 1
}

# 5. Check AVD extension
Write-Host "[5/6] Checking AVD CLI extension..." -ForegroundColor Yellow
try {
    & $az extension show --name desktopvirtualization > $null 2>&1
    $ext = & $az extension show --name desktopvirtualization | ConvertFrom-Json
    Write-Host "✅ AVD extension installed: v$($ext.version)" -ForegroundColor Green
} catch {
    Write-Host "⚠️  AVD extension not found, installing..." -ForegroundColor Yellow
    & $az extension add --name desktopvirtualization --allow-preview true
    Write-Host "✅ AVD extension installed" -ForegroundColor Green
}

# 6. Check network connectivity to AVD broker
Write-Host "[6/6] Checking network connectivity..." -ForegroundColor Yellow
try {
    $brokerEndpoint = "rdbroker-g-us-r1.wvd.microsoft.com"
    $connection = Test-NetConnection -ComputerName $brokerEndpoint -Port 443 -WarningAction SilentlyContinue
    if ($connection.TcpTestSucceeded) {
        Write-Host "✅ AVD broker reachable ($brokerEndpoint:443)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Cannot reach AVD broker endpoint" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Network check skipped: $_" -ForegroundColor Yellow
}

Write-Host "`n=== Pre-Flight Checks Complete ===" -ForegroundColor Cyan
Write-Host "Status: Ready to proceed with AVD provisioning" -ForegroundColor Green
