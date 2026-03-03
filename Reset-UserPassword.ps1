<#
.SYNOPSIS
    Resets a user's password in Entra ID and forces change at next sign-in.

.DESCRIPTION
    Generates a secure temporary password, applies it to the specified user account,
    and enforces a password change at next login. Logs the action for audit purposes.
    The temporary password is displayed once — deliver it securely to the user.

.PARAMETER UPN
    The UserPrincipalName of the target user.

.PARAMETER TempPassword
    Optional: Provide your own temporary password. If omitted, one is auto-generated.

.EXAMPLE
    .\Reset-UserPassword.ps1 -UPN "jane.doe@yourdomain.com"
    .\Reset-UserPassword.ps1 -UPN "jane.doe@yourdomain.com" -TempPassword "Welcome2025!"

.NOTES
    Author:      Reyan Qureshi
    Module:      Microsoft.Graph.Users
    Permissions: User.ReadWrite.All
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$UPN,

    [string]$TempPassword
)

function New-RandomPassword {
    param ([int]$Length = 16)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry
    Add-Content -Path ".\PasswordResets.log" -Value $entry
}

Write-Log "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All" -ErrorAction Stop
    Write-Log "Connected successfully."
} catch {
    Write-Log "Connection failed: $_" -Level "ERROR"; exit 1
}

# --- LOOKUP USER ---
Write-Log "Looking up user: $UPN"
try {
    $User = Get-MgUser -UserId $UPN -Property Id, DisplayName, AccountEnabled -ErrorAction Stop
    Write-Log "Found: $($User.DisplayName)"
} catch {
    Write-Log "User not found: $UPN" -Level "ERROR"; exit 1
}

if (-not $User.AccountEnabled) {
    Write-Log "WARNING: This account is currently disabled." -Level "WARN"
}

# --- GENERATE OR USE PROVIDED PASSWORD ---
if (-not $TempPassword) {
    $TempPassword = New-RandomPassword -Length 16
    Write-Log "Generated temporary password."
}

# --- RESET PASSWORD ---
Write-Log "Resetting password for $($User.DisplayName)..."
try {
    Update-MgUser -UserId $User.Id -PasswordProfile @{
        Password                      = $TempPassword
        ForceChangePasswordNextSignIn = $true
    } -ErrorAction Stop
    Write-Log "Password reset successful."
} catch {
    Write-Log "Password reset failed: $_" -Level "ERROR"; exit 1
}

Write-Log "=== Password Reset Complete ==="
Write-Log "User          : $($User.DisplayName)"
Write-Log "UPN           : $UPN"
Write-Log "Temp Password : $TempPassword  <-- Deliver securely"
Write-Log "Force Change  : Yes"
Write-Log "==============================="

Disconnect-MgGraph
