#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates AVD control plane components (host pool, workspace, app group).
.DESCRIPTION
    Provisions host pool with BreadthFirst load balancing, workspace, and desktop app group.
    Generates 24-hour registration token for session host provisioning.
.PARAMETER ResourceGroup
    Azure Resource Group name.
.PARAMETER HostPoolName
    Name for the host pool (e.g., POOL-FIN-01).
.PARAMETER WorkspaceName
    Name for the workspace (e.g., FinBridge-Workspace).
.PARAMETER AppGroupName
    Name for the app group (e.g., POOL-FIN-01-DAG).
.PARAMETER HostPoolType
    Host pool type: Pooled or Personal. Default: Pooled.
.PARAMETER LoadBalancerType
    Load balancer: BreadthFirst, DepthFirst, or Persistent. Default: BreadthFirst.
.PARAMETER MaxSessionLimit
    Maximum sessions per session host. Default: 5.
.EXAMPLE
    .\02-Create-ControlPlane.ps1 -ResourceGroup "dwpai-lab-rg" `
      -HostPoolName "POOL-FIN-01" -WorkspaceName "FinBridge-Workspace" `
      -AppGroupName "POOL-FIN-01-DAG"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName,
    
    [Parameter(Mandatory=$true)]
    [string]$AppGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$HostPoolType = "Pooled",
    
    [Parameter(Mandatory=$false)]
    [string]$LoadBalancerType = "BreadthFirst",
    
    [Parameter(Mandatory=$false)]
    [int]$MaxSessionLimit = 5
)

$ErrorActionPreference = "Stop"
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

Write-Host "=== Creating AVD Control Plane ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "Host Pool: $HostPoolName" -ForegroundColor Gray
Write-Host "Workspace: $WorkspaceName" -ForegroundColor Gray
Write-Host "App Group: $AppGroupName`n" -ForegroundColor Gray

# Step 1: Create Host Pool
Write-Host "[1/3] Creating host pool..." -ForegroundColor Yellow
try {
    & $az desktopvirtualization hostpool create `
        -g $ResourceGroup `
        -n $HostPoolName `
        --host-pool-type $HostPoolType `
        --load-balancer-type $LoadBalancerType `
        --max-session-limit $MaxSessionLimit `
        --description "Finance pooled host pool for Windows 11 migration project" `
        --friendly-name $HostPoolName `
        --custom-rdp-property "enablerdsaadauth:i:1;targetisaadjoined:i:1;" `
        --output json > $null
    
    Write-Host "✅ Host pool created: $HostPoolName" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create host pool: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Create Workspace
Write-Host "[2/3] Creating workspace..." -ForegroundColor Yellow
try {
    & $az desktopvirtualization workspace create `
        -g $ResourceGroup `
        -n $WorkspaceName `
        --friendly-name $WorkspaceName `
        --description "Finance AVD workspace" `
        --output json > $null
    
    Write-Host "✅ Workspace created: $WorkspaceName" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create workspace: $_" -ForegroundColor Red
    exit 1
}

# Step 3: Create Desktop App Group
Write-Host "[3/3] Creating app group..." -ForegroundColor Yellow
try {
    $hostPoolId = "$(& $az desktopvirtualization hostpool show -g $ResourceGroup -n $HostPoolName --query id -o tsv)"
    
    & $az desktopvirtualization applicationgroup create `
        -g $ResourceGroup `
        -n $AppGroupName `
        --host-pool-id $hostPoolId `
        --app-group-type Desktop `
        --friendly-name "$AppGroupName (Desktop)" `
        --description "Desktop application group for POOL-FIN-01" `
        --output json > $null
    
    Write-Host "✅ App group created: $AppGroupName" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create app group: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Link Workspace to App Group
Write-Host "[4/4] Linking workspace to app group..." -ForegroundColor Yellow
try {
    $workspaceId = "$(& $az desktopvirtualization workspace show -g $ResourceGroup -n $WorkspaceName --query id -o tsv)"
    $appGroupId = "$(& $az desktopvirtualization applicationgroup show -g $ResourceGroup -n $AppGroupName --query id -o tsv)"
    
    & $az desktopvirtualization workspace update `
        -g $ResourceGroup `
        -n $WorkspaceName `
        --add "applicationGroupReferences=$appGroupId" `
        --output json > $null
    
    Write-Host "✅ Workspace linked to app group" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to link workspace: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Generate Registration Token
Write-Host "`n[5/5] Generating registration token..." -ForegroundColor Yellow
try {
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
    
    Write-Host "✅ Registration token generated (24-hour expiry)" -ForegroundColor Green
    Write-Host "`nToken (save for session host provisioning):" -ForegroundColor Cyan
    Write-Host $token -ForegroundColor White
    
    # Save token to file
    $token | Out-File -FilePath "$PSScriptRoot\registration-token.txt" -Force
    Write-Host "`n✅ Token saved to: $PSScriptRoot\registration-token.txt" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Failed to generate token: $_" -ForegroundColor Red
    exit 1
}

# Display summary
Write-Host "`n=== Control Plane Created Successfully ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Green
Write-Host "Host Pool: $HostPoolName (Pooled, BreadthFirst, max $MaxSessionLimit sessions)" -ForegroundColor Green
Write-Host "Workspace: $WorkspaceName" -ForegroundColor Green
Write-Host "App Group: $AppGroupName" -ForegroundColor Green
Write-Host "`n⏱️  Registration token expires: $expirationTime" -ForegroundColor Yellow
Write-Host "`nNext Step: Run script 03-Create-SessionHost-VM.ps1 to create session host" -ForegroundColor Yellow
