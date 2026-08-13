#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates an AVD session host VM with Windows 11 multi-session, Trusted Launch security, and Entra ID join.
.DESCRIPTION
    Provisions VM with:
    - Windows 11 multi-session image (with M365 apps)
    - Trusted Launch security (SecureBoot, vTPM)
    - System-assigned managed identity
    - Public IP and NSG for RDP access
    - Entra ID domain join readiness
.PARAMETER ResourceGroup
    Azure Resource Group name.
.PARAMETER VMName
    VM name (e.g., pfin01sh63).
.PARAMETER VMSize
    VM size (e.g., Standard_B2ms). Default: Standard_B2ms.
.PARAMETER VNetName
    VNet name for VM placement.
.PARAMETER SubnetName
    Subnet name within VNet.
.PARAMETER ImagePublisher
    Image publisher (default: MicrosoftWindowsDesktop).
.PARAMETER ImageOffer
    Image offer (default: office-365).
.PARAMETER ImageSku
    Image SKU (default: win11-24h2-avd-m365).
.EXAMPLE
    .\03-Create-SessionHost-VM.ps1 -ResourceGroup "dwpai-lab-rg" `
      -VMName "pfin01sh63" -VNetName "dwp-p43-winVNET" -SubnetName "dwp-p43-winSubnet"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$VMName,
    
    [Parameter(Mandatory=$false)]
    [string]$VMSize = "Standard_B2ms",
    
    [Parameter(Mandatory=$true)]
    [string]$VNetName,
    
    [Parameter(Mandatory=$true)]
    [string]$SubnetName,
    
    [Parameter(Mandatory=$false)]
    [string]$ImagePublisher = "MicrosoftWindowsDesktop",
    
    [Parameter(Mandatory=$false)]
    [string]$ImageOffer = "office-365",
    
    [Parameter(Mandatory=$false)]
    [string]$ImageSku = "win11-24h2-avd-m365"
)

$ErrorActionPreference = "Stop"
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

Write-Host "=== Creating AVD Session Host VM ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "VM Name: $VMName" -ForegroundColor Gray
Write-Host "VM Size: $VMSize" -ForegroundColor Gray
Write-Host "Image: $ImagePublisher/$ImageOffer/$ImageSku`n" -ForegroundColor Gray

# Step 1: Create Public IP
Write-Host "[1/5] Creating public IP..." -ForegroundColor Yellow
try {
    & $az network public-ip create `
        -g $ResourceGroup `
        -n "$VMName-pip" `
        --allocation-method Static `
        --sku Standard `
        --dns-name $VMName `
        --output json > $null
    
    $publicIp = & $az network public-ip show -g $ResourceGroup -n "$VMName-pip" `
        --query "{ipAddress:ipAddress, fqdn:dnsSettings.fqdn}" -o json | ConvertFrom-Json
    
    Write-Host "✅ Public IP created: $($publicIp.ipAddress)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create public IP: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Create NSG with RDP rule
Write-Host "[2/5] Creating NSG and RDP rule..." -ForegroundColor Yellow
try {
    & $az network nsg create `
        -g $ResourceGroup `
        -n "$VMName-nsg" `
        --output json > $null
    
    # Get current client IP
    $clientIp = (Invoke-WebRequest -Uri "https://ifconfig.me" -UseBasicParsing).Content.Trim()
    
    & $az network nsg rule create `
        -g $ResourceGroup `
        --nsg-name "$VMName-nsg" `
        -n "allow-rdp-from-current-client" `
        --priority 1001 `
        --direction Inbound `
        --access Allow `
        --protocol Tcp `
        --source-address-prefixes "$clientIp/32" `
        --destination-port-ranges 3389 `
        --output json > $null
    
    Write-Host "✅ NSG created with RDP rule from $clientIp/32" -ForegroundColor Green
} catch {
    Write-Host "⚠️  RDP rule creation issue: $_" -ForegroundColor Yellow
    # Continue anyway, rule can be added manually
}

