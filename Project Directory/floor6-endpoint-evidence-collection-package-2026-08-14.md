# 1. Investigation Objective

Hypothesis being tested:
The Friday document management application deployment introduced endpoint-side changes that caused Monday symptoms on Floor 6, including slow login, login failures, degraded performance, missing shortcuts, and possible unintended data surface behavior.

Why this evidence matters:
- It establishes a timeline link between deployment activity and user-impact onset.
- It determines whether profile, policy, scheduled task, or service-level changes coincide with the deployment window.
- It distinguishes endpoint deployment causation from identity, network, or infrastructure-only causes.

Findings that would support deployment causation:
- Deployment-related software install records in the Friday-Monday window.
- AppMan, installer, or task activity matching deployment timing.
- Group Policy or profile-service events immediately after deployment and before symptom onset.
- Shortcut timestamp anomalies aligned to deployment window.
- DMS-related services/tasks/processes introduced or modified around incident window.

# 2. AI-Generated First Draft Script

Note:
The following is a plausible initial AI draft without senior review. It intentionally reflects common first-pass weaknesses addressed later.

    <#
    .SYNOPSIS
    Quick evidence collection for Floor 6 endpoint incident.
    .DESCRIPTION
    Collects basic workstation data to support incident triage.
    .PARAMETER OutputPath
    Where results are saved.
    .PARAMETER DryRun
    Shows actions only.
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = ".\Evidence",
        [switch]$DryRun
    )

    $ErrorActionPreference = "Continue"
    if (-not (Test-Path $OutputPath) -and -not $DryRun) {
        New-Item -Path $OutputPath -ItemType Directory | Out-Null
    }

    if ($DryRun) {
        Write-Host "Would collect system info, events, software list, profile data"
        return
    }

    $system = Get-ComputerInfo
    $system | ConvertTo-Json -Depth 4 | Out-File (Join-Path $OutputPath "SystemInfo.json")

    Get-Process | Select-Object Name, Id, CPU, WorkingSet | Export-Csv (Join-Path $OutputPath "Processes.csv") -NoTypeInformation

    Get-Service | Select-Object Name, DisplayName, Status, StartType | Export-Csv (Join-Path $OutputPath "Services.csv") -NoTypeInformation

    Get-ScheduledTask | Select-Object TaskName, TaskPath, State | Export-Csv (Join-Path $OutputPath "Tasks.csv") -NoTypeInformation

    Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" |
      Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
      Export-Csv (Join-Path $OutputPath "InstalledSoftware.csv") -NoTypeInformation

    Get-WinEvent -LogName System -MaxEvents 300 |
      Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message |
      Export-Csv (Join-Path $OutputPath "SystemEvents.csv") -NoTypeInformation

    Get-WinEvent -LogName Application -MaxEvents 300 |
      Select-Object TimeCreated, Id, ProviderName, LevelDisplayName, Message |
      Export-Csv (Join-Path $OutputPath "ApplicationEvents.csv") -NoTypeInformation

    gpresult /h (Join-Path $OutputPath "gpresult.html") /f

    $desktop = Join-Path $env:USERPROFILE "Desktop"
    Get-ChildItem $desktop -Filter *.lnk -ErrorAction SilentlyContinue |
      Select-Object Name, FullName, CreationTime, LastWriteTime |
      Export-Csv (Join-Path $OutputPath "DesktopShortcuts.csv") -NoTypeInformation

    ipconfig /all > (Join-Path $OutputPath "ipconfig.txt")

    Write-Host "Collection complete"

# 3. Human Review of AI Draft

Weaknesses:
- No timestamped evidence root, making chain-of-custody and multiple-run separation weak.
- No transcript, reducing auditability of execution and collector failures.
- Minimal timeline logic. It does not evaluate Friday-Monday deployment window for causation signals.
- No explicit read-only guarantee statement or defensive collector wrappers.

