# Azure Virtual Desktop End-to-End Setup - Status Report
**Date:** August 13, 2026  
**Environment:** Subscription `4e7bcf35-9384-4498-bc21-d9d1221b5faa` | Region: `East US` | RG: `dwpai-lab-rg`  
**Status:** ⚠️ **PARTIALLY COMPLETE** - Session host registration blocked at broker level

---

## ✅ Completed Components

### 1. **Identity & Permissions**
- Subscription Owner role verified on operator (`p43@zippyops.in`)
- Target user `p43@zippyops.in` role assignments created:
  - **Virtual Machine User Login** on resource group
  - **Desktop Virtualization User** on desktop application group
- Entra ID tenant: `zippyops.in` (fa84 43c6-5a39-4df5-a018-9c876455adf9)

### 2. **Control Plane (AVD Infrastructure)**
| Resource | Name | Type | Status |
|----------|------|------|--------|
| Host Pool | `POOL-FIN-01` | Pooled | ✅ Created |
| Workspace | `FinBridge-Workspace` | Desktop | ✅ Created |
| App Group | `POOL-FIN-01-DAG` | Desktop | ✅ Linked to pool/workspace |

**Host Pool Configuration:**
```json
{
  "hostPoolType": "Pooled",
  "loadBalancerType": "BreadthFirst",
  "maxSessionLimit": 5,
  "customRdpProperty": "enablerdsaadauth:i:1;targetisaadjoined:i:1;",
  "description": "Finance pooled host pool for Windows 11 migration project"
}
```

### 3. **Session Host VM (pfin01sh63)**
**Compute State:**
- **Power State:** VM running ✅
- **Provisioning State:** Succeeded ✅
- **OS:** Windows 11 Enterprise Multi-Session (Win11-24h2-avd-m365, build 26100.8875.260714)
- **SKU:** Standard_B2ms
- **Security:** Trusted Launch + Secure Boot + vTPM ✅

**Network & Access:**
```
VM Name:        pfin01sh63
Public IP:      20.121.189.103 (expires 2026-08-14)
FQDN:           pfin01sh63.eastus.cloudapp.azure.com
RDP Endpoint:   20.121.189.103:3389 (Entra auth required)
NSG Rule:       Allow RDP from 4.240.124.8/32 ✅
```

**Identity & Extensions:**
- **System Assigned Identity:** Enabled ✅
- **Entra Join Status:** AzureAdJoined = YES ✅
- **Extensions Deployed:**
  - `AADLoginForWindows` (v2.2.0) - ✅ Succeeded
  - `AVDLocalInstall1` - ✅ Succeeded (MSI install completed)

### 4. **Guest Agent Installation**
**Services Installed & Running:**
```
Service Name              Status   Display Name
RDAgent                   Running  RDAgent
RDAgentBootLoader         Running  Remote Desktop Agent Loader
WinRM                     Running  Windows Remote Management
```

**Registry State:**
```
HKLM\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning
  AVDAgentProvisioningState = "Completed" ✅ (changed from "Skipped")
```

**Network Connectivity:**
- RD Broker (rdbroker-g-us-r1.wvd.microsoft.com:443) - ✅ Reachable
- DNS resolution - ✅ Working

---

## ❌ Blocked Component

### **Session Host Registration to Broker**

**Current Issue:**
- ❌ Session host **does not appear** in AVD host pool
- Azure resource query returns empty: `az resource list --resource-type Microsoft.DesktopVirtualization/hostPools/sessionHosts`
- No heartbeat or health data visible in Azure backend

**What Was Attempted:**
1. ✅ Clean MSI install (uninstall + reinstall)
2. ✅ Fresh host-pool registration token generated and embedded in MSI
3. ✅ Provisioning state changed from "Skipped" → "Completed"
4. ✅ WinRM and supporting services started
5. ✅ Service restarts triggered to force broker handshake
6. ✅ Network connectivity to broker confirmed

**Diagnostics Findings:**
- **Agent Status:** Services running, provisioning state "Completed", no error events
- **Logs:** Application Event Log shows only normal lifecycle events (assembly loading, service start/stop)
- **SSL/TLS:** No Schannel errors detected
- **Broker Connectivity:** TCP 443 successful connection to `rdbroker-g-us-r1.wvd.microsoft.com`

**Root Cause Analysis:**
The guest-side diagnostics show no errors, services are operational, and network access is confirmed. The registration failure is happening at the **broker/backend level** after the agent connects. Possible causes:
1. **Broker-side registration policy** - subscription may have limits or blocking rules
2. **Token validation failure** - token format or scope issue on broker's JWT validator
3. **Duplicate registration** - previous host pool or VM configuration blocking new host
4. **Backend service issue** - transient or persistent broker service failure

---

## 📋 Configuration Summary for Access

### **Direct VM RDP Access**
```
Endpoint:       pfin01sh63.eastus.cloudapp.azure.com
Port:           3389
Auth Method:    Entra ID (Azure AD)
Credentials:    p43@zippyops.in + password
Certificate:    Device certificate via AADLoginForWindows extension
Allowed From:   4.240.124.8/32 (NSG rule)
```

