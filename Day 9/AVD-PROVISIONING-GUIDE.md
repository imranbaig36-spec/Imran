# Azure Virtual Desktop (AVD) End-to-End Provisioning Guide

**Version:** 1.0  
**Date:** August 13, 2026  
**Author:** AI Training Session - Day 9  
**Environment:** Azure (East US) | Entra ID (zippyops.in)

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Provisioning Steps](#provisioning-steps)
4. [Troubleshooting](#troubleshooting)
5. [Verification Checklist](#verification-checklist)
6. [Access and Validation](#access-and-validation)

---

## Prerequisites

### Required Information
- **Azure Subscription ID:** `4e7bcf35-9384-4498-bc21-d9d1221b5faa`
- **Resource Group:** `dwpai-lab-rg`
- **Region:** `East US`
- **Entra Tenant:** `zippyops.in` (ID: `fa84443c-5a39-4df5-a018-9c876455adf9`)
- **Target User:** `p43@zippyops.in`
- **Operator Credentials:** Must be Owner or Desktop Virtualization Contributor

### Tools Required
- Azure CLI 2.x (with `desktopvirtualization` extension v1.0.0)
- PowerShell 5.1+
- Network access to AVD broker endpoints (rdbroker.wvd.microsoft.com:443)
- Azure Account with sufficient RBAC permissions

### Network Prerequisites
- Existing VNet and subnet: `dwp-p43-winVNET` / `dwp-p43-winSubnet`
- Public IP pool available for VM assignment
- NSG configured to allow RDP inbound (port 3389)

### RBAC Prerequisites
Operator must have permissions to:
- Create and manage AVD host pools/workspaces/app groups
- Create VMs and NICs
- Assign RBAC roles
- Manage DNS and public IPs

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Subscription                        │
│  (4e7bcf35-9384-4498-bc21-d9d1221b5faa)                     │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              AVD Control Plane                        │   │
│  │  ┌─────────────────┐  ┌──────────────┐  ┌─────────┐  │   │
│  │  │  Host Pool      │  │ Workspace    │  │  App    │  │   │
│  │  │ (POOL-FIN-01)   │  │(FinBridge)   │  │ Group   │  │   │
│  │  └────────┬────────┘  └──────────────┘  │(DAG)    │  │   │
│  │           │                             └────┬────┘  │   │
│  │           └────────────────┬───────────────────┘      │   │
│  └──────────────────────────┼──────────────────────────┘   │
│                             │                                │
│  ┌──────────────────────────┼──────────────────────────┐   │
│  │              Session Hosts (VMs)                     │   │
│  │  ┌─────────────────────────────────────────────┐    │   │
│  │  │  pfin01sh63 (Win11 Multi-session)           │    │   │
│  │  │  ├─ Standard_B2ms                           │    │   │
│  │  │  ├─ Trusted Launch + Secure Boot + vTPM    │    │   │
│  │  │  ├─ Entra ID Joined                         │    │   │
│  │  │  ├─ RDAgent + RDAgentBootLoader (INSTALLED) │    │   │
│  │  │  ├─ AADLoginForWindows (INSTALLED)          │    │   │
│  │  │  └─ Public IP: 20.121.189.103               │    │   │
│  │  └─────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  RBAC Assignments                                     │   │
│  │  ├─ p43@zippyops.in: Virtual Machine User Login (RG) │   │
│  │  └─ p43@zippyops.in: Desktop Virtualization User     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Provisioning Steps

### Step 1: Verify Prerequisites and RBAC

**Script:** `01-Pre-Flight-Checks.ps1`

Before starting, verify:
1. ✅ Azure CLI installed and authenticated
2. ✅ Operator has Owner role on subscription
3. ✅ Resource group exists
4. ✅ VNet/subnet available
5. ✅ Entra tenant accessible

```powershell
# Run pre-flight checks
.\Day9\01-Pre-Flight-Checks.ps1 -SubscriptionId "4e7bcf35-9384-4498-bc21-d9d1221b5faa" `
  -ResourceGroup "dwpai-lab-rg" -Region "eastus"
```

**Output:** Validates permissions, network prerequisites, and Azure CLI setup.

---

### Step 2: Create AVD Control Plane

**Script:** `02-Create-ControlPlane.ps1`

Creates host pool, workspace, and application group:

```powershell
# Create AVD infrastructure
.\Day9\02-Create-ControlPlane.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" `
  -WorkspaceName "FinBridge-Workspace" `
  -AppGroupName "POOL-FIN-01-DAG" `
  -HostPoolType "Pooled" `
  -LoadBalancerType "BreadthFirst" `
  -MaxSessionLimit 5
```

**Resources Created:**
- Host Pool: `POOL-FIN-01`
- Workspace: `FinBridge-Workspace`
- Desktop App Group: `POOL-FIN-01-DAG`
- Registration token (24-hour expiry)

**Output:** Registration token for use in VM provisioning.

---

### Step 3: Create Session Host VM

**Script:** `03-Create-SessionHost-VM.ps1`

Deploys Windows 11 multi-session VM with required security settings:

```powershell
# Create session host VM
.\Day9\03-Create-SessionHost-VM.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -VMName "pfin01sh63" `
  -VMSize "Standard_B2ms" `
  -ImagePublisher "MicrosoftWindowsDesktop" `
  -ImageOffer "office-365" `
  -ImageSku "win11-24h2-avd-m365" `
  -VNetName "dwp-p43-winVNET" `
  -SubnetName "dwp-p43-winSubnet" `
  -EnableSystemAssignedIdentity $true `
  -SecurityType "TrustedLaunch"
```

**Resources Created:**
- VM: `pfin01sh63`
- NIC: `pfin01sh63-nic`
- Public IP: `pfin01sh63-pip` (20.121.189.103)
- NSG: `pfin01sh63-nsg` (RDP inbound rule)

**Output:** VM ID, public IP, FQDN.

---

### Step 4: Configure Entra ID Join and Extensions

**Script:** `04-Configure-Entra-Join.ps1`

Deploys AADLoginForWindows extension and configures Entra ID authentication:

```powershell
# Configure Entra ID join and extensions
.\Day9\04-Configure-Entra-Join.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -VMName "pfin01sh63"
```

**Extensions Deployed:**
- `AADLoginForWindows` v2.2.0 (enables Entra ID sign-in)

**Verifications:**
- `dsregcmd /status` shows AzureAdJoined = YES
- VM certificate for Entra auth installed

---

### Step 5: Install AVD Guest Agent

**Script:** `05-Install-AVD-Agent.ps1`

Installs RDAgent and RDAgentBootLoader MSIs with registration token:

```powershell
# Install AVD guest agent
$token = & az desktopvirtualization hostpool show -g "dwpai-lab-rg" `
  -n "POOL-FIN-01" --query "registrationInfo.token" -o tsv

.\Day9\05-Install-AVD-Agent.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -VMName "pfin01sh63" `
  -RegistrationToken $token
```

**Components Installed:**
- `RDAgent` (Remote Desktop Agent)
- `RDAgentBootLoader` (Agent Loader/Heartbeat Service)
- Provisioning state set to "Provision" → "Completed"

**Services Status After Install:**
```
RDAgent: Running
RDAgentBootLoader: Running
WinRM: Running (for management)
RemoteRegistry: (may require elevation)
```

---

### Step 6: Assign User RBAC Roles

**Script:** `06-Assign-User-Roles.ps1`

Grants target user permissions for VM and AVD access:

```powershell
# Assign RBAC roles
.\Day9\06-Assign-User-Roles.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -UserPrincipalName "p43@zippyops.in" `
  -HostPoolName "POOL-FIN-01" `
  -AppGroupName "POOL-FIN-01-DAG"
```

**Roles Assigned:**
- **Virtual Machine User Login** (Resource Group level) → RDP access to VMs
- **Desktop Virtualization User** (App Group level) → AVD desktop access

---

### Step 7: Verify and Troubleshoot Registration

**Script:** `07-Verify-Registration.ps1`

Validates session host registration and diagnoses issues:

```powershell
# Verify registration
.\Day9\07-Verify-Registration.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" `
  -VMName "pfin01sh63"
```

**Checks Performed:**
- ✅ Host pool exists and has valid token
- ✅ VM is powered on and accessible
- ✅ RDAgent services running
- ✅ Provisioning state
- ✅ Session host appears in broker
- ✅ Network connectivity to broker
- ✅ Event log for errors

---

## Troubleshooting

### Issue 1: Provisioning State = "Skipped"

**Cause:** Registration token invalid or expired during MSI install.

**Solution:**
```powershell
# Generate fresh token
$exp = (Get-Date).ToUniversalTime().AddHours(24).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
az desktopvirtualization hostpool update -g "dwpai-lab-rg" -n "POOL-FIN-01" `
  --registration-info "expiration-time=$exp" "registration-token-operation=Update"

# Uninstall and reinstall MSIs on VM with fresh token
.\Day9\08-Reinstall-AVD-Agent.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -VMName "pfin01sh63"
```

### Issue 2: Session Host Not Appearing in Broker

**Cause:** Broker registration failed despite "Completed" provisioning state (network, policy, or validation issue).

**Diagnostic Commands:**
```powershell
# Check broker connectivity from VM
Test-NetConnection -ComputerName "rdbroker-g-us-r1.wvd.microsoft.com" -Port 443

# Check event log for RDAgent errors
Get-EventLog -LogName "Application" -Source "RDAgent*" -Newest 20 | 
  Select-Object TimeGenerated,EventID,Message | 
  Where-Object {$_.EventID -ne 3389}

# Check provisioning state
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning"

# Force service restart
Restart-Service RDAgentBootLoader -Force
```

**Recovery Options:**
1. Delete and recreate host pool with different name
2. Uninstall/reinstall MSIs with fresh token (see Issue 1)
3. Escalate to Azure Support with host pool ID + VM ID

### Issue 3: User Cannot Access Desktop

**Cause:** No session hosts available (not registered) or user RBAC missing.

**Verification:**
```powershell
# Check user roles
az role assignment list --assignee "p43@zippyops.in" -g "dwpai-lab-rg"

# Check app group membership
az desktopvirtualization applicationgroup show -g "dwpai-lab-rg" -n "POOL-FIN-01-DAG"

# Check session hosts in pool
az resource list -g "dwpai-lab-rg" \
  --resource-type Microsoft.DesktopVirtualization/hostPools/sessionHosts \
  --query "[].{name:name,status:properties.status}"
```

---

## Verification Checklist

Run this to validate complete setup:

```powershell
# Complete verification
.\Day9\09-Full-Verification.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" `
  -VMName "pfin01sh63" `
  -UserPrincipalName "p43@zippyops.in"
```

**Expected Output:**
- [ ] Host pool exists with valid configuration
- [ ] Workspace linked to app group
- [ ] App group linked to host pool
- [ ] VM is running and provisioned
- [ ] Entra join confirmed
- [ ] RDAgent services running
- [ ] Provisioning state = "Completed"
- [ ] Session host appears in broker with status = "Available"
- [ ] User has required RBAC roles
- [ ] Broker connectivity verified

---

## Access and Validation

### Direct VM RDP Access

```powershell
# Once VM is deployed, RDP with:
$vmFqdn = az vm show -d -g "dwpai-lab-rg" -n "pfin01sh63" --query "fqdns" -o tsv
mstsc /v:$vmFqdn
# Sign in with p43@zippyops.in (Entra ID)
```

### AVD Desktop Access

```
Endpoint:       https://rdweb.wvd.microsoft.com/arm/webclient/
Workspace:      FinBridge-Workspace
User:           p43@zippyops.in
Expected:       Available desktop session in POOL-FIN-01
```

### Browser RDP Client

```
URL: https://client.wvd.microsoft.com/
Feed Type: Subscribe with URL
Subscribe URL: https://rdweb.wvd.microsoft.com/arm/webclient/
```

---

## Performance Tuning (Optional)

### Enable StartVMOnConnect
For cost savings, auto-start VM when user connects:

```powershell
az desktopvirtualization hostpool update -g "dwpai-lab-rg" -n "POOL-FIN-01" \
  --start-vm-on-connect true
```

### Adjust Session Limits
```powershell
az desktopvirtualization hostpool update -g "dwpai-lab-rg" -n "POOL-FIN-01" \
  --max-session-limit 10  # Change from 5 to 10
```

### Change Load Balancer
```powershell
az desktopvirtualization hostpool update -g "dwpai-lab-rg" -n "POOL-FIN-01" \
  --load-balancer-type DepthFirst  # Balance by session depth
```

---

## Cleanup

### Delete Everything (Development/Test Only)

```powershell
# Delete session host
az vm delete -g "dwpai-lab-rg" -n "pfin01sh63" --yes --no-wait

# Delete app group
az desktopvirtualization applicationgroup delete -g "dwpai-lab-rg" -n "POOL-FIN-01-DAG" --yes

# Delete workspace
az desktopvirtualization workspace delete -g "dwpai-lab-rg" -n "FinBridge-Workspace" --yes

# Delete host pool
az desktopvirtualization hostpool delete -g "dwpai-lab-rg" -n "POOL-FIN-01" --yes

# Delete network resources
az network nsg delete -g "dwpai-lab-rg" -n "pfin01sh63-nsg" --yes --no-wait
az network public-ip delete -g "dwpai-lab-rg" -n "pfin01sh63-pip" --yes --no-wait
az network nic delete -g "dwpai-lab-rg" -n "pfin01sh63-nic" --yes --no-wait
```

---

## Reference Links

- [Microsoft AVD Documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [AVD PowerShell Docs](https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/)
- [Host Pool Creation Guide](https://learn.microsoft.com/en-us/azure/virtual-desktop/create-host-pools-azure-marketplace)
- [Session Host Requirements](https://learn.microsoft.com/en-us/azure/virtual-desktop/prerequisites)
- [AVD Troubleshooting](https://learn.microsoft.com/en-us/azure/virtual-desktop/troubleshoot-client-connection)

---

**Document Version:** 1.0  
**Last Updated:** 2026-08-13  
**Status:** Complete with known broker registration issue noted
