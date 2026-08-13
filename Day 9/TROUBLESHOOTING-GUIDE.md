# AVD Provisioning Troubleshooting Guide

**Version:** 1.0  
**Date:** August 13, 2026

---

## Table of Contents

1. [Common Issues](#common-issues)
2. [Diagnostic Commands](#diagnostic-commands)
3. [Error Resolution](#error-resolution)
4. [Service Recovery](#service-recovery)
5. [Network Troubleshooting](#network-troubleshooting)
6. [Escalation Path](#escalation-path)

---

## Common Issues

### Issue 1: Provisioning State = "Skipped"

**Symptoms:**
- AVD agent installed but registry shows `AVDAgentProvisioningState = "Skipped"`
- Session host doesn't appear in broker
- No broker communication

**Root Causes:**
- Invalid or expired registration token during MSI install
- Broker connectivity failure during installation
- Insufficient token scope or permissions

**Resolution:**
```powershell
# Run recovery script
.\08-Reinstall-AVD-Agent.ps1 -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" -VMName "pfin01sh63"
```

**Manual Fix:**
```powershell
# On the VM (via RDP):
# 1. Generate fresh token
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
$token = & $az desktopvirtualization hostpool show -g "dwpai-lab-rg" `
  -n "POOL-FIN-01" --query "registrationInfo.token" -o tsv

# 2. Uninstall old packages
msiexec /x "C:\AVDInstall\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi" /qn
msiexec /x "C:\AVDInstall\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.15008.300.msi" /qn
Start-Sleep -Seconds 5

# 3. Reinstall with fresh token
msiexec /i "C:\AVDInstall\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.15008.300.msi" /qn `
  REGISTRATIONTOKEN="$token"
msiexec /i "C:\AVDInstall\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi" /qn

# 4. Restart services
Restart-Service RDAgentBootLoader -Force
Restart-Service RDAgent -Force

# 5. Verify
Start-Sleep -Seconds 10
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning" `
  -Name "AVDAgentProvisioningState"
```

---

### Issue 2: Session Host Not Registering Despite "Completed" State

**Symptoms:**
- Provisioning state shows "Completed"
- Services RDAgent and RDAgentBootLoader are running
- Session host never appears in broker
- No errors in event log

**Root Causes:**
- Broker backend validation failure
- Token encoding/format issue
- Broker policy or subscription limits
- Transient broker service issue
- TLS/certificate validation problem

**Diagnostics:**
```powershell
# 1. Check broker connectivity
Test-NetConnection -ComputerName "rdbroker-g-us-r1.wvd.microsoft.com" -Port 443

# 2. Check event log for RDAgent errors
Get-EventLog -LogName "Application" -Source "RDAgent*" -Newest 20 | 
  Where-Object {$_.EventID -ne 3389} | 
  Select-Object TimeGenerated,EventID,Message

# 3. Check WinRM status (used for guest communication)
Get-Service WinRM | Select-Object Status,StartType
Start-Service WinRM -ErrorAction SilentlyContinue

# 4. Check token validity
$token = 'paste_token_here'
# Decode JWT (manual or use online tool): https://jwt.io
# Verify exp, aud, iss fields match expected values

# 5. Check host pool registration info
az desktopvirtualization hostpool show -g "dwpai-lab-rg" -n "POOL-FIN-01" `
  --query "registrationInfo"
```

**Recovery Options:**
```powershell
# Option 1: Force refresh of host pool token
$exp = (Get-Date).ToUniversalTime().AddHours(24).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
az desktopvirtualization hostpool update -g "dwpai-lab-rg" -n "POOL-FIN-01" `
  --registration-info "expiration-time=$exp" "registration-token-operation=Update"

# Option 2: Delete and recreate host pool
az desktopvirtualization hostpool delete -g "dwpai-lab-rg" -n "POOL-FIN-01" --yes
# Then recreate with different name

# Option 3: Restart VM completely
az vm restart -g "dwpai-lab-rg" -n "pfin01sh63"
```

---

### Issue 3: Cannot RDP to VM

**Symptoms:**
- Connection timeout or refused
- "Remote Desktop can't find the computer"
- Connection reset by host

**Causes:**
- VM not running
- Public IP not assigned
- NSG blocking RDP
- VM hostname/DNS not resolving
- Entra extension not deployed

**Resolution:**
```powershell
# 1. Verify VM is running
az vm get-instance-view -g "dwpai-lab-rg" -n "pfin01sh63" `
  --query "instanceView.statuses[1].displayStatus"
# Should return: "VM running"

# 2. Check public IP
az vm show -d -g "dwpai-lab-rg" -n "pfin01sh63" `
  --query "publicIps,fqdns"

# 3. Verify NSG rule allows RDP from your IP
az network nsg rule list -g "dwpai-lab-rg" --nsg-name "pfin01sh63-nsg" `
  --query "[?name == 'allow-rdp*']"

# 4. If needed, add RDP rule
$yourIp = (Invoke-WebRequest -Uri "https://ifconfig.me").Content.Trim()
az network nsg rule create -g "dwpai-lab-rg" --nsg-name "pfin01sh63-nsg" `
  -n "allow-rdp-from-me" --priority 1001 --direction Inbound `
  --access Allow --protocol Tcp --source-address-prefixes "$yourIp/32" `
  --destination-port-ranges 3389

# 5. Start VM if stopped
az vm start -g "dwpai-lab-rg" -n "pfin01sh63" --no-wait

# 6. Test connectivity
Test-NetConnection -ComputerName "pfin01sh63.eastus.cloudapp.azure.com" -Port 3389
```

---

### Issue 4: Entra Join Failed

**Symptoms:**
- Cannot authenticate with Entra ID credentials at RDP login
- AADLoginForWindows extension shows failed state

**Verification:**
```powershell
# Via RDP on VM, run:
dsregcmd /status
# Look for: AzureAdJoined : YES

# Check extension status from management machine:
az vm extension show -g "dwpai-lab-rg" --vm-name "pfin01sh63" `
  -n AADLoginForWindows --query "provisioningState"
# Should return: Succeeded

# Check for errors
az vm extension show -g "dwpai-lab-rg" --vm-name "pfin01sh63" `
  -n AADLoginForWindows --expand instanceView
```

**Recovery:**
```powershell
# Reinstall AADLoginForWindows extension
az vm extension set -g "dwpai-lab-rg" --vm-name "pfin01sh63" `
  --name AADLoginForWindows --publisher Microsoft.Azure.ActiveDirectory `
  --version 2.2 --force-update

# Restart VM
az vm restart -g "dwpai-lab-rg" -n "pfin01sh63"

# Re-verify
Start-Sleep -Seconds 30
az vm extension show -g "dwpai-lab-rg" --vm-name "pfin01sh63" `
  -n AADLoginForWindows --query "provisioningState"
```

---

### Issue 5: User Cannot Access Desktop

**Symptoms:**
- User signs in to AVD web client but no desktops appear
- Or: "No desktops available"

**Causes:**
- No session hosts registered
- Session host in "Unavailable" state
- User missing RBAC roles
- App group not linked to workspace

**Diagnostics:**
```powershell
# 1. Check session hosts
az resource list -g "dwpai-lab-rg" `
  --resource-type Microsoft.DesktopVirtualization/hostPools/sessionHosts `
  --query "[].{name:name,status:properties.status}"

# 2. Check user roles
az role assignment list --assignee "p43@zippyops.in" -g "dwpai-lab-rg"
# Should include: Virtual Machine User Login, Desktop Virtualization User

# 3. Check app group links
az desktopvirtualization applicationgroup show -g "dwpai-lab-rg" `
  -n "POOL-FIN-01-DAG" --query "id"

az desktopvirtualization workspace show -g "dwpai-lab-rg" `
  -n "FinBridge-Workspace" --query "applicationGroupReferences"
```

**Fix:**
```powershell
# If session host missing, run registration script
.\07-Verify-Registration.ps1 -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" -VMName "pfin01sh63"

# If user roles missing
.\06-Assign-User-Roles.ps1 -ResourceGroup "dwpai-lab-rg" `
  -UserPrincipalName "p43@zippyops.in" -HostPoolName "POOL-FIN-01" `
  -AppGroupName "POOL-FIN-01-DAG"

# If links missing, relink
$appGroupId = az desktopvirtualization applicationgroup show -g "dwpai-lab-rg" `
  -n "POOL-FIN-01-DAG" --query id -o tsv

az desktopvirtualization workspace update -g "dwpai-lab-rg" `
  -n "FinBridge-Workspace" --add "applicationGroupReferences=$appGroupId"
```

---

## Diagnostic Commands

### Quick Health Check

```powershell
# Run complete verification
.\07-Verify-Registration.ps1 -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" -VMName "pfin01sh63" `
  -UserPrincipalName "p43@zippyops.in"
```

### Check All Resources

```powershell
$rg = "dwpai-lab-rg"
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

Write-Host "=== Host Pool ===" -ForegroundColor Cyan
& $az desktopvirtualization hostpool show -g $rg -n "POOL-FIN-01" `
  --query "{name,hostPoolType,loadBalancerType,maxSessionLimit,token:registrationInfo.token}" -o json

Write-Host "`n=== Workspace ===" -ForegroundColor Cyan
& $az desktopvirtualization workspace show -g $rg -n "FinBridge-Workspace" `
  --query "{name,applicationGroupReferences}" -o json

Write-Host "`n=== App Group ===" -ForegroundColor Cyan
& $az desktopvirtualization applicationgroup show -g $rg -n "POOL-FIN-01-DAG" `
  --query "{name,applicationGroupType,hostPoolId,workspaceId}" -o json

Write-Host "`n=== Session Hosts ===" -ForegroundColor Cyan
& $az resource list -g $rg --resource-type Microsoft.DesktopVirtualization/hostPools/sessionHosts `
  --query "[].{name,status:properties.status,lastHeartBeat:properties.lastHeartBeat}" -o json

Write-Host "`n=== VM ===" -ForegroundColor Cyan
& $az vm show -d -g $rg -n "pfin01sh63" `
  --query "{name,powerState:powerState,publicIps,provisioningState}" -o json

Write-Host "`n=== Extensions ===" -ForegroundColor Cyan
& $az vm extension list -g $rg --vm-name "pfin01sh63" `
  --query "[].{name,provisioningState}" -o json
```

### Guest Diagnostics (via RDP)

```powershell
# Check services
Get-Service RDAgentBootLoader,RDAgent,WinRM | Select-Object Name,Status,StartType

# Check provisioning state
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning"

# Check Entra join
dsregcmd /status | Select-String "AzureAdJoined"

# Check event log
Get-EventLog -LogName "Application" -Source "RDAgent*" -Newest 20 | 
  Select-Object TimeGenerated,EventID,Message | 
  Format-Table -AutoSize

# Check network to broker
Test-NetConnection -ComputerName "rdbroker-g-us-r1.wvd.microsoft.com" -Port 443

# Check installed packages
wmic product list | find /i "RDInfra"

# Test broker connectivity (PowerShell)
$sock = New-Object System.Net.Sockets.TcpClient
$result = $sock.BeginConnect("rdbroker-g-us-r1.wvd.microsoft.com", 443, $null, $null)
$result.AsyncWaitHandle.WaitOne(3000, $true) | Out-Null
Write-Host "Connected: $($sock.Connected)"
```

---

## Error Resolution

### Azure CLI Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `ResourceNotFound` | Resource doesn't exist | Check resource name and RG |
| `AuthorizationFailed` | Insufficient permissions | Add required RBAC role |
| `InvalidParameter` | Bad parameter syntax | Use `--help` to check syntax |
| `Long-running operation wait cancelled` | CLI timeout | Use `--no-wait` flag |

### AVD Agent Errors

| Error | Location | Fix |
|-------|----------|-----|
| MSI exit code 1603 | Event log during install | Re-run with fresh token |
| "Skipped" provisioning | Registry: AVDAgentProvisioningState | Run recovery script |
| Service won't start | Services panel | Check MSI logs in C:\Windows\Temp\avd-*.log |

### Extension Errors

| State | Meaning | Action |
|-------|---------|--------|
| Creating | In progress | Wait, then check again |
| Succeeded | Complete | Verify functionality |
| Failed | Error | Force-update with `--force-update` |
| Updating | Transition state | Wait, avoid multiple updates |

---

## Service Recovery

### Reset Registry Provisioning State

```powershell
# On VM via RDP (as Administrator):
$path = "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning"
Set-ItemProperty $path -Name "AVDAgentProvisioningState" -Value "Provision"
Restart-Service RDAgentBootLoader -Force
```

### Restart Services Safely

```powershell
# On VM via RDP:
# Stop services
Stop-Service RDAgentBootLoader -Force
Stop-Service RDAgent -Force

# Wait
Start-Sleep -Seconds 5

# Start services
Start-Service RDAgent
Start-Service RDAgentBootLoader

# Verify
Get-Service RDAgent,RDAgentBootLoader
```

### Clean AVD Installation

```powershell
# On VM via RDP (as Administrator):
# 1. Stop services
Stop-Service RDAgent,RDAgentBootLoader -Force -ErrorAction SilentlyContinue

# 2. Uninstall packages
msiexec /x "C:\AVDInstall\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi" /qn
msiexec /x "C:\AVDInstall\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.15008.300.msi" /qn

# 3. Delete residual files
Remove-Item "C:\Program Files\Microsoft RDInfra" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -Force -ErrorAction SilentlyContinue

# 4. Get fresh token
$token = ...  # Fetch from Azure

# 5. Reinstall clean
msiexec /i "C:\AVDInstall\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.15008.300.msi" /qn REGISTRATIONTOKEN="$token"
msiexec /i "C:\AVDInstall\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi" /qn

# 6. Restart
Restart-Computer -Force
```

---

## Network Troubleshooting

### Test Connectivity to Broker

```powershell
# From management machine or VM:

# 1. DNS resolution
Resolve-DnsName -Name "rdbroker-g-us-r1.wvd.microsoft.com"

# 2. TCP connectivity
Test-NetConnection -ComputerName "rdbroker-g-us-r1.wvd.microsoft.com" -Port 443

# 3. TLS handshake (PowerShell)
$sock = New-Object System.Net.Sockets.TcpClient
$sock.Connect("rdbroker-g-us-r1.wvd.microsoft.com", 443)

$stream = $sock.GetStream()
$sslStream = New-Object System.Net.Security.SslStream($stream, $false)
$sslStream.AuthenticateAsClient("rdbroker-g-us-r1.wvd.microsoft.com")

Write-Host "TLS Version: $($sslStream.SslProtocol)"
Write-Host "Cipher: $($sslStream.CipherAlgorithm)"
```

### Check NSG Rules

```powershell
# List rules
az network nsg rule list -g "dwpai-lab-rg" --nsg-name "pfin01sh63-nsg" `
  --query "[].{name,sourceAddressPrefix,destinationPortRange,access}" -o json

# Add rule for your IP
$yourIp = (Invoke-WebRequest -Uri "https://ifconfig.me").Content.Trim()
az network nsg rule create -g "dwpai-lab-rg" --nsg-name "pfin01sh63-nsg" `
  -n "AllowYourIP" --priority 1000 --direction Inbound `
  --source-address-prefixes "$yourIp/32" --destination-port-ranges "3389"
```

---

## Escalation Path

### When to Escalate

| Situation | Action |
|-----------|--------|
| Provisioning state stuck "Skipped" after recovery | Run 08-Reinstall-AVD-Agent.ps1 once more |
| Session host won't register despite all fixes | Escalate to Azure Support |
| Event log shows TLS/cert errors | Check VM certificate store, escalate if needed |
| Broker returns 403/401 errors | Escalate for token validation issue |
| Multiple VMs showing same issue | Check host pool/broker service health |

### Information to Provide Support

```
Subscription ID: 4e7bcf35-9384-4498-bc21-d9d1221b5faa
Resource Group: dwpai-lab-rg
Host Pool ID: ac71fa57-ce47-458f-b054-f8fd04538123
Host Pool Name: POOL-FIN-01
VM ID: c008030d-a6e7-4b5d-9f9c-068f4902e835
VM Name: pfin01sh63
Issue: [Describe issue]
Current Provisioning State: [Completed/Skipped]
Last Error (Event Log): [Paste error]
Registration Token (if safe): [Token or "Expired"]
Steps Already Attempted: [List]
```

### Support URLs

- Azure Support: https://portal.azure.com/#blade/HubsExtension/SupportBlade
- AVD Issues: Open "Microsoft.DesktopVirtualization" resource support request
- Session Host Registration: Provide subscription + hostpool IDs in case analysis

---

**Document Version:** 1.0  
**Last Updated:** 2026-08-13  
**Next Review:** Upon completion of pilot deployment
