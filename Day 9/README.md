# Azure Virtual Desktop - Complete Provisioning Guide

**Version:** 1.0  
**Date:** August 13, 2026  
**Status:** Production Ready

---

## Quick Start

### Automated Provisioning (Recommended)

```powershell
cd "c:\Users\labuser\Documents\AI Training\Day 9"

.\09-Complete-Provisioning.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -SubscriptionId "4e7bcf35-9384-4498-bc21-d9d1221b5faa" `
  -Region "eastus" `
  -HostPoolName "POOL-FIN-01" `
  -WorkspaceName "FinBridge-Workspace" `
  -VMName "pfin01sh63" `
  -UserPrincipalName "p43@zippyops.in"
```

### Step-by-Step Manual Provisioning

If you prefer granular control or need to debug individual steps:

```powershell
cd "c:\Users\labuser\Documents\AI Training\Day 9"

# 1. Validate environment
.\01-Pre-Flight-Checks.ps1 `
  -SubscriptionId "4e7bcf35-9384-4498-bc21-d9d1221b5faa" `
  -ResourceGroup "dwpai-lab-rg" `
  -Region "eastus"

# 2. Create AVD control plane (host pool, workspace, app group)
.\02-Create-ControlPlane.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" `
  -WorkspaceName "FinBridge-Workspace" `
  -AppGroupName "POOL-FIN-01-DAG"

# 3. Create session host VM
.\03-Create-SessionHost-VM.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -VMName "pfin01sh63" `
  -VNetName "dwp-p43-winVNET" `
  -SubnetName "dwp-p43-winSubnet"

# 4. Configure Entra ID join
.\04-Configure-Entra-Join.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -VMName "pfin01sh63"

# 5. Install AVD guest agent
.\05-Install-AVD-Agent.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -VMName "pfin01sh63" `
  -HostPoolName "POOL-FIN-01"

# 6. Assign user RBAC roles
.\06-Assign-User-Roles.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -UserPrincipalName "p43@zippyops.in" `
  -HostPoolName "POOL-FIN-01" `
  -AppGroupName "POOL-FIN-01-DAG"

# 7. Verify complete registration
.\07-Verify-Registration.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" `
  -VMName "pfin01sh63" `
  -UserPrincipalName "p43@zippyops.in"
```

---

## Files in This Directory

### Core Scripts

