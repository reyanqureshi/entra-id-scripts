<#
.SYNOPSIS
    Audits and exports group membership for one user, one group, or all users.

.DESCRIPTION
    Flexible group membership audit tool with three modes:
      - User mode:  Lists all groups a specific user belongs to
      - Group mode: Lists all members of a specific group
      - Audit mode: Exports full tenant-wide user-to-group membership map (CSV)

.PARAMETER UPN
    UserPrincipalName to audit memberships for a single user.

.PARAMETER GroupName
    Display name of a group to list all its members.

.PARAMETER FullAudit
    Switch to run a full tenant-wide group membership export.

.PARAMETER ExportPath
    Output CSV path for FullAudit mode. Defaults to .\GroupMembership-Audit.csv

.EXAMPLE
    .\Get-GroupMembership.ps1 -UPN "jane.doe@yourdomain.com"
    .\Get-GroupMembership.ps1 -GroupName "IT-Admins"
    .\Get-GroupMembership.ps1 -FullAudit
    .\Get-GroupMembership.ps1 -FullAudit -ExportPath "C:\Reports\Groups-June-2025.csv"

.NOTES
    Author:      Reyan Qureshi
    Module:      Microsoft.Graph.Users, Microsoft.Graph.Groups
    Permissions: User.Read.All, Group.Read.All, GroupMember.Read.All
#>

[CmdletBinding(DefaultParameterSetName = "User")]
param (
    [Parameter(ParameterSetName = "User")]
    [string]$UPN,

    [Parameter(ParameterSetName = "Group")]
    [string]$GroupName,

    [Parameter(ParameterSetName = "Audit")]
    [switch]$FullAudit,

    [string]$ExportPath = ".\GroupMembership-Audit.csv"
)

function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

Write-Log "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "GroupMember.Read.All" -ErrorAction Stop
    Write-Log "Connected successfully."
} catch {
    Write-Log "Connection failed: $_" -Level "ERROR"; exit 1
}

# --- MODE 1: SINGLE USER ---
if ($PSCmdlet.ParameterSetName -eq "User" -and $UPN) {
    Write-Log "Retrieving group memberships for: $UPN"
    try {
        $User     = Get-MgUser -UserId $UPN -ErrorAction Stop
        $MemberOf = Get-MgUserMemberOf -UserId $User.Id -All -ErrorAction Stop
        $Groups   = $MemberOf | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }

        Write-Host "
Groups for $($User.DisplayName) ($UPN):
" -ForegroundColor Cyan
        $Groups | ForEach-Object { Write-Host "  - $($_.AdditionalProperties['displayName'])" }
        Write-Log "Total groups: $($Groups.Count)"
    } catch {
        Write-Log "Error: $_" -Level "ERROR"
    }
}

# --- MODE 2: SINGLE GROUP ---
elseif ($PSCmdlet.ParameterSetName -eq "Group" -and $GroupName) {
    Write-Log "Retrieving members of group: $GroupName"
    try {
        $Group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction Stop
        if (-not $Group) { Write-Log "Group not found: $GroupName" -Level "ERROR"; exit 1 }

        $Members = Get-MgGroupMember -GroupId $Group.Id -All -ErrorAction Stop
        Write-Host "
Members of '$GroupName':
" -ForegroundColor Cyan
        $Members | ForEach-Object {
            Write-Host "  - $($_.AdditionalProperties['userPrincipalName'] ?? $_.AdditionalProperties['displayName'])"
        }
        Write-Log "Total members: $($Members.Count)"
    } catch {
        Write-Log "Error: $_" -Level "ERROR"
    }
}

# --- MODE 3: FULL AUDIT ---
elseif ($PSCmdlet.ParameterSetName -eq "Audit") {
    Write-Log "Running full tenant group membership audit..."
    $Users   = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, Department -ErrorAction Stop
    $Results = [System.Collections.Generic.List[PSObject]]::new()
    $Counter = 0

    foreach ($User in $Users) {
        $Counter++
        Write-Progress -Activity "Auditing group memberships" -Status $User.UserPrincipalName `
            -PercentComplete (($Counter / $Users.Count) * 100)

        try {
            $MemberOf = Get-MgUserMemberOf -UserId $User.Id -All -ErrorAction Stop
            $Groups   = $MemberOf | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' }

            foreach ($Group in $Groups) {
                $Results.Add([PSCustomObject]@{
                    DisplayName       = $User.DisplayName
                    UserPrincipalName = $User.UserPrincipalName
                    Department        = $User.Department
                    GroupName         = $Group.AdditionalProperties['displayName']
                    GroupId           = $Group.Id
                    ReportDate        = (Get-Date -Format "yyyy-MM-dd")
                })
            }
        } catch {
            Write-Log "Skipping $($User.UserPrincipalName): $_" -Level "WARN"
        }
    }

    $Results | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
    Write-Log "Audit complete. $($Results.Count) records exported to: $ExportPath"
}

Disconnect-MgGraph