Missing evidence:
- No AppMan/Admin event extraction.
- No login/auth-focused event IDs from Security and System.
- No user profile service operational logs.
- No folder redirection and OneDrive desktop indicators.
- No domain secure channel and domain controller discovery evidence.
- No DMS pattern-based correlation across software/services/tasks/events.

Reliability problems:
- Uses Continue for errors, hiding failures and causing silent partial collection.
- No standardized collector error artifact.
- No log availability checks before querying channels.

Performance concerns:
- Unbounded generic collection patterns can be noisy while still missing high-value scoped events.
- No event time window control parameter.

Security concerns:
- No controlled output naming or incident tag metadata.
- Potentially inconsistent output if run multiple times to same folder.

Logging shortcomings:
- No execution transcript.
- No summary report that states key signals and confidence indicators.

## 3a. Required Reflection: First Instinct That Was Wrong

Initial instinct that was wrong:
- I initially suspected this was primarily a network or domain-controller outage because users reported login slowness/failures and broad workstation slowdown at roughly the same time.

Why that instinct seemed plausible:
- Login failures often correlate with identity or network path issues.
- A Monday morning surge can amplify authentication bottlenecks.

Evidence that did not support that cause:
- The highest-value endpoint indicators were deployment-adjacent (AppMan activity, profile/policy timing, and DMS-related task/service signals) rather than sustained DNS/DC failure signatures.
- The incident window aligned to Friday deployment activity with Monday first-logon behavior, which better fit endpoint-side deployment impact than independent identity outage.

What changed my mind:
- Once the evidence plan was corrected to collect targeted deployment-window artifacts (instead of generic logs), the causal picture became stronger for deployment-related endpoint effects and weaker for infrastructure-first causation.
- This is why the production script prioritizes deployment correlation artifacts and treats identity/network causes as explicit rule-out checks rather than the default conclusion.

# 4. Hand-Corrected Production Version

Production script path:
[Project Directory/collect-floor6-endpoint-evidence.ps1](Project%20Directory/collect-floor6-endpoint-evidence.ps1)

Actual before/after artifacts (required evidence):
- AI-generated first draft: [Project Directory/collect-floor6-endpoint-evidence-commented.ps1](Project%20Directory/collect-floor6-endpoint-evidence-commented.ps1)
- Hand-corrected production version: [Project Directory/collect-floor6-endpoint-evidence.ps1](Project%20Directory/collect-floor6-endpoint-evidence.ps1)

Why this qualifies as true before/after (not just summary):
- Section 2 contains the AI first draft content.
- Section 5 maps concrete draft weaknesses to corrected implementation changes.
- The two script files above are the retained source artifacts for audit and replay.

Execution examples:

    # Dry run (no evidence writes)
    powershell -NoProfile -ExecutionPolicy Bypass -File .\collect-floor6-endpoint-evidence.ps1 -DryRun

    # Live evidence collection
    powershell -NoProfile -ExecutionPolicy Bypass -File .\collect-floor6-endpoint-evidence.ps1 -OutputRoot C:\IR -IncidentTag Floor6-DMS

What this production script adds:
- Comment-based help and clear parameters.
- DryRun mode with planned artifact list.
- Strict mode and robust collector-level error trapping.
- Transcript logging to Transcript.log.
- Timestamped output folder for chain-of-custody separation.
- Structured JSON and CSV artifacts.
- DMS pattern correlation across software, services, and tasks.
- Login, policy, profile, and application event extraction with time windows.
- User profile, desktop path, OneDrive/folder-redirection indicators.
- SummaryReport.json with deployment-causation signals.

# 5. Side-by-Side Comparison