| Script | Purpose | Type | Approx. Time |
|--------|---------|------|--------------|
| [01-Pre-Flight-Checks.ps1](#script-01) | Validate prerequisites | Validation | 2 min |
| [02-Create-ControlPlane.ps1](#script-02) | Create host pool, workspace, app group | Provisioning | 3 min |
| [03-Create-SessionHost-VM.ps1](#script-03) | Create Windows 11 multi-session VM | Provisioning | 8 min |
| [04-Configure-Entra-Join.ps1](#script-04) | Deploy Entra ID authentication | Provisioning | 5 min |
| [05-Install-AVD-Agent.ps1](#script-05) | Install RDAgent and RDAgentBootLoader | Provisioning | 5 min |
| [06-Assign-User-Roles.ps1](#script-06) | Grant RBAC roles to user | Provisioning | 2 min |
| [07-Verify-Registration.ps1](#script-07) | Comprehensive health check | Validation | 3 min |
| [08-Reinstall-AVD-Agent.ps1](#script-08) | Recover from provisioning failures | Recovery | 5 min |
| [09-Complete-Provisioning.ps1](#script-09) | Orchestrate all steps with flow control | Orchestration | ~30 min |

### Documentation

| File | Purpose |
|------|---------|
| [AVD-PROVISIONING-GUIDE.md](#guide) | Complete reference guide |
| [TROUBLESHOOTING-GUIDE.md](#troubleshooting) | Diagnostic and recovery procedures |
| [README.md](#readme) | This file |

---

## Detailed Script Reference

### Script 01: Pre-Flight Checks

**Purpose:** Validate environment before starting provisioning

**What It Checks:**
- ✅ Azure CLI is installed (v2.x)
- ✅ Subscription is accessible
- ✅ Operator has Owner role on subscription
- ✅ Resource group exists
- ✅ desktopvirtualization extension available
- ✅ Network connectivity to AVD broker

**Usage:**
```powershell
.\01-Pre-Flight-Checks.ps1 `
  -SubscriptionId "4e7bcf35-9384-4498-bc21-d9d1221b5faa" `
  -ResourceGroup "dwpai-lab-rg" `
  -Region "eastus"
```

**Output Example:**
```
✅ Azure CLI v2.59.0 found
✅ Subscription accessible
✅ You have Owner role on subscription
✅ Resource group 'dwpai-lab-rg' exists
✅ desktopvirtualization extension available
✅ Broker reachable: rdbroker-g-us-r1.wvd.microsoft.com:443
```

**What to Do If It Fails:**
- Missing CLI: Download from https://aka.ms/cli
- Wrong role: Ask subscription admin for Owner assignment
- No RG: Create it first with `az group create`

---

### Script 02: Create Control Plane

**Purpose:** Create AVD infrastructure (host pool, workspace, app group, registration token)

**What It Creates:**
- Host pool: POOL-FIN-01 (Pooled, BreadthFirst, max 5 sessions)
- Workspace: FinBridge-Workspace
- App group: POOL-FIN-01-DAG (Desktop type)
- Registration token: For session host enrollment

**Usage:**
```powershell
.\02-Create-ControlPlane.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" `
  -WorkspaceName "FinBridge-Workspace" `
  -AppGroupName "POOL-FIN-01-DAG"
```

**Saved Files:**
- `registration-token.txt` - Token for session host (24-hour expiry)

**Customization:**
```powershell
# Change these if needed (inside script):
$rdpProperties = "enablerdsaadauth:i:1;targetisaadjoined:i:1;"  # For Entra auth
$maxSessions = 5                                                 # Max per session
$loadBalancerType = "BreadthFirst"                              # or Depth First
```

---

### Script 03: Create Session Host VM

**Purpose:** Provision Windows 11 multi-session VM with security hardening

**What It Creates:**
- VM: Standard_B2ms, Windows 11 Enterprise Multi-Session
- Public IP: Static, with DNS name and RDP rule
- NIC: Attached to existing VNet/Subnet
- NSG: With RDP inbound rule
- Security: Trusted Launch (SecureBoot, vTPM)

**Usage:**
```powershell
.\03-Create-SessionHost-VM.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -VMName "pfin01sh63" `
  -VNetName "dwp-p43-winVNET" `
  -SubnetName "dwp-p43-winSubnet"
```

**Default Configuration:**
- Image: Microsoft.WindowsDesktop/office-365/win11-24h2-avd-m365 (latest)
- Size: Standard_B2ms (2 vCPU, 4 GB RAM)
- OS Disk: 128 GB, Premium SSD
- License: Windows_Client (use existing license)

**Customization:**
```powershell
# Change these (inside script):
$vmSize = "Standard_B2ms"        # or Standard_B4ms, D2s_v3
$imageId = "MicrosoftWindowsDesktop/office-365/win11-24h2-avd-m365"  # or multi-session
$osDiskSizeGb = 128             # Increase if needed
```

**Generated Resources:**
```
VM: pfin01sh63
Public IP: 20.121.189.103 (example)
FQDN: pfin01sh63.eastus.cloudapp.azure.com
NIC: pfin01sh63-nic
NSG: pfin01sh63-nsg
```

---

### Script 04: Configure Entra Join

**Purpose:** Deploy AADLoginForWindows extension for Entra ID authentication

**What It Does:**
- Starts VM if not running
- Deploys AADLoginForWindows v2.2 extension
- Waits for deployment to complete
- Enables Entra ID login at RDP screen

**Usage:**
```powershell
.\04-Configure-Entra-Join.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -VMName "pfin01sh63"
```

**Result:**
```
✅ Extension deployed successfully
✅ Entra ID login enabled
✅ User can now login with p43@zippyops.in at RDP screen
```

**Verification:**
```powershell
# RDP to VM and run:
dsregcmd /status
# Look for: AzureAdJoined : YES
```

---

### Script 05: Install AVD Agent

**Purpose:** Install RDAgent and RDAgentBootLoader with registration token

**What It Does:**
- Fetches registration token from host pool
- Downloads MSI packages to C:\AVDInstall\ (if not present)
- Uninstalls previous versions (if any)
- Installs RDAgent with token embedded in command line
- Installs RDAgentBootLoader
- Verifies services are running
- Checks provisioning state registry

**Usage:**
```powershell
.\05-Install-AVD-Agent.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -VMName "pfin01sh63" `
  -HostPoolName "POOL-FIN-01"
```

**Expected Output:**
```
✅ RDAgent installed successfully
✅ RDAgentBootLoader installed successfully
✅ Both services running
✅ Provisioning state: Completed
```

**If Fails:**
- May show provisioning state "Skipped" if token is invalid/expired
- Run 08-Reinstall-AVD-Agent.ps1 to recover
- Check C:\Windows\Temp\avd-*.log on VM for details

---

### Script 06: Assign User Roles

**Purpose:** Grant RBAC roles for VM access and AVD desktop access

**What It Does:**
- Resolves user UPN to Entra ID object ID
- Assigns "Virtual Machine User Login" at resource group level (for RDP)
- Assigns "Desktop Virtualization User" at app group level (for AVD desktop)

**Usage:**
```powershell
.\06-Assign-User-Roles.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -UserPrincipalName "p43@zippyops.in" `
  -HostPoolName "POOL-FIN-01" `
  -AppGroupName "POOL-FIN-01-DAG"
```

**Expected Output:**
```
✅ User p43@zippyops.in resolved
✅ Virtual Machine User Login assigned (RG scope)
✅ Desktop Virtualization User assigned (App Group scope)
```

**Verification:**
```powershell
az role assignment list --assignee "p43@zippyops.in" --resource-group "dwpai-lab-rg"
# Should show both roles
```

---

### Script 07: Verify Registration

**Purpose:** Comprehensive health check and troubleshooting diagnostics

**What It Checks:**
1. **Host Pool** - Exists, token active
2. **VM State** - Running, provisioned
3. **Extensions** - AADLoginForWindows deployed
4. **Entra Join** - VM Entra AD joined
5. **AVD Services** - RDAgent and RDAgentBootLoader running
6. **Provisioning State** - Registry value = "Completed"
7. **Session Host Registration** - Host appears in broker
8. **Network** - Broker connectivity confirmed

**Usage:**
```powershell
.\07-Verify-Registration.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" `
  -VMName "pfin01sh63" `
  -UserPrincipalName "p43@zippyops.in"
```

**Interpretation:**
- All ✅: Provisioning complete, ready for user access
- Mix of ✅/⚠️: Most items OK, review warnings
- Any ❌: Issue detected, see TROUBLESHOOTING-GUIDE.md

**Known Issue:**
- Check 7 (Session Host Registration) may return empty if broker hasn't ingested registration yet
- This is a backend timing issue, not a guest-side problem
- Services will be "Completed" and functional even if broker listing is delayed
- See TROUBLESHOOTING-GUIDE.md for recovery options

---

### Script 08: Reinstall AVD Agent

**Purpose:** Recover from provisioning state "Skipped" by regenerating token and reinstalling

**When to Use:**
- Provisioning state is "Skipped"
- Session host won't register after 08-Install-AVD-Agent.ps1
- Token expired during initial installation

**What It Does:**
1. Deletes current registration token
2. Generates fresh token with 24-hour expiry
3. Uninstalls both MSI packages
4. Reinstalls with fresh token
5. Restarts services
6. Verifies state = "Completed"

**Usage:**
```powershell
.\08-Reinstall-AVD-Agent.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" `
  -VMName "pfin01sh63"
```

**Expected Outcome:**
```
✅ New registration token generated
✅ Previous versions uninstalled
✅ Reinstallation complete
✅ Provisioning state: Completed
```

**If Still Fails:**
- Check broker connectivity (see TROUBLESHOOTING-GUIDE.md)
- Escalate to Azure Support with host pool ID + VM ID

---

### Script 09: Complete Provisioning

**Purpose:** Orchestrate all 7 provisioning steps with error handling and flow control

**When to Use:**
- First-time provisioning on new infrastructure
- Reproducing exact configuration
- Automated deployment pipelines

**What It Does:**
1. Runs scripts 01-07 in sequence
2. Pauses if any step fails
3. Offers retry/skip/abort options
4. Provides final summary
5. Lists next steps for manual validation

**Usage:**
```powershell
.\09-Complete-Provisioning.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -SubscriptionId "4e7bcf35-9384-4498-bc21-d9d1221b5faa" `
  -Region "eastus" `
  -HostPoolName "POOL-FIN-01" `
  -WorkspaceName "FinBridge-Workspace" `
  -VMName "pfin01sh63" `
  -UserPrincipalName "p43@zippyops.in"
```

**Interactive Flow:**
```
STEP 1/7: Pre-Flight Checks
[runs 01-Pre-Flight-Checks.ps1]
✅ Step 1 COMPLETED

STEP 2/7: Create Control Plane
[runs 02-Create-ControlPlane.ps1]
✅ Step 2 COMPLETED

... (continues through all 7 steps)

[If failure occurs]
Fix the issue and select action:
  [R] Retry this step
  [S] Skip to next step
  [E] Exit provisioning
Action (R/S/E): R

[Final summary shows pass/warn/fail counts]
```

**Total Provisioning Time:** ~30-35 minutes (depending on resources and network)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Subscription                       │
│  4e7bcf35-9384-4498-bc21-d9d1221b5faa                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                ┌──────────────────────────────┐
                │   Resource Group             │
                │   dwpai-lab-rg (East US)     │
                └──────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
    ┌──────────┐      ┌───────────────┐      ┌──────────────┐
    │  Host    │      │    VM         │      │   Entra ID   │
    │  Pool    │      │   pfin01sh63  │      │  (External)  │
    │POOL-FIN  │      │   Win11 B2ms  │      │  zippyops.in │
    │   -01    │      │   w/Trusted   │      │              │
    └──────────┘      │    Launch     │      └──────────────┘
        │             │   + Entra     │              ▲
        │             │    Join       │              │
        │             │   + RDAgent   │              │
        │             └───────────────┘              │
        │                     │                      │
        ▼                     ▼                      │
    ┌───────────────────────────────────────────────┼──────┐
    │          Workspace + App Group                │      │
    │   FinBridge-Workspace                         │ Auth │
    │   POOL-FIN-01-DAG                             │      │
    │   (Desktop Application)                       │      │
    └───────────────────────────────────────────────┼──────┘
                                                     │
                                    p43@zippyops.in ◄─┘
                                    - VM RDP access
                                    - AVD desktop access
```

**Data Flow:**
1. User launches AVD client with Entra ID credentials
2. AVD broker authenticates against Entra ID
3. Broker queries session hosts in POOL-FIN-01
4. Session host VM accepts connections via AADLoginForWindows extension
5. User authenticates with p43@zippyops.in via Entra ID
6. User granted desktop session (BreadthFirst load balancing)

**Network Connectivity:**
- VM → Broker: TCP 443 to rdbroker-g-us-r1.wvd.microsoft.com (mandatory)
- User → RDP Port: TCP 3389 to 20.121.189.103 (NSG controlled)
- VM → Entra ID: HTTPS for token validation (implicit)

---

## Configuration Reference

### Host Pool Settings (Script 02)

```powershell
$hostPoolType = "Pooled"              # Multi-user shared
$loadBalancerType = "BreadthFirst"    # Balance new sessions across hosts
$maxSessionLimit = 5                  # Max sessions per user/VM
$rdpProperties = @{
    "enablerdsaadauth:i:1"            # Enable Entra ID auth
    "targetisaadjoined:i:1"           # Target is Entra joined
}
```

### VM Configuration (Script 03)

```powershell
$vmSize = "Standard_B2ms"             # 2 vCPU, 4 GB RAM, $60-70/month
$imagePublisher = "MicrosoftWindowsDesktop"
$imageOffer = "office-365"
$imageSku = "win11-24h2-avd-m365"     # Win11 + Microsoft 365 apps
$osType = "Windows"
$trustedLaunchEnabled = $true         # SecureBoot + vTPM
$licenseType = "Windows_Client"       # BYOL (requires license)
```

### Agent Configuration (Script 05)

```powershell
$rdAgentMsi = "Microsoft.RDInfra.RDAgent.Installer-x64-1.0.15008.300.msi"
$bootloaderMsi = "Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi"
$registrationTokenExpiry = 24          # Hours
```

### RBAC Roles Assigned (Script 06)

| Role | Scope | Purpose |
|------|-------|---------|
| Virtual Machine User Login | Resource Group | RDP access to VM |
| Desktop Virtualization User | App Group | AVD desktop session |

---

## Troubleshooting Quick Reference

| Symptom | Probable Cause | Action |
|---------|----------------|--------|
| "Cannot connect" at RDP | VM not running, IP not assigned, NSG blocking | Run 07-Verify-Registration.ps1, check networking |
| "Skipped" provisioning state | Invalid token during install | Run 08-Reinstall-AVD-Agent.ps1 |
| Session host won't register | Backend broker issue (not guest-side) | See TROUBLESHOOTING-GUIDE.md section on registration |
| Cannot auth with Entra ID | Extension not deployed or failed | Re-run 04-Configure-Entra-Join.ps1 |
| User can't access desktop | No roles, no registered hosts, app group issue | Run 07-Verify-Registration.ps1 with user UPN |
| Event log shows errors | Service dependency (WinRM), network issue | Check services on VM, run 07-Verify-Registration.ps1 |

For detailed troubleshooting, see **TROUBLESHOOTING-GUIDE.md**

---

## Security Considerations

### VM-Level Security
- ✅ Trusted Launch (SecureBoot + vTPM)
- ✅ Managed identity (system-assigned)
- ✅ No public RDP inbound except from specific IPs (via NSG)
- ✅ OS disk encrypted at rest (Azure managed)

### Access Control
- ✅ RBAC-based (Virtual Machine User Login, Desktop Virtualization User)
- ✅ Entra ID authentication mandatory
- ✅ No local accounts used for session access

### Network Security
- ✅ VNet isolation (existing VNet/Subnet)
- ✅ NSG rules restrict inbound traffic
- ✅ All agent-to-broker communication encrypted (TLS 1.2+)

### Compliance
- ✅ Audit logs: Enable Azure Monitor for host pool
- ✅ Session recording: Configure AVD Insights + Log Analytics
- ✅ Data residency: Resources stay in specified region (East US)

**Hardening Options Not Included:**
- Private endpoint for host pool (adds cost/complexity)
- Managed environment (Azure Virtual Desktop for Gov Cloud)
- Custom image with additional security patches
- DLP policies (separate Microsoft Purview configuration)

---

## Cost Estimation

**Monthly Costs (Approximate, East US):**

| Resource | Size/Type | Quantity | Cost/Month |
|----------|-----------|----------|-----------|
| VM Compute | Standard_B2ms | 1 | $65 |
| OS Disk | 128 GB Premium SSD | 1 | $12 |
| Public IP | Static | 1 | $3 |
| Outbound Data Transfer | ~10 GB/month | 1 | $1 |
| AVD Licensing | Per-user (pooled) | 1 | $20 |
| **Total** | | | **~$100/month** |

**Cost Optimization:**
- Use Dev/Test license (50% discount if MSDN subscription)
- Switch to Depth First load balancing if fewer users
- Scale down VM size for lower utilization
- Deallocate VM when not in use (saves compute costs)
- Use Reserved Instances for 1-year commitment (-30%)

**Optional Add-Ons:**
- Log Analytics (diagnostics): +$15-50/month
- Azure Backup: +$5-20/month
- Managed disks auto-shutdown: ~-$20/month

---

## Validation Checklist

After running complete provisioning:

- [ ] Host pool created with correct name, type, LB, max sessions
- [ ] Workspace created and linked to app group
- [ ] VM created and running
- [ ] Public IP assigned and reachable
- [ ] RDP accessible from management machine
- [ ] Entra join verified via `dsregcmd /status`
- [ ] RDAgent service running
- [ ] RDAgentBootLoader service running
- [ ] Provisioning state registry = "Completed"
- [ ] User RBAC roles assigned
- [ ] User can authenticate with Entra ID at RDP
- [ ] User appears in AVD web client
- [ ] User can launch desktop session
- [ ] Session host appears in broker (may take 5-10 min)

**Validation Script:**
```powershell
.\07-Verify-Registration.ps1 `
  -ResourceGroup "dwpai-lab-rg" `
  -HostPoolName "POOL-FIN-01" `
  -VMName "pfin01sh63" `
  -UserPrincipalName "p43@zippyops.in"
```

---

## Cleanup (When Done)

**To remove all provisioned resources:**

```powershell
# Option 1: Delete entire resource group
az group delete --name "dwpai-lab-rg" --yes

# Option 2: Delete individual resources
az desktopvirtualization workspace delete -g "dwpai-lab-rg" -n "FinBridge-Workspace" --yes
az desktopvirtualization hostpool delete -g "dwpai-lab-rg" -n "POOL-FIN-01" --yes
az vm delete -g "dwpai-lab-rg" -n "pfin01sh63" --yes
az network nic delete -g "dwpai-lab-rg" -n "pfin01sh63-nic" --yes
az network nsg delete -g "dwpai-lab-rg" -n "pfin01sh63-nsg" --yes
az network public-ip delete -g "dwpai-lab-rg" -n "pfin01sh63-pip" --yes
```

**Estimated Cleanup Time:** 5-10 minutes

**Data Retention:**
- AVD control plane deleted immediately
- VM disks deleted (delete-on-termination enabled)
- Public IP released
- No backups retained by default

---

## Support & Resources

### Official Microsoft Documentation
- [Azure Virtual Desktop Docs](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [AVD Troubleshooting Guide](https://learn.microsoft.com/en-us/azure/virtual-desktop/troubleshoot-set-up-issues)
- [RDAgent Release Notes](https://learn.microsoft.com/en-us/azure/virtual-desktop/whats-new-agent)

### Community Resources
- [Azure Virtual Desktop Tech Community](https://techcommunity.microsoft.com/t5/azure-virtual-desktop/ct-p/AzureVirtualDesktopCommunity)
- [AVD GitHub Issues](https://github.com/microsoft/avd/issues)

### Scripts & Tools
- This provisioning guide: [c:\Users\labuser\Documents\AI Training\Day 9\]
- Troubleshooting guide: [TROUBLESHOOTING-GUIDE.md](TROUBLESHOOTING-GUIDE.md)
- Full reference: [AVD-PROVISIONING-GUIDE.md](AVD-PROVISIONING-GUIDE.md)

### Reporting Issues
Include in support ticket:
- Subscription ID
- Host pool name and ID
- VM name and ID
- Error message (from Event Log or script output)
- Registration token (if not expired)
- Steps already attempted

---

## Change Log

### Version 1.0 (August 13, 2026)
- ✅ Initial release
- ✅ 9 provisioning/verification scripts
- ✅ Comprehensive troubleshooting guide
- ✅ Complete reference documentation

### Known Limitations
- **Broker Registration Delay:** Session host may not appear in broker for 5-10 minutes after "Completed" state is reached. This is a known Azure backend timing issue, not a guest-side problem. Services will be fully functional.
- **Single VM Scope:** Scripts provision one VM per host pool. For multi-VM scenarios, repeat scripts with different VM names.
- **MSI Package Caching:** Scripts assume MSI packages exist locally at C:\AVDInstall\. First run may download them; subsequent runs will use cached copies.
- **Token Expiry:** Registration tokens expire after 24 hours. Regenerate if installing to new VM after token expiry.

---

**Document Version:** 1.0  
**Created:** August 13, 2026  
**Status:** Ready for Production Deployment  
**Maintained By:** Azure Infrastructure Team  
**Last Updated:** 2026-08-13  
**Next Review:** Upon completion of pilot  

For questions or updates, contact the Azure Infrastructure team.
