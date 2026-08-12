# Phased Intune Deployment Plan: FinBridge Connect v3.1

Date: 2026-08-12  
Deadline (3 weeks): 2026-09-02  
Target: 10,000 Win11 endpoints

## 1. RING STRUCTURE

Ring design is built to protect service continuity while meeting the Finance deadline and validating the known 4GB RAM risk early.

- Ring 1 (Pilot)
- Size: 300 devices (3.0% of fleet)
- Duration: 3 calendar days deployment + 2 calendar days observation (5 days total)
- Include:
  - IT engineering and service desk staff
  - Cross-functional users from Operations, HR, and a small Finance subset (up to 25 users)
  - Dedicated 4GB RAM canary subgroup: 60 devices (20% of Ring 1)
- Purpose:
  - Validate install behavior, detection rule accuracy, and uninstall reliability at low scale
  - Expose any performance issues on lower-spec hardware before wider rollout
  - Confirm telemetry and reporting quality in Intune
- Intune assignment group type:
  - Microsoft Entra ID security group (Assigned/static) for strict inclusion control
  - Separate static subgroup for 4GB RAM canary devices

- Ring 2 (Early)
- Size: 2,200 devices total (22% of fleet), including remaining Finance users
- Duration: 5 calendar days deployment + 2 calendar days observation (7 days total)
- Include:
  - All Finance users not already in Ring 1 (target total Finance = 500 by end of week 1)
  - Business-critical but support-ready departments
  - Additional 4GB RAM cohort to reach at least 300 total at-risk devices across Ring 1 and Ring 2
- Purpose:
  - Validate deployment and user experience at meaningful operational scale
  - Confirm no department-specific workflow regressions
  - Complete Finance rollout within week 1 under controlled conditions
- Intune assignment group type:
  - Combination model:
    - Assigned/static group for Finance (deadline-critical)
    - Dynamic device group for the remainder of Ring 2 (rules based on department and managed device attributes)

- Ring 3 (Broad)
- Size: 7,500 devices (remaining 75% of fleet)
- Duration: 7 calendar days staged waves + 2 calendar days final observation (9 days total)
- Include:
  - All remaining eligible Win11 endpoints
  - Exclude known problem devices via temporary exclusion group if needed
- Purpose:
  - Complete enterprise rollout before 2026-09-02
  - Maintain control via staged daily wave increments while monitoring health
- Intune assignment group type:
  - Dynamic device groups with wave segmentation
  - Optional static exclusion group for incident containment

Planned timeline summary:
- Week 1 (days 1-7): Ring 1 complete and Ring 2 starts; Finance completed by day 7
- Week 2 (days 8-14): Ring 2 observation complete and Ring 3 begins
- Week 3 (days 15-21): Ring 3 complete with final stabilization before deadline

## 2. ADVANCE CRITERIA

All criteria are evaluated from Intune app install reports, device status, and service desk incident records during the defined monitoring window.

Ring 1 -> Ring 2 (promotion gate)
- Install success rate: >= 97.0% within 72 hours of assignment in Ring 1
- Error rate threshold: <= 2.0% failed install status in Intune over the same 72-hour window
- User-reported issues threshold: <= 1.5 tickets per 100 deployed users per 24 hours, sustained across a 48-hour monitoring period
- Monitoring period: minimum 48 consecutive hours after at least 90% of Ring 1 devices report final install status

Ring 2 -> Ring 3 (promotion gate)
- Install success rate: >= 98.5% within 96 hours of assignment in Ring 2
- Error rate threshold: <= 1.0% failed install status in Intune over the same 96-hour window
- User-reported issues threshold: <= 1.0 tickets per 100 deployed users per 24 hours, sustained for 72 hours
- Monitoring period: minimum 72 consecutive hours after at least 90% of Ring 2 devices report final install status

Hold condition (pause without full rollback)
- Trigger:
  - If detection-rule-related false negatives are between 1.0% and 3.0% of targeted devices in the current ring within 24 hours, pause next-ring assignments while remediation is applied.
- Example:
  - Intune shows app installed on 2.2% of devices but reports "Not Installed" because the registry version string path changed from v3.0 to v3.1 key location. Action: pause ring advancement, correct detection rule, re-sync, and re-evaluate same ring for 24 hours.

## 3. ROLLBACK TRIGGERS