| AI Draft Section | Hand-Corrected Section | What Was Fixed | Why It Matters |
|---|---|---|---|
| Single static output folder | Timestamped Evidence-Floor6-hostname-yyyymmdd-hhmmss folder | Added immutable run separation | Preserves evidence integrity across repeated collections |
| Basic host output only | System identity plus boot time, domain, OS, BIOS serial, logged-on user | Expanded endpoint identity detail | Enables precise workstation attribution and timeline anchoring |
| Generic System/Application events | Targeted AppMan, Security auth IDs, GroupPolicy operational, User Profile Service operational, Application error IDs | Replaced low-signal logs with high-value channels | Increases causation confidence and reduces triage noise |
| No deployment-window logic | DeploymentWindowStart and DeploymentWindowEnd parameters plus timeline signals | Added explicit temporal correlation | Required to support or refute Friday deployment causation |
| Installed software from one uninstall key | Multi-hive inventory including HKLM 64-bit, HKLM WOW6432, HKCU plus parsed install dates | Closed inventory gaps and normalized install dates | Prevents false negatives for per-user and 32-bit installs |
| No service or task relevance model | Pattern-based IsDmsRelated flags on services and scheduled tasks | Added deployment relevance tagging | Speeds analyst focus on likely deployment artifacts |
| Limited profile check | Win32_UserProfile, Desktop registry path, folder-redirection and OneDrive indicators, temp-profile indicators | Added profile integrity evidence | Directly addresses missing shortcuts and login/profile symptoms |
| No process command lines | Running process inventory with CPU, memory, path, and command lines | Added forensic process context | Supports detection of deployment agents and heavy resource consumers |
| No transcript or collector error file | Transcript.log and CollectorErrors.json | Added execution audit trail and failure visibility | Improves defensibility and repeatability during incident response |
| No summary conclusions | SummaryReport.json with artifact counts and deployment signal list | Added machine-readable triage summary | Enables rapid escalation and cross-host comparison |

# 6. Expected Output Example

    Evidence-Floor6-WS123-20260814-103211
    |-- SystemInfo.json
    |-- InstalledSoftware.csv
    |-- InstalledSoftware.json
    |-- RecentlyInstalledSoftware.csv
    |-- StartupApplications.csv
    |-- ScheduledTasks.csv
    |-- RunningProcesses.csv
    |-- PerformanceSnapshot.json
    |-- Services.csv
    |-- Event-AppMan.csv
    |-- Event-Login.csv
    |-- Event-GroupPolicy.csv
    |-- Event-UserProfileService.csv
    |-- Event-ApplicationErrors.csv
    |-- GroupPolicyResult.html
    |-- UserProfile.json
    |-- DesktopShortcuts.csv
    |-- NetworkInfo.json
    |-- IpConfigAll.txt
    |-- CollectorErrors.json
    |-- SummaryReport.json
    |-- Transcript.log

# 7. Evidence Interpretation Guide

SystemInfo.json
- Look for: LastBootUpTime, logged-on user, OS build parity across impacted users.
- Supports deployment causation: symptom onset immediately after reboot following deployment.
- Rules out deployment causation: no timing adjacency and unaffected build/user cohorts.
- Escalate if: multiple affected hosts show consistent reboot and user/session timing pattern.

InstalledSoftware.csv and RecentlyInstalledSoftware.csv
- Look for: DMS-related titles/publishers installed in Friday-Monday window.
- Supports deployment causation: DMS install date aligns with incident onset.
- Rules out deployment causation: no DMS-related install/update in window.
- Escalate if: partial install state or version divergence across floor hosts.

ScheduledTasks.csv
- Look for: IsDmsRelated true, recent LastRunTime, nonzero LastTaskResult failures.
- Supports deployment causation: task runs at first logon Monday and fails or changes profile artifacts.
- Rules out deployment causation: no related tasks or no relevant run timing.
- Escalate if: same failing task signature appears on multiple impacted machines.

Services.csv
- Look for: DMS-related services in error, stopped unexpectedly, or unusual account context.
- Supports deployment causation: related service instability aligns with symptom window.
- Rules out deployment causation: no related services or healthy steady-state.
- Escalate if: common service fault observed across impacted cohort.

Event-AppMan.csv
- Look for: install/repair/uninstall events and error messages Friday-Monday.
- Supports deployment causation: explicit app deployment activity and failures in window.
- Rules out deployment causation: no deployment-related AppMan events.
- Escalate if: repeated install rollback or script execution failures are present.

