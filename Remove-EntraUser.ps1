<#
.SYNOPSIS
    Offboards a user from Microsoft Entra ID.

.DESCRIPTION
    Full offboarding sequence:
      1. Disables the user account
      2. Revokes all active sign-in sessions
      3. Removes from all group memberships
      4. Logs all actions for audit trail
    Note: Account is DISABLED, not deleted. Manual deletion after 30-day review is recommended.

.PARAMETER UPN
    The UserPrincipalName of the user to offboard.

.EXAMPLE
    .\Remove-EntraUser.ps1 -UPN "john.doe@yourdomain.com"

.NOTES
    Author:      Reyan Qureshi
    Requires:    Microsoft.Graph PowerShell SDK
    Permissions: User.ReadWrite.All, Group.ReadWrite.All
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string]$UPN
)

function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] [$Level] $Message"
    Write-Host $entry
    Add-Content -Path ".\EntraOffboarding.log" -Value $entry
}

Write-Log "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All" -ErrorAction Stop
    Write-Log "Connected successfully."
} catch {
    Write-Log "Connection failed: $_" -Level "ERROR"; exit 1
}

# Lookup user
Write-Log "Looking up user: $UPN"
try {
    $User = Get-MgUser -UserId $UPN -ErrorAction Stop
    Write-Log "Found: $($User.DisplayName) | Id: $($User.Id)"
} catch {
    Write-Log "User not found: $UPN" -Level "ERROR"; exit 1
}

# Step 1: Disable account
Write-Log "Step 1/3 — Disabling account..."
try {
    Update-MgUser -UserId $User.Id -AccountEnabled $false -ErrorAction Stop
    Write-Log "Account disabled."
} catch {
    Write-Log "Failed to disable: $_" -Level "ERROR"
}

# Step 2: Revoke sessions
Write-Log "Step 2/3 — Revoking all active sessions..."
try {
    Revoke-MgUserSignInSession -UserId $User.Id -ErrorAction Stop
    Write-Log "Sessions revoked."
} catch {
    Write-Log "Failed to revoke sessions: $_" -Level "ERROR"
}

# Step 3: Remove from all groups
Write-Log "Step 3/3 — Removing from all groups..."
try {
    $MemberOf = Get-MgUserMemberOf -UserId $User.Id -All -ErrorAction Stop
    $Groups   = $MemberOf | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }

    if ($Groups.Count -eq 0) {
        Write-Log "No group memberships found."
    } else {
        foreach ($Group in $Groups) {
            try {
                Remove-MgGroupMemberByRef -GroupId $Group.Id -DirectoryObjectId $User.Id -ErrorAction Stop
                Write-Log "Removed from: $($Group.AdditionalProperties['displayName'])"
            } catch {
                Write-Log "Could not remove from $($Group.Id): $_" -Level "WARN"
            }
        }
    }
} catch {
    Write-Log "Failed to retrieve memberships: $_" -Level "ERROR"
}

Write-Log "=== Offboarding Complete ==="
Write-Log "User   : $($User.DisplayName)"
Write-Log "UPN    : $UPN"
Write-Log "Status : Disabled | Sessions Revoked | Groups Removed"
Write-Log "Next   : Review and hard-delete after 30 days if required"
Write-Log "============================"

Disconnect-MgGraph
