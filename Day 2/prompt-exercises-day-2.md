# Day 2 Training Prompts and Responses

## Contents
- [1. Manager Email for Delayed Access Request](#1-manager-email-for-delayed-access-request)
- [2. Intune Briefing for Finance Manager](#2-intune-briefing-for-finance-manager)
- [3. New Win11 Laptop Running Slowly](#3-new-win11-laptop-running-slowly)
- [4. Triage Summary for VPN Connected but No Internal Access](#4-triage-summary-for-vpn-connected-but-no-internal-access)
- [5. Closure Note for Intune BitLocker Compliance Incident](#5-closure-note-for-intune-bitlocker-compliance-incident)
- [6. Win11 Login Failure Likely Causes](#6-win11-login-failure-likely-causes)

## 1. Manager Email for Delayed Access Request

### Prompt Used
```text
You are a DWP service-desk analyst. A user is asking for help drafting an email to their manager to explain that a system access request has been delayed due to pending approval from IT. Write the email on the user's behalf. State the delay, the reason, and the expected next step
```

### Generated Response
Subject: Update on System Access Request

Hi [Manager Name],

I wanted to let you know that my system access request has been delayed because it is still pending approval from IT.

At the moment, no further action is needed from my side while the approval is being processed. The expected next step is for IT to complete the approval, after which the access should be provisioned and I will be updated accordingly.

I will let you know as soon as I receive confirmation.

Kind regards,
[Your Name]

---

## 2. Intune Briefing for Finance Manager

### Prompt Used
```text
You are a DWP service-desk analyst. A Finance user's manager wants a quick briefing on Microsoft Intune before a device migration rollout. Explain what Intune is, what it is used for in a managed Windows 11 environment, and how it relates to device compliance and app deployment. Structure the answer with these sections: Summary; Key capabilities; Relevance to this migration
```

### Generated Response
## Summary
Microsoft Intune is Microsoft's cloud-based endpoint management platform. In a managed Windows 11 environment, it is used to control how corporate devices are configured, secured, and supported without relying solely on manual setup. It gives IT a central way to manage device policies, security settings, compliance status, and application delivery.

## Key capabilities
- Enrols and manages Windows 11 devices from a central admin platform.
- Applies security and configuration policies such as encryption, password rules, update settings, and device restrictions.
- Monitors compliance against organisational standards, for example whether BitLocker, antivirus, and required security settings are in place.
- Deploys and updates corporate applications such as Microsoft 365 apps, VPN clients, and approved business software.
- Supports remote actions such as sync, restart, wipe, retire, and troubleshooting tasks.
- Provides reporting so IT can see device health, policy status, and deployment progress.

## Relevance to this migration
For this migration, Intune is the management layer that helps ensure newly issued Windows 11 devices are built to the required standard. It is relevant in two main ways:

- Device compliance: Intune checks whether each migrated device meets required security controls before it is trusted for company access.
- App deployment: Intune is commonly used to push the required business applications and configuration profiles to the new device so users receive a consistent setup.

In practical terms, this means Intune helps standardise the migration outcome, reduce manual setup effort, and confirm that migrated devices are both usable and compliant.

---

## 3. New Win11 Laptop Running Slowly

### Prompt Used
```text
You are a DWP service-desk analyst. A user has just received a new Win11 laptop as part of the FinBridge migration and is calling to say it is running slowly. List the five most likely causes of poor performance on a newly deployed Win11 laptop in a managed environment, most probable first. For each cause give: the likely reason, and the single fastest check
```

### Generated Response
1. Post-build updates and background installs
   Likely reason: The device is still completing Windows updates, driver installs, Intune policy processing, or required application deployments in the background after first sign-in.
   Single fastest check: Open Task Manager and check whether Windows Update, Microsoft Intune Management Extension, or installers are actively consuming CPU, disk, or network.

2. OneDrive, Outlook, or profile data still syncing
   Likely reason: A newly deployed device often feels slow while OneDrive, Outlook, Teams, and Windows Search are indexing and syncing large volumes of user data.
   Single fastest check: Check the OneDrive client and Outlook status to see whether sync is still running or marked as processing.

3. Endpoint security scan running
   Likely reason: Microsoft Defender or another managed security tool may be running an initial full scan or post-deployment policy scan, which can temporarily increase CPU and disk usage.
   Single fastest check: Open Task Manager or Windows Security and confirm whether an antivirus scan is currently active.

4. Poor network connection during setup
   Likely reason: If the device has weak Wi-Fi or is on VPN while pulling apps, policies, and cloud data, performance can appear slow even when the device itself is healthy.
   Single fastest check: Check Wi-Fi signal quality and whether the slowdown improves when the device is on a stable office or home connection.

5. Resource or storage constraint on the device
   Likely reason: Available RAM or disk may already be under pressure from the standard build, large sync activity, or an unexpectedly small amount of free space.
   Single fastest check: Check Task Manager Performance and File Explorer free space to see whether memory, disk, or storage is close to saturation.

---

## 4. Triage Summary for VPN Connected but No Internal Access

### Prompt Used
```text
You are a DWP service-desk analyst. A Finance user on Windows 11 reports their VPN connects successfully but no internal resources are reachable after a Win11 upgrade last week. The device is managed via Intune. Produce a structured triage summary with these sections: Summary; Impact; Known facts; Missing info to gather; likely category; First diagnostic step. Do not invent facts — mark anything uncertain as "to confirm". Return only the triage summary
```

### Generated Response
## Summary
Finance user reports VPN connects successfully but internal resources are not reachable following a Windows 11 upgrade last week.

## Impact
- Who is affected: one Finance user (to confirm)
- Scope: currently one reported device/user (to confirm whether broader)
- Business effect: loss of access to internal resources over VPN; business urgency to confirm

## Known facts
- User is in Finance
- Device is running Windows 11
- VPN reports as connected
- Internal resources are not reachable
- Windows 11 upgrade took place last week
- Device is managed via Intune

## Missing info to gather
- Which internal resources fail: file shares, intranet, line-of-business apps, RDP, or all internal services (to confirm)
- Whether access fails by hostname only, by IP address only, or both (to confirm)
- Whether the issue occurs on all networks or only the current connection (to confirm)
- Whether other users upgraded to Windows 11 are seeing the same VPN symptom (to confirm)
- Whether DNS, routes, or adapter settings change when VPN connects (to confirm)
- Whether any recent Intune policy, VPN client, or security configuration changes were applied (to confirm)

## likely category
Remote access/networking issue, most likely VPN routing, DNS resolution, or post-upgrade client/policy behaviour (to confirm)

## First diagnostic step
With the VPN connected, test access to one known internal resource by both hostname and IP address to quickly distinguish likely DNS/name-resolution failure from broader VPN routing or connectivity failure.

---

## 5. Closure Note for Intune BitLocker Compliance Incident

### Prompt Used
```text
You are a DWP service-desk analyst. A device was flagged as non-compliant in Intune due to BitLocker not being enabled, and remediation has since been applied to restore compliance. Write a closure note documenting this incident for the ticket record. Structure it with these sections: Issue; Root cause; Remediation applied; Current status. Do not invent facts — mark anything uncertain as "to confirm". Return only the closure note
```

### Generated Response
## Issue
Device was flagged in Intune as non-compliant because BitLocker was not enabled.

## Root cause
BitLocker encryption was not active on the device at the time compliance was evaluated. The underlying reason BitLocker was not enabled is to confirm.

## Remediation applied
Remediation was applied to restore the required BitLocker/compliance state. Exact remediation steps used are to confirm.

## Current status
Device now reports as compliant in Intune following remediation. Ongoing monitoring requirement, if any, is to confirm.

---

## 6. Win11 Login Failure Likely Causes

### Prompt Used
```text
You are a DWP service-desk analyst. A user reports they are unable to log in to their Win11 device. List the five most likely causes of this login failure in a managed environment, most probable first. For each cause give: the likely reason, and the single fastest check. Do not invent facts — mark anything uncertain as "to confirm". No preamble — return only the numbered list
```

### Generated Response
1. Incorrect password, keyboard layout issue, or cached credential mismatch
   Likely reason: The user may be entering the wrong password, using an unexpected keyboard layout, or the device may still be using older cached credentials. Exact trigger is to confirm.
   Single fastest check: Confirm the username format and test whether the password works in another Microsoft 365 or company sign-in service.

2. Account locked, disabled, or password recently changed
   Likely reason: The account may be locked out, disabled, or out of sync after a recent password change. Exact account state is to confirm.
   Single fastest check: Check the account status in the identity admin portal or ask whether the user can sign in successfully to webmail or another corporate service.

3. Network not available for a required first or refreshed sign-in
   Likely reason: If the device needs live authentication rather than cached sign-in, lack of internet or corporate network connectivity can prevent login. Whether this is a first sign-in or token refresh scenario is to confirm.
   Single fastest check: Confirm the device has a working internet connection from the sign-in screen.

4. Device trust, compliance, or sign-in policy issue
   Likely reason: A managed device can fail sign-in if device registration, trust, or a required policy state is not healthy. The exact policy condition is to confirm.
   Single fastest check: Check in the management or identity console whether the device is present, healthy, and compliant.

5. Local profile corruption or recent update issue
   Likely reason: The local Windows profile or sign-in components may be damaged following an update, failed shutdown, or disk issue. Exact cause is to confirm.
   Single fastest check: Test whether another known-good account can log in to the same device.
