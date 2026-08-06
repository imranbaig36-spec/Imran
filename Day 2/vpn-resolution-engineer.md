# VPN Connectivity Issue — Engineer-to-Engineer Resolution Note

## Root Cause Analysis

Win11 upgrade removed legacy VPN client binaries and service registry entries. Intune VPN client deployment policy contained detection-rule gap: the rule failed to trigger remediation when legacy client was detected as removed. Result: new modern VPN client was not auto-deployed post-upgrade.

## Resolution Steps

1. **Registry Cleanup**: Manually removed stale VPN entries under HKLM\SOFTWARE\[Vendor], including service configuration keys and cached authentication tokens.

2. **Intune Device Sync**: Force-triggered full device sync via Settings > Accounts > Access work or school > Sync.

3. **Client Deployment**: Confirmed new VPN client (modern Intune-managed version) deployed successfully.

4. **Policy Application**: Applied split-tunnel configuration policy via Intune mobile device management (MDM) compliance baseline.

5. **Verification**: Tested and confirmed connectivity to all internal subnets:
   - Remote Desktop Protocol (RDP) to domain controller
   - SMB file share access
   - Office 365 authentication
   - Internal DNS resolution
   - All 10.0.0.0/8 internal routes responding

## Data Impact

No data loss. Session logs reviewed and clean.

## Preventive Actions (To Prevent Recurrence)

1. Update Intune VPN deployment detection rule to include condition: "IF legacy client binary not found AND new client not found, THEN deploy new client."

2. Modify Win11 deployment task sequence to include pre-upgrade scan phase that detects legacy VPN client and queues new client for deployment during upgrade process.

3. Update OS upgrade runbook to explicitly document this scenario and include mitigation steps.

4. Consider staging new client in pre-upgrade image to eliminate this dependency gap.