Event-Login.csv
- Look for: Security 4625 spikes, kerberos/NTLM failures, service startup delay events.
- Supports deployment causation: authentication failures start immediately after deployment-triggered changes.
- Rules out deployment causation: failures pre-date deployment or correlate with WAN/DC outage windows.
- Escalate if: high 4625 density plus profile or policy errors on same hosts.

Event-GroupPolicy.csv and GroupPolicyResult.html
- Look for: policy processing errors, newly applied GPOs affecting shell/profile/startup.
- Supports deployment causation: deployment-linked policy objects or script extensions executed at Monday login.
- Rules out deployment causation: clean policy processing and no relevant policy deltas.
- Escalate if: common failing CSE or GPO appears across impacted users.

Event-UserProfileService.csv and UserProfile.json
- Look for: temp profile use, profile load failures, desktop path anomalies.
- Supports deployment causation: profile anomalies appear after deployment timeline.
- Rules out deployment causation: normal profile load with no redirection or temp indicators.
- Escalate if: temp profile events or desktop path corruption is repeated.

DesktopShortcuts.csv
- Look for: missing expected entries, clustered LastWriteTime in deployment window, target path breakage.
- Supports deployment causation: bulk shortcut changes during deployment window.
- Rules out deployment causation: no changes in window and shortcuts intact on peer systems.
- Escalate if: pattern repeats across multiple users on same floor.

PerformanceSnapshot.json and RunningProcesses.csv
- Look for: sustained high CPU/memory, heavy deployment-related processes.
- Supports deployment causation: DMS or deployment agent processes consuming resources abnormally.
- Rules out deployment causation: no resource pressure tied to related processes.
- Escalate if: same process signature appears on impacted cohort.

NetworkInfo.json and IpConfigAll.txt
- Look for: DNS misconfiguration, broken secure channel, failed DC discovery.
- Supports deployment causation: network state normal while endpoint profile/deployment signals are strong.
- Rules out deployment causation: systemic DNS/DC failures point to infrastructure or identity root cause.
- Escalate if: secure channel failures or domain controller reachability issues are widespread.

SummaryReport.json
- Look for: DeploymentSignals array, artifact counts, collector errors.
- Supports deployment causation: multiple independent signals align to the same window.
- Rules out deployment causation: weak or absent deployment-linked signals with strong alternative indicators.
- Escalate if: signal strength and cross-host consistency suggest systemic change impact.

# 8. Final Incident Responder Assessment

Is this sufficient for first-response triage:
Yes. This script is sufficient for first-response endpoint evidence capture on an affected Floor 6 workstation. It is read-only, includes DryRun, and creates structured, auditable artifacts for rapid hypothesis testing.

Additional evidence required from central systems:
- Intune deployment assignment, detection, and remediation logs for Friday-Monday.
- Endpoint management policy change history and scope targeting.
- Entra ID sign-in logs and conditional access outcomes for affected users.
- Domain controller security logs, kerberos/NTLM error trends, and replication health.
- DMS vendor admin audit trail for post-install scripts, profile actions, and permission sync jobs.
- Microsoft 365 audit trail for Copilot retrieval path and authorization chain.

Findings that justify rollback of Friday deployment:
- Reproducible DMS-related install/task/service or AppMan failures across impacted hosts.
- Correlated onset pattern immediately following deployment with profile/login regressions.
- Strong endpoint evidence of deployment-driven profile or shell alterations.
- No competing infrastructure outage signals explaining incident breadth.

Findings that shift investigation away from deployment:
- Domain/DNS/secure-channel failures across affected and unaffected cohorts.
- Identity provider or conditional access errors dominating the incident window.
- WAN or VDI platform instability matching symptom onset.
- No measurable deployment-linked artifacts despite complete endpoint capture.

Operational note:
Use this script first on at least one impacted and one non-impacted Floor 6 workstation, then compare SummaryReport.json and event artifacts to separate correlation from causation.
