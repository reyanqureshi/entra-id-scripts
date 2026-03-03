# 🔐 Entra ID PowerShell Automation Scripts

![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Microsoft Graph](https://img.shields.io/badge/Microsoft%20Graph-0078D4?style=flat-square&logo=microsoft&logoColor=white)
![Entra ID](https://img.shields.io/badge/Microsoft%20Entra%20ID-0078D4?style=flat-square&logo=microsoftazure&logoColor=white)
![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square)

A collection of production-ready PowerShell scripts for automating identity lifecycle management in Microsoft Entra ID. Built using the **Microsoft Graph PowerShell SDK** — the modern replacement for the deprecated AzureAD and MSOnline modules.

All scripts are used in a real enterprise IT environment and are designed to be modular, auditable, and safe for production use.

---

## 📋 Prerequisites

### Install Microsoft Graph PowerShell SDK
```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

### Connect to Microsoft Graph
```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All"
```

> **Note:** First-time use requires admin consent for the required permission scopes. Each script lists its required permissions in the .NOTES section.

---

## 📂 Scripts

### 1. `New-EntraUser.ps1` — User Provisioning
Creates a new Entra ID user with standard organizational settings including department, job title, usage location, and license group assignment. Generates a secure temporary password and forces change at first login.

**Required Permissions:** `User.ReadWrite.All`, `Group.ReadWrite.All`

```powershell
.\New-EntraUser.ps1 `
    -FirstName "Jane" `
    -LastName "Doe" `
    -Department "IT" `
    -JobTitle "Help Desk Analyst" `
    -LicenseGroup "M365-BusinessPremium"
```

---

### 2. `Remove-EntraUser.ps1` — User Offboarding
Performs a full offboarding sequence: disables the account, revokes all active sign-in sessions, and removes the user from all security and M365 groups. All actions are logged for audit trail. Account is disabled (not deleted) to allow for 30-day review before permanent removal.

**Required Permissions:** `User.ReadWrite.All`, `Group.ReadWrite.All`

```powershell
.\Remove-EntraUser.ps1 -UPN "jane.doe@yourdomain.com"
```

---

### 3. `Get-MFAStatusReport.ps1` — MFA Compliance Report
Queries all users and exports a CSV report showing per-user MFA registration status — Authenticator App, Phone, FIDO2 key, and Windows Hello. Includes a `-FilterNonMFA` flag to instantly surface at-risk users for compliance follow-up.

**Required Permissions:** `UserAuthenticationMethod.Read.All`, `User.Read.All`

```powershell
# Full report
.\Get-MFAStatusReport.ps1

# Only users WITHOUT MFA registered
.\Get-MFAStatusReport.ps1 -FilterNonMFA

# Custom export path
.\Get-MFAStatusReport.ps1 -ExportPath "C:\Reports\MFA-June-2025.csv"
```

---

### 4. `Reset-UserPassword.ps1` — Password Reset
Resets a user's password with a secure auto-generated temporary password and forces change at next login. Logs all reset actions with timestamps for audit purposes.

**Required Permissions:** `User.ReadWrite.All`

```powershell
# Auto-generate temp password
.\Reset-UserPassword.ps1 -UPN "jane.doe@yourdomain.com"

# Provide your own temp password
.\Reset-UserPassword.ps1 -UPN "jane.doe@yourdomain.com" -TempPassword "Welcome2025!"
```

---

### 5. `Get-GroupMembership.ps1` — Group Membership Audit
Three-mode audit tool for group membership analysis. Use it to inspect a single user's groups, list all members of a group, or run a full tenant-wide export to CSV for compliance reviews.

**Required Permissions:** `User.Read.All`, `Group.Read.All`, `GroupMember.Read.All`

```powershell
# Audit a single user's group memberships
.\Get-GroupMembership.ps1 -UPN "jane.doe@yourdomain.com"

# List all members of a specific group
.\Get-GroupMembership.ps1 -GroupName "IT-Admins"

# Full tenant-wide audit export
.\Get-GroupMembership.ps1 -FullAudit
.\Get-GroupMembership.ps1 -FullAudit -ExportPath "C:\Reports\Groups-June-2025.csv"
```

---

## 🔒 Security Notes

- All scripts use **least-privilege scopes** — only requesting the permissions they need
- Passwords are never written to log files in plaintext beyond the console session
- Offboarding script **disables** accounts rather than deleting them — preserving data for legal/compliance review
- All scripts include structured logging with timestamps for audit trail

---

## 🗺️ Roadmap

- [ ] Bulk user provisioning from CSV import
- [ ] Conditional Access policy audit and reporting
- [ ] Stale account detection (inactive 90+ days)
- [ ] Automated MFA enforcement reminder emails via Graph Mail API
- [ ] Service principal / app registration audit

---

*Part of my Cloud Security / IAM Engineering portfolio. See more at [github.com/reyanqureshi](https://github.com/reyanqureshi)*
