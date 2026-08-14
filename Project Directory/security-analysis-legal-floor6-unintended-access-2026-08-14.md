# Security/Data-Governance Analysis: Unintended Client Matter Access
**Incident**: Paralegal (Legal Floor 6) surfaced client matter via Copilot she states she never had access to.

**Key principle**: Copilot only surfaces content user already has read permissions for. This indicates an active permissions/access-scope issue, not a platform malfunction.

---

## Ranked Causes (Most to Least Probable)

### 1. Security Group / Team Access Inheritance
**Probability: Highest (65%)**

**Why this is plausible:**
- Legal department typically uses security groups for matter access (e.g., "Matter-[ClientName]-Team", "Legal-Floor6-All", departmental access groups)
- Paralegal may have been added to a group with broader matter access than her role requires
- In large legal environments, access scope drift is common: groups are created for specific matters, but over time users are added to general departmental groups that inadvertently include multiple matters
- Recent Win11/Intune migration may have re-synced on-premises security group memberships without validation of current scope

**Why this fits the Facts:**
- "Never had access to before" suggests access was granted recently or visibility was newly enabled
- No specific group membership data provided — to confirm

**Fastest confirmation check:**
- Query Active Directory (or Entra ID, if cloud-managed): List all security groups this paralegal's account is a member of
- For each group: Check documented purpose and matter-level permissions it grants
- Cross-reference against role/matter assignments in matter management system
  - **If found**: Group membership includes this client matter unintentionally
  - **If not found**: Rules out group inheritance as cause

---

### 2. Permission Propagation from Document Management App Deployment (Friday)
**Probability: High (25%)**

**Why this is plausible:**
- Document management app deployed Friday afternoon to Legal Floor 6
- New app may have created or modified resource permissions (SharePoint sites, Teams channels, shared drives, document repositories)
- App deployment could have auto-assigned "reader" or "team member" permissions to all Legal Floor 6 users by default
- Integration with client matter repository may have inadvertently granted broader read access during provisioning
- Intune enrollment + app deployment may have triggered policy-driven access assignment

**Why this fits the Facts:**
- Timing coincides with app deployment (Friday → matter visible in Copilot by Monday)
- Floor-level deployment suggests blanket permission assignment possible
- No app deployment scope or access model provided — to confirm

**Fastest confirmation check:**
- Query document management app logs or configuration: What permissions did app provisioning assign to Legal Floor 6 users?
- Check SharePoint/Teams/shared drive access list for the client matter: Was this paralegal added as reader/member by app deployment process?
- Review app vendor deployment documentation: Does it auto-grant access to all department users or only role-specific users?
  - **If user was added by app**: App deployment is cause
  - **If no app-driven assignment**: Rules out app as cause

---

### 3. Legacy On-Premises Permission Not Deprovisioned During Win11/Intune Migration
**Probability: Moderate (10%)**

**Why this is plausible:**
- Legal Floor 6 users recently migrated to Win11 and Intune enrollment
- Migration may have re-synced on-premises permissions without cleanup of obsolete or overly broad access rights
- Paralegal may have had access to this matter in past role, permission was not removed when role changed, and migration simply re-enabled it
- On-premises access control lists (ACLs) may not have been audited before cloud sync
- Hybrid identity scenario (on-prem AD + cloud) could have duplicate or conflicting permission entries

**Why this fits the Facts:**
- "Never had access to before" could mean "not in recent memory" rather than literally never; legacy access reinstated
- Win11/Intune migration is recent trigger event that could expose dormant permissions
- No on-premises/cloud permission sync audit provided — to confirm

**Fastest confirmation check:**
- Query on-premises Active Directory / ACLs for this client matter: Does this paralegal's account or any of her group memberships have explicit read permissions assigned?
- Compare on-premises ACLs to cloud (Entra ID / SharePoint) permissions: Are there permission entries in cloud that do not exist in current on-premises state?
- Review access provisioning/deprovisioning logs for this paralegal during past 12 months: Was she ever assigned or removed from this matter?
  - **If legacy on-prem ACL found**: On-premises permission re-sync is cause
  - **If cloud permissions only, no on-prem match**: Rules out migration as cause

---

## Evidence Gathering Priority
1. **Immediate (confirm cause #1)**: Security group membership query (fastest, highest probability)
2. **Secondary (confirm cause #2)**: Document management app provisioning logs
3. **Tertiary (confirm cause #3)**: On-premises vs. cloud permission audit

---

## Data-Governance Escalation Notes
- **Access path is active**: User has live read permissions; Copilot is correctly surfacing authorized content
- **Scope of review needed**: Audit all Legal Floor 6 users for similar unintended matter access (not just this paralegal)
- **Potential systemic issue**: If cause is group inheritance or app deployment, issue may affect multiple users
- **No data breach confirmed**: User has technical permissions; investigation should determine if access grant violated policy or governance rules
- **To confirm**: Obtain matter-level access matrix, current security group membership definitions, and app deployment configuration

---

## Next Step
Hand to security/data-governance team with: (1) current user's account details, (2) client matter details, (3) this ranked cause list. Security team to execute fastest checks in order until cause is confirmed and scope of affected users is determined.