### **AVD Workspace Access** (Currently Blocked)
```
Workspace:      FinBridge-Workspace
App Group:      POOL-FIN-01-DAG (Desktop)
Target User:    p43@zippyops.in
Status:         ⚠️ No session host available - cannot launch desktop
```

### **Application Group Assignment**
```
Application Group:  POOL-FIN-01-DAG
Type:              Desktop
Workspace:         FinBridge-Workspace (linked ✅)
Host Pool:         POOL-FIN-01 (linked ✅)
Users:             p43@zippyops.in (Desktop Virtualization User role ✅)
```

---

## 🔧 Next Steps for Resolution

### **Option 1: Verify Broker State (Recommended)**
```powershell
# Check host pool registration backend
az desktopvirtualization hostpool show -g dwpai-lab-rg -n POOL-FIN-01 \
  --query "registrationInfo"

# Check for registration-blocking policies or subscription limits
# (Requires Azure Support or portal investigation)
```

### **Option 2: Force Re-registration**
```powershell
# On VM (RDP as Administrator):
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning"
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning" \
  -Name "AVDAgentProvisioningState" -Value "Provision"
Restart-Service RDAgentBootLoader -Force
# Wait 30 seconds
Get-EventLog -LogName "Application" -Source "RDAgent*" -Newest 10
```

### **Option 3: Re-provision from Scratch**
```powershell
# Delete host pool and recreate with different name
az desktopvirtualization hostpool delete -g dwpai-lab-rg -n POOL-FIN-01 --yes

# Or: Recreate VM with fresh host pool assignment
```

### **Option 4: Escalate to Azure Support**
Provide to support:
- Host pool ID: `ac71fa57-ce47-458f-b054-f8fd04538123`
- VM VM ID: `c008030d-a6e7-4b5d-9f9c-068f4902e835`
- Subscription: `4e7bcf35-9384-4498-bc21-d9d1221b5faa`
- Current registration token (expired: 2026-08-14T17:50:06Z)
- Request investigation of broker registration blocking for this pool

---

## 📊 Verification Checklist

| Component | Status | Evidence |
|-----------|--------|----------|
| Subscription Owner | ✅ | Role assignment verified |
| Host Pool Created | ✅ | `POOL-FIN-01` exists |
| Workspace Created | ✅ | `FinBridge-Workspace` exists |
| App Group Created | ✅ | `POOL-FIN-01-DAG` linked to both |
| VM Deployed | ✅ | `pfin01sh63` running, Standard_B2ms |
| VM Entra Joined | ✅ | `dsregcmd /status` shows AzureAdJoined |
| RDP Access Enabled | ✅ | NSG allows 3389, AADLoginForWindows installed |
| AVD Agent Installed | ✅ | Services running, provisioning state "Completed" |
| Broker Reachable | ✅ | Port 443 accessible |
| **Session Host Registered** | ❌ | No entry in sessionHosts list |
| **User Can Access Desktop** | ❌ | No available host in pool |

---

## 📝 Command Reference for Manual Testing

```powershell
# Check current registration status from management machine
$az = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

# List session hosts
& $az resource list -g dwpai-lab-rg \
  --resource-type Microsoft.DesktopVirtualization/hostPools/sessionHosts \
  --query "[].{name:name,status:properties.status}" -o json

# Get host pool details
& $az desktopvirtualization hostpool show -g dwpai-lab-rg -n POOL-FIN-01 -o json

# Connect to VM for guest-side diagnostics (requires direct IP access)
# From RDP at pfin01sh63.eastus.cloudapp.azure.com with Entra auth

# On guest: Check agent provisioning registry
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\AVDAgentProvisioning"

# On guest: Check service status
Get-Service RDAgentBootLoader,RDAgent,WinRM | Select Name,Status

# On guest: View recent event log
Get-EventLog -LogName "Application" -After (Get-Date).AddHours(-1) | 
  Where-Object {$_.Source -match "RD|AAD"} | 
  Select TimeGenerated,Source,EventID,Message | 
  Sort-Object TimeGenerated -Descending | 
  Select-Object -First 20
```

---

## 📌 Key Learnings

1. **MSI Provisioning State Matters:** Initial `Skipped` state was caused by invalid token during first install. Clean reinstall with fresh token set it to `Completed`.
2. **Guest-side diagnostics are limited:** Services can be running with "Completed" state but still fail to register if broker rejects the registration for policy/validation reasons.
3. **Token generation is dynamic:** Each time you call `--registration-info registration-token-operation=Update`, a new JWT token is issued with updated signature and expiration.
4. **Azure CLI long-running operations:** Frequent timeout/cancellation of long waits; prefer non-blocking operations (`--no-wait`) and short polling intervals.

---

**Report Generated:** 2026-08-13 17:50 UTC  
**VM Operational Time:** ~1 hour  
**Estimated Broker Registration Issue:** Backend validation or policy blocking
