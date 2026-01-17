
# ESA Requirements for Cannery Tech

## 1. Management Groups (CAF-aligned)
- **Root**
	- `myco-company` (CAN - Company)
		- `myco-platform` (CAN - Platform/Hub)
		- `myco-dev` (CAN - Dev)
		- `myco-prod` (CAN - Prod)

## 2. Identity Groups & Service Principals
- `MYCO-ADM-Global` — Administer Global Administrator role
- `MYCO-ADM-Security` — Administer Security Administrator role
- `MYCO-GRP-Engineering` — Engineering user group
- `MYCO-GRP-Contractors` — Contractor access group
- `MYCO-SPN-Deploy` — Deployment automation SPN

**Best Practices:**
- All groups use the `MYCO-` prefix for clarity and automation.
- Admin groups are mapped to directory roles for least privilege.
- Service principals are created for automation, not for user logins.

## 3. Break Glass Account
- **UPN:** `break.glass@myco.io`
- **Notes:**
	- Excluded from all Conditional Access and risk-based policies.
	- Password must be long, rotated, and stored in Key Vault.
	- No licenses assigned.
	- All sign-ins must be monitored and investigated.

## 4. Conditional Access Policies
- **MYCO-CA-Require-MFA-All-Users:**  
	Require MFA for all users, excluding `break.glass@myco.io`.
- **MYCO-CA-Require-MFA-Admins:**  
	Require MFA for all admin roles, excluding `break.glass@myco.io`.
- **MYCO-CA-Block-Legacy-Auth:**  
	Block legacy authentication clients.
- **MYCO-CA-Exclusion-Break-Glass:**  
	Documentation artifact for break-glass exclusions.

**Best Practices:**
- Exclude break-glass only where absolutely necessary.
- Consider removing legacy auth exclusion for break-glass if possible.

## 5. Identity Protection & Audit
- **Sign-in risk policy:**  
	Enforce MFA for medium/high risk sign-ins, exclude break-glass.
- **User risk policy:**  
	Require password change for high-risk users, exclude break-glass.
- **Unified audit log:**  
	Enabled, 90-day retention.
- **Directory audit:**  
	Log sign-ins and service principal activity.

## 6. Privileged Identity Management (PIM)
- **Eligible roles:**  
	Global Admin, Privileged Role Admin, Security Admin, Application Admin, Cloud App Admin.
- **Activation:**  
	4-hour max, require MFA and justification, notify security@myco.io.
- **Assignments:**  
	`my.user@myco.com` (initial), `my.user@myco.io` (future, disabled until mailbox ready).

## 7. Platform Resources (Hub)
- Hub VNET
- Private DNS zones
- Log Analytics workspace
- Diagnostic settings
- Key Vault
- Firewall (optional)

## 8. Landing Zones (Spokes)
- `myco-dev` (Dev spoke)
- `myco-prod` (Prod spoke)
- Product-specific spokes (future expansion)