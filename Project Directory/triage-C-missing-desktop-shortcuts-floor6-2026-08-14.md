# Triage C: Missing Desktop Shortcuts (Floor 6)

**Date:** 2026-08-14  
**Incident Type:** User Environment / Profile  
**Priority:** Medium

## What Was Reported
Some users report that desktop shortcuts have disappeared.

## Why This Matters
Lower severity than security/login outage, but may indicate profile issues, policy failures, or side effects of recent changes.

## What To Check First (In Order, And Why)
1. **Confirm symptom type**: missing files vs hidden/unpinned icons.  
Why: separates UI-state issue from actual profile/data-path issue.
2. **Validate profile health**: temp profile events, FSLogix/roaming profile attach, redirected desktop paths.  
Why: profile fallback frequently causes apparent shortcut loss.
3. **Check GPO/Intune shortcut deployment** status and errors.  
Why: policy failures can remove or fail to restore shortcuts.
4. **Check OneDrive KFM/sync status** where desktop is redirected.  
Why: sync conflicts can move/hide desktop items.

## Immediate Actions (Right Now)
- Restore critical shortcuts via standard script/policy refresh.
- Capture logs from one representative affected endpoint for RCA.
- Communicate that confirmed data loss is not indicated at this stage.

## What To Tell Non-Technical Stakeholders
“Some users are missing desktop shortcuts. We are restoring required app access first and verifying whether profile or policy sync issues caused the change.”

## Owner Handoff
- Technical Owner: Endpoint Engineering
- Supporting Teams: EUC, Profile/VDI Admin, Service Desk Floor Support
