<#
.SYNOPSIS
    Provisions a new user in Microsoft Entra ID with standard organizational settings.

.DESCRIPTION
    Creates a new Entra ID user account with display name, UPN, department, job title,
    usage location, and license group assignment. Uses Microsoft Graph PowerShell SDK.

.PARAMETER FirstName
    User's first name.

.PARAMETER LastName
    User's last name.

.PARAMETER Department
    Department the user belongs to (e.g., IT, HR, Finance).

.PARAMETER JobTitle
    User's job title.

.PARAMETER LicenseGroup
    Name of the Azure AD group used for license assignment (e.g., "M365-BusinessPremium").

.EXAMPLE
    .\New-EntraUser.ps1 -FirstName "Jane" -LastName "Doe" -Department "IT" -JobTitle "Help Desk Analyst" -LicenseGroup "M365-BusinessPremium"

.NOTES
    Author:      Reyan Qureshi
    Requires:    Microsoft.Graph PowerShell SDK
    Permissions: User.ReadWrite.All, Group.ReadWrite.All
    Install:     Install-Module Microsoft.Graph -Scope CurrentUser
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)] [string]$FirstName,
    [Parameter(Mandatory)] [string]$LastName,
    [Parameter(Mandatory)] [string]$Department,
    [Parameter(Mandatory)] [string]$JobTitle,
    [Parameter(Mandatory)] [string]$LicenseGroup
)

#region CONFIGURATION
$TenantDomain  = "yourdomain.com"   # Replace with your verified domain
$UsageLocation = "US"
#endregion

function New-RandomPassword {
    param ([int]$Length = 16)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$ts] [$Level] $Message"
    Write-Host $entry
    Add-Content -Path ".\EntraProvisioning.log" -Value $entry
}

# Connect
Write-Log "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All" -ErrorAction Stop
    Write-Log "Connected successfully."
} catch {
    Write-Log "Connection failed: $_" -Level "ERROR"; exit 1
}

# Build user object
$UPN         = "$($FirstName.ToLower()).$($LastName.ToLower())@$TenantDomain"
$DisplayName = "$FirstName $LastName"
$TempPwd     = New-RandomPassword -Length 16

$UserParams = @{
    DisplayName       = $DisplayName
    UserPrincipalName = $UPN
    MailNickname      = "$($FirstName.ToLower())$($LastName.ToLower())"
    GivenName         = $FirstName
    Surname           = $LastName
    Department        = $Department
    JobTitle          = $JobTitle
    UsageLocation     = $UsageLocation
    AccountEnabled    = $true
    PasswordProfile   = @{
        Password                      = $TempPwd
        ForceChangePasswordNextSignIn = $true
    }
}

# Create user
Write-Log "Creating user: $DisplayName ($UPN)..."
try {
    $NewUser = New-MgUser @UserParams -ErrorAction Stop
    Write-Log "User created. ObjectId: $($NewUser.Id)"
} catch {
    Write-Log "Failed to create user: $_" -Level "ERROR"; exit 1
}

# Assign license group
Write-Log "Assigning license group: $LicenseGroup..."
try {
    $Group = Get-MgGroup -Filter "displayName eq '$LicenseGroup'" -ErrorAction Stop
    if (-not $Group) {
        Write-Log "Group not found: $LicenseGroup" -Level "WARN"
    } else {
        $Body = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($NewUser.Id)" }
        New-MgGroupMember -GroupId $Group.Id -BodyParameter $Body -ErrorAction Stop
        Write-Log "Added to license group: $LicenseGroup"
    }
} catch {
    Write-Log "License group assignment failed: $_" -Level "ERROR"
}

Write-Log "=== Provisioning Complete ==="
Write-Log "UPN           : $UPN"
Write-Log "Temp Password : $TempPwd  <-- Deliver securely to user"
Write-Log "Force Change  : Yes"
Write-Log "============================="

Disconnect-MgGraph