# Step 3: Create NIC
Write-Host "[3/5] Creating network interface..." -ForegroundColor Yellow
try {
    $subnetId = & $az network vnet subnet show -g $ResourceGroup --vnet-name $VNetName \
        -n $SubnetName --query id -o tsv
    
    $publicIpId = & $az network public-ip show -g $ResourceGroup -n "$VMName-pip" \
        --query id -o tsv
    
    $nsgId = & $az network nsg show -g $ResourceGroup -n "$VMName-nsg" --query id -o tsv
    
    & $az network nic create `
        -g $ResourceGroup `
        -n "$VMName-nic" `
        --subnet $subnetId `
        --public-ip-address $publicIpId `
        --network-security-group $nsgId `
        --accelerated-networking false `
        --output json > $null
    
    Write-Host "✅ NIC created and attached" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create NIC: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Create VM
Write-Host "[4/5] Creating VM with Trusted Launch..." -ForegroundColor Yellow
try {
    $nicId = & $az network nic show -g $ResourceGroup -n "$VMName-nic" --query id -o tsv
    
    & $az vm create `
        -g $ResourceGroup `
        -n $VMName `
        --nics $nicId `
        --image "$ImagePublisher:$ImageOffer:$ImageSku:latest" `
        --size $VMSize `
        --os-disk-size-gb 128 `
        --os-disk-name "$VMName-osdisk" `
        --os-disk-delete-option Delete `
        --security-type TrustedLaunch `
        --enable-secure-boot true `
        --enable-vtpm true `
        --assign-identity `
        --license-type Windows_Client `
        --no-wait `
        --output json > $null
    
    Write-Host "✅ VM creation started (running in background)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create VM: $_" -ForegroundColor Red
    exit 1
}

# Step 5: Wait for VM provisioning
Write-Host "[5/5] Waiting for VM provisioning..." -ForegroundColor Yellow
try {
    $maxAttempts = 120
    $attempt = 0
    
    do {
        $vmState = & $az vm get-instance-view -g $ResourceGroup -n $VMName `
            --query "{provisioningState:provisioningState, powerState:instanceView.statuses[1].displayStatus}" -o json 2>&1 | ConvertFrom-Json
        
        if ($vmState.provisioningState -eq "Succeeded") {
            Write-Host "✅ VM provisioning complete - Power: $($vmState.powerState)" -ForegroundColor Green
            break
        }
        
        $attempt++
        Write-Host "   Wait... Provisioning State: $($vmState.provisioningState) (Attempt $attempt/$maxAttempts)" -ForegroundColor Gray
        
        if ($attempt -ge $maxAttempts) {
            Write-Host "⏱️  VM still provisioning. Check status with:" -ForegroundColor Yellow
            Write-Host "   az vm get-instance-view -g $ResourceGroup -n $VMName" -ForegroundColor Yellow
            break
        }
        
        Start-Sleep -Seconds 5
    } while ($true)
} catch {
    Write-Host "⚠️  Could not verify VM state: $_" -ForegroundColor Yellow
}

# Display VM details
Write-Host "`n=== Session Host VM Created ===" -ForegroundColor Cyan
Write-Host "VM Name: $VMName" -ForegroundColor Green
Write-Host "Size: $VMSize" -ForegroundColor Green
Write-Host "Image: $ImagePublisher/$ImageOffer/$ImageSku" -ForegroundColor Green
Write-Host "Public IP: $($publicIp.ipAddress)" -ForegroundColor Green
Write-Host "FQDN: $($publicIp.fqdn)" -ForegroundColor Green
Write-Host "System-Assigned Identity: Enabled" -ForegroundColor Green

Write-Host "`nRDP Connection:" -ForegroundColor Cyan
Write-Host "mstsc /v:$($publicIp.fqdn)" -ForegroundColor Yellow

Write-Host "`nNext Step: Run script 04-Configure-Entra-Join.ps1 to deploy Entra ID extension" -ForegroundColor Yellow
