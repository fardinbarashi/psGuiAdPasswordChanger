<#
.SYNOPSIS
    Normalizes a raw AD user into the user object used across the app and reports.
#>
function ConvertTo-UserObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [object]$AdUser,
        [object]$Config = $script:App.Config
    )

    process {
        $nameAttr  = $Config.Attributes.DisplayNameAttribute

        $displayName = if ($nameAttr -and $AdUser.PSObject.Properties[$nameAttr] -and $AdUser.$nameAttr) { [string]$AdUser.$nameAttr } else { [string]$AdUser.Name }

        $enabled   = if ($AdUser.PSObject.Properties['Enabled'])   { [bool]$AdUser.Enabled }   else { $true }
        $locked    = if ($AdUser.PSObject.Properties['LockedOut']) { [bool]$AdUser.LockedOut } else { $false }
        $pne       = if ($AdUser.PSObject.Properties['PasswordNeverExpires']) { [bool]$AdUser.PasswordNeverExpires } else { $false }

        # --- Password expiry ---------------------------------------------
        $pwExpired = if ($AdUser.PSObject.Properties['PasswordExpired']) { [bool]$AdUser.PasswordExpired } else { $false }
        $pwExpiry  = $null
        $attr = 'msDS-UserPasswordExpiryTimeComputed'
        if ($AdUser.PSObject.Properties[$attr] -and $null -ne $AdUser.$attr) {
            try {
                $ticks = [int64]$AdUser.$attr
                if ($ticks -gt 0 -and $ticks -lt [int64]::MaxValue) {
                    $pwExpiry = [DateTime]::FromFileTime($ticks)
                }
            } catch { $pwExpiry = $null }
        }
        if ($pne) { $pwExpiry = $null; $pwExpired = $false }
        if (-not $pwExpired -and $pwExpiry -and $pwExpiry -le (Get-Date)) { $pwExpired = $true }

        # --- Account expiry ----------------------------------------------
        $acctExpiry = if ($AdUser.PSObject.Properties['AccountExpirationDate']) { $AdUser.AccountExpirationDate } else { $null }
        $acctExpired = ($null -ne $acctExpiry -and $acctExpiry -le (Get-Date))

        [pscustomobject]@{
            Name                 = $displayName
            SamAccountName       = [string]$AdUser.SamAccountName
            Account              = if ($AdUser.UserPrincipalName) { [string]$AdUser.UserPrincipalName } else { [string]$AdUser.SamAccountName }
            DistinguishedName    = [string]$AdUser.DistinguishedName
            Enabled              = $enabled
            LockedOut            = $locked
            PasswordNeverExpires = $pne
            PasswordExpired      = $pwExpired
            PasswordExpiryDate   = $pwExpiry
            AccountExpired       = $acctExpired
            AccountExpiryDate    = $acctExpiry
        }
    }
}
