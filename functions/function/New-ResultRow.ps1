<#
.SYNOPSIS
    Builds the standard result row that the HTML and CSV reports consume.
.DESCRIPTION
    Used both by the password reset (Set-AdUserPassword) and by an
    account-options-only run, so both kinds of run produce identical columns.
    PasswordChanged = $false marks a row where no password was touched; the
    reports then print "- not changed -" instead of a masked password.
#>
function New-ResultRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$User,
        [string]$Password = '',
        [string]$State = 'OK',
        [string]$Message = '',
        [string]$Options = '',
        [bool]$PasswordChanged = $true,
        [object]$Config = $script:App.Config
    )

    $ou = if ($User.PSObject.Properties['Ou'] -and $User.Ou) {
        $User.Ou
    } else {
        Get-TopOuFromDn -DistinguishedName $User.DistinguishedName -Config $Config
    }

    [pscustomobject]@{
        Name                 = $User.Name
        Account              = $User.Account
        SamAccountName       = $User.SamAccountName
        Enabled              = $User.Enabled
        LockedOut            = $User.LockedOut
        PasswordNeverExpires = $User.PasswordNeverExpires
        PasswordExpired      = $User.PasswordExpired
        PasswordExpiryDate   = $User.PasswordExpiryDate
        AccountExpired       = $User.AccountExpired
        AccountExpiryDate    = $User.AccountExpiryDate
        State                = $State
        Password             = $Password
        PasswordChanged      = $PasswordChanged
        Options              = $Options
        Message              = $Message
        Ou                   = $ou
    }
}
