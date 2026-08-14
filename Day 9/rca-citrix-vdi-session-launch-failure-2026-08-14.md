# RCA - Citrix VDI Session Launch Failure (FinBridge Pool-02)

Date: 2026-08-14  
Prepared by: DWP Operations

## Executive Summary

A major launch failure affected FinBridge-VDI-Pool-02, impacting 22 of 30 users. Evidence shows a severe registration deficit in Pool-02 and a stopped Citrix Broker Service on `dc-vdi-02`, while `dc-vdi-01` and Pool-01 remained healthy. The most supported incident mechanism is controller service outage on `dc-vdi-02` leading to mass unregistration and broker inability to allocate machines.

## Scope and Impact

- Affected pool: FinBridge-VDI-Pool-02
- User impact: 22/30 users affected
- Unaffected pool: FinBridge-VDI-Pool-01
- Business effect: Users in impacted pool unable to launch VDI sessions; partial service continuity maintained via unaffected pool.

## Supporting Evidence

1. Broker log evidence
- `[08:58:34] Broker: Timeout waiting for machine registration response (30000ms exceeded)`
- `[08:58:34] Session launch FAILED: error 1030 'No machines available in the desktop group'`

2. Catalog registration evidence
- Pool-02: 25 provisioned, 3 registered, 22 unregistered, maintenance mode 0
- Pool-01: 20 provisioned, 19 registered, 1 unregistered

3. Affected machine sample evidence (Pool-02)
- VDI-P02-014 and VDI-P02-017 failed registration attempts
- Error path: unable to contact Delivery Controller `dc-vdi-02.finbridge.local:80`
- Network symptom: `connection refused`

4. Controller health evidence
- `dc-vdi-02`: Citrix Broker Service STOPPED
- `dc-vdi-02`: Last known running yesterday 23:40
- `dc-vdi-02`: Windows Update installed today 00:15 with reboot required flag set
- `dc-vdi-01`: Citrix Broker Service RUNNING, uptime 14 days

## Timeline (from provided data)

- Yesterday 23:40: `dc-vdi-02` Broker Service last known running
- Today 00:15: Windows Update installed on `dc-vdi-02`; reboot-required state present
- 06:15:22: VDI-P02-014 registration attempt failed
- 06:16:01: VDI-P02-017 registration attempt failed
- 08:58:03: User session launch requested in Pool-02
- 08:58:34: Broker registration wait timed out (30000ms)
- 08:58:34: Launch failure with error 1030 and message no machines available

## Analysis

- The failure pattern is pool-specific (Pool-02) rather than site-wide.
- The registration collapse in Pool-02 (3/25 registered) maps directly to allocation failure.
- The unregistered machine error path and controller health both align to `dc-vdi-02` as the failing control point.
- Stable controller and registration in Pool-01 form a strong internal control comparison.

## 5 Whys

1. Why did users fail to launch sessions in Pool-02?
- Because broker could not allocate available registered machines and returned 1030 with no machines available.

2. Why were machines not available?
- Because most Pool-02 machines were unregistered (22 of 25).

3. Why were Pool-02 machines unregistered?
- Because registration attempts to `dc-vdi-02:80` failed with connection refused.

4. Why was `dc-vdi-02` refusing registration path?
- Because Citrix Broker Service on `dc-vdi-02` was stopped.

5. Why did service remain stopped long enough to cause impact?
- Post-update reboot-required/maintenance completion controls did not ensure controller service health and registration baseline verification before returning to business-as-usual.

## Final Root Cause Statement

Primary root cause: Citrix Broker Service outage on `dc-vdi-02` led to widespread Pool-02 VDA unregistration, resulting in broker session launch failures due to insufficient registered capacity.

Contributing factors:
- Reboot-required condition after update with host not rebooted.
- Lack of proactive alerting/guardrails for controller service-down and pool registration degradation.

## Confirmed/Planned Remediation

Immediate recovery actions:
1. Restore Broker Service on `dc-vdi-02`.
2. Reboot `dc-vdi-02` in controlled window if required for service stability.
3. Validate service startup and stability.
4. Validate Pool-02 registration recovery and user launch success.

## Verification of Resolution

Success criteria:
- `dc-vdi-02` Broker Service running and stable.
- Pool-02 registered count recovers from 3 toward expected normal baseline.
- New Pool-02 user launches complete without timeout/1030 occurrences.
- Pool-01 remains stable through recovery window.

## Preventive Actions

1. Monitoring and alerting
- Critical alert when Citrix Broker Service stops on any Delivery Controller.
- Alert on pool registration ratio degradation beyond defined threshold.

2. Patch/change process hardening
- Mandatory post-patch reboot completion validation for controllers.
- Mandatory post-maintenance health gate:
  - Broker service status check
  - Registration baseline check
  - Synthetic user launch check

3. Configuration resilience
- Audit and standardize VDA controller failover configuration across pools.
- Periodic failover simulation to verify cross-controller registration behavior.

4. Operational readiness
- Documented runbook for controller service recovery and fast registration restoration.
- Quarterly DR-style exercise for control-plane service outage response.

## Notes on Error Code Interpretation

- This RCA relies on the literal log text for error 1030: `No machines available in the desktop group`.
- No additional vendor semantic expansion of numeric code meaning is asserted beyond the provided evidence text.