Rollback means halting v3.1 expansion and reverting affected scope to v3.0 assignments.

Install failure rate trigger (automatic halt)
- Condition:
  - >= 8.0% install failures in any active ring over any rolling 12-hour window once at least 200 devices in that ring have attempted install
- Decision authority:
  - Primary: Endpoint Engineering On-Call Lead
  - Secondary approver: Service Owner (Digital Workplace)
- Decision window:
  - 60 minutes from threshold breach alert
- Exact Intune action:
  - Remove Required assignment of FinBridge Connect v3.1 from active ring group(s)
  - Add same ring group(s) to FinBridge Connect v3.0 Required assignment
  - Keep v3.1 assignment only on pilot troubleshooting subgroup if explicitly approved

Application crash rate trigger (rollback consideration)
- Condition:
  - >= 3.0% of deployed users in the ring report repeat app crashes (2 or more crashes per user) within rolling 24 hours, validated by endpoint telemetry and service desk correlation
- Decision authority:
  - Endpoint Engineering Lead + App Owner joint decision
- Decision window:
  - 4 hours from confirmed threshold
- Exact Intune action:
  - Freeze further v3.1 assignments immediately
  - If confirmed as v3.1 defect, switch Required assignment for impacted ring(s) from v3.1 to v3.0
  - Maintain exclusion group for devices requiring forensic capture before downgrade

Business-critical failure trigger (immediate rollback)
- Condition:
  - Any verified inability for Finance users to complete payment batch submission in FinBridge Connect for >= 30 consecutive minutes during business hours, attributable to v3.1
- Decision authority:
  - Incident Commander (Major Incident) can invoke immediate rollback without waiting for percentage thresholds
- Decision window:
  - Immediate execution (target <= 30 minutes to action)
- Exact Intune action:
  - Remove Finance group from v3.1 Required assignment
  - Assign Finance group to v3.0 Required assignment with highest assignment priority
  - Trigger Company Portal sync communication and force policy sync advisory to Finance endpoints

4GB RAM device failure trigger (ring isolation)
- Condition:
  - >= 12.0% install failure rate OR >= 10.0% severe performance incident rate on the 4GB RAM cohort in a rolling 24-hour period
- Decision authority:
  - Endpoint Engineering Lead
- Decision window:
  - 2 hours from threshold confirmation
- Exact Intune action:
  - Move all identified 4GB RAM devices to a dedicated exclusion group for v3.1
  - Assign excluded group to v3.0 Required
  - Continue v3.1 rollout for non-4GB devices if global thresholds remain healthy

## 4. FINANCE DEADLINE RESOLUTION

Option A - Compress pilot to fit Finance into Ring 2 by end of week 1
- Minimum safe pilot duration:
  - 72 hours active deployment + 24 hours observation (4 days total minimum)
- Risk introduced:
  - Reduced time to detect slower-burn reliability issues (for example, day-3 memory/performance degradation)
- Compensating control:
  - Increase 4GB RAM representation in Ring 1 canary to 20% and enforce twice-daily checkpoint reviews (09:00 and 16:00) before Ring 2 expansion

Option B - Finance as separate priority Ring 0 before main pilot
- Ring 0 structure:
  - 100 Finance power users (20% of Finance population), static assignment group, deploy on day 1
  - 48-hour monitoring window before expanding to remaining 400 Finance users
- Ring 0 advance conditions:
  - >= 98% success within 48 hours
  - <= 1% failed installs
  - <= 1 ticket per 100 users per 24 hours
  - No business-critical payment workflow defect
- Ring 0 rollback plan:
  - If failure threshold breached, remove Ring 0 Finance group from v3.1 Required and reassign to v3.0 Required within 30 minutes
  - Pause all non-Finance rings until root cause decision

Recommendation: Option A
- Reason 1: Lowest operational complexity; avoids creating an extra pre-pilot governance stream and duplicate approval cadence.
- Reason 2: Still satisfies Finance end-of-week-1 target by starting Ring 2 immediately after a tightly monitored minimum-safe pilot.
- Reason 3: Risk from compressed pilot is manageable with explicit compensating controls (larger 4GB canary mix, twice-daily gate reviews, and hard rollback triggers already defined above).

Execution decision:
- Proceed with Ring 1 on day 1, evaluate gates at hour 96, and begin Ring 2 (including remaining Finance users) no later than day 5 to complete Finance by day 7.
