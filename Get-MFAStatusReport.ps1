<#
.SYNOPSIS
    Exports an MFA registration status report for all Entra ID users to CSV.

.DESCRIPTION
    Queries Microsoft Graph to retrieve MFA registration details for all users.
    Outputs a CSV showing per-user MFA method registration. Useful for compliance
    audits, security reviews, and tracking MFA adoption across your tenant.

.PARAMETER ExportPath
    Output CSV path. Defaults to .\MFA-Status-Report.csv

.PARAMETER FilterNonMFA
    If specified, exports only users who have NOT registered any MFA method.

.EXAMPLE
    .\Get-MFAStatusReport.ps1
    .\Get-MFAStatusReport.ps1 -FilterNonMFA
    .\Get-MFAStatusReport.ps1 -ExportPath "C:\Reports\MFA-June-2025.csv"

.NOTES
    Author:      Reyan Qureshi
    Requires:    Microsoft.Graph PowerShell SDK
    Permissions: UserAuthenticationMethod.Read.All, User.Read.All
#>

[CmdletBinding()]
param (
    [string]$ExportPath  = ".\MFA-Status-Report.csv",
    [switch]$FilterNonMFA
)

function Write-Log {
    param ([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message"
}

Write-Log "Connecting to Microsoft Graph..."
try {
    Connect-MgGraph -Scopes "UserAuthenticationMethod.Read.All","User.Read.All" -ErrorAction Stop
    Write-Log "Connected successfully."
} catch {
    Write-Log "Connection failed: $_" -Level "ERROR"; exit 1
}

Write-Log "Retrieving all users..."
$Users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,Department -ErrorAction Stop
Write-Log "Found $($Users.Count) users. Checking MFA status..."

$Results = [System.Collections.Generic.List[PSObject]]::new()
$Counter = 0

foreach ($User in $Users) {
    $Counter++
    Write-Progress -Activity "Checking MFA" -Status $User.UserPrincipalName -PercentComplete (($Counter / $Users.Count) * 100)
    try {
        $Methods     = Get-MgUserAuthenticationMethod -UserId $User.Id -ErrorAction Stop
        $MethodTypes = $Methods | ForEach-Object { $_.'@odata.type' -replace '#microsoft.graph.','' }

        $Results.Add([PSCustomObject]@{
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            Department        = $User.Department
            AccountEnabled    = $User.AccountEnabled
            MFARegistered     = ($MethodTypes | Where-Object { $_ -ne 'passwordAuthenticationMethod' }).Count -gt 0
            AuthenticatorApp  = $MethodTypes -contains 'microsoftAuthenticatorAuthenticationMethod'
            PhoneMethod       = $MethodTypes -contains 'phoneAuthenticationMethod'
            FIDO2Key          = $MethodTypes -contains 'fido2AuthenticationMethod'
            WindowsHello      = $MethodTypes -contains 'windowsHelloForBusinessAuthenticationMethod'
            MethodsRegistered = ($MethodTypes -join ", ")
            ReportDate        = (Get-Date -Format "yyyy-MM-dd")
        })
    } catch {
        Write-Log "Skipping $($User.UserPrincipalName): $_" -Level "WARN"
    }
}

if ($FilterNonMFA) {
    $Results = $Results | Where-Object { -not $_.MFARegistered }
    Write-Log "Filtered to non-MFA users."
}

$Results | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
Write-Log "Report saved: $ExportPath"
Write-Log "MFA Registered: $(($Results | Where-Object {$_.MFARegistered}).Count) | No MFA: $(($Results | Where-Object {-not $_.MFARegistered}).Count)"

Disconnect-MgGraph
