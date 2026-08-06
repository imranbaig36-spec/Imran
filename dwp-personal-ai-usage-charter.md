# Personal AI Usage Charter for a DWP Desktop/Endpoint Engineer

**Version:** 1.0  
**Date:** 2026-08-03

## Purpose
I use public AI assistants to improve speed and quality in engineering work without compromising security, privacy, service reliability, or DWP policy obligations. This charter defines what I will and will not use public AI for, and how I will handle data and verification.

## Scope
This applies to day-to-day desktop and endpoint engineering activities, including Windows device management, packaging, scripting, troubleshooting, patching, configuration baselining, and user support documentation.

## 1) Appropriate DWP Tasks for Public LLM Help
I may use public AI for low-risk, non-sensitive assistance where no DWP confidential data is disclosed.

- Script drafting from generic requirements: PowerShell skeletons, log parsing helpers, file/registry checks, detection/remediation templates with placeholder values only.
- Troubleshooting method design: Step-by-step investigation plans for common endpoint issues using anonymized symptoms.
- Command and syntax support: Cmdlet usage reminders, regex patterns, JSON/YAML structures, packaging logic, and deployment patterns at a generic level.
- Documentation improvement: Rewriting runbooks, creating checklists, and simplifying technical language from non-sensitive source text.
- Test case generation: Edge-case lists and validation checklists for scripts, deployment, and baseline changes.
- Learning and comparison: Best-practice explanations for endpoint hardening concepts, patch sequencing, rollback planning, and monitoring signals.

**Condition for all acceptable use:** Prompts must be abstracted and sanitized so they cannot identify a person, device, tenant, environment, or control weakness.

## 2) Tasks Not Appropriate for Public LLM Help
I will not use public AI for any activity that includes sensitive data, privileged details, or decisions requiring internal authority.

- Sharing any end-user, claimant, staff, or device-identifiable data.
- Sharing internal architecture, network topology, hostnames, domain details, security tooling configuration, vulnerability data, incident details, or unpatched exposure information.
- Sharing production logs, event traces, tickets, screenshots, exports, or config files that contain real identifiers or operational detail.
- Asking AI to generate or review live credentials, authentication artifacts, secrets, encryption material, or access control mappings.
- Using AI output as sole authority for security decisions, production change approvals, firewall/policy exceptions, incident remediation, or compliance interpretations.
- Uploading proprietary code/scripts/configuration unless explicitly approved by policy and data classification rules.
- Using AI to bypass standard change, CAB, peer review, or security assurance processes.

**If uncertain whether content is safe for public AI, treat it as not safe and do not submit it.**

## 3) Data-Handling Rule for End-User PII and Credentials
**Non-negotiable rule: no PII, no credentials, no secrets in public AI prompts. Ever.**

- Never paste names, emails, phone numbers, usernames, employee IDs, national identifiers, addresses, dates of birth, ticket references tied to people, device serials tied to users, session tokens, API keys, passwords, hashes, private keys, certificates, or recovery codes.
- Redact before prompting by replacing real values with neutral placeholders such as `USER_A`, `DEVICE_X`, `TENANT_Y`, `APP_Z`, `DATE_YYYYMMDD`.
- Minimize context and share only the smallest snippet needed to ask the technical question.
- Assume persistence: treat any public AI input as externally stored and potentially reviewable.
- Keep secrets in approved tools only (credential managers, secure vaults, approved internal platforms), never in prompts, chat history, or screenshots.

**If a prompt needs real PII or credentials to make sense, do not use a public AI assistant for that task.**

## 4) Personal Generate-Then-Verify Rule for Scripts and System Changes
I use AI output as a draft, not as a deployable answer.

- Generate: Request draft script/procedure with placeholders and explicit assumptions.
- Review: Read line-by-line for unsafe commands, destructive actions, privilege misuse, weak error handling, and hidden side effects.
- Validate technically: Run lint/syntax checks and confirm compatibility with target Windows version and tooling stack.
- Test safely: Execute in isolated lab/sandbox/test device first; never first run in production.
- Peer check: Obtain colleague review for medium/high-impact changes.
- Control change: Follow standard change process with rollback plan, success criteria, and monitoring checks.
- Deploy gradually: Pilot ring first, then staged rollout.
- Verify outcomes: Confirm expected behavior, no regressions, and security baseline intact.
- Record: Document AI assistance used, what changed, how it was tested, and final evidence.

**Hard stop rule:** I do not run AI-generated scripts in production unchanged or untested.

## Accountability Statement
I remain fully accountable for all technical decisions, scripts, and changes I implement. AI can accelerate drafting and learning, but responsibility for safety, legality, privacy, and service quality remains mine.
