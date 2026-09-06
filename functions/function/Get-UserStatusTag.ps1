<#
.SYNOPSIS
    Builds the status tags shown after a user's name, e.g.
    [Disabled] [Locked] [PW Expired]  or  [PW Expire : 2026-09-15].
.OUTPUTS
    Array of @{ Text=...; Kind='bad'|'info' } in display order.
#>
function Get-UserStatusTag {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [object]$User)

    $tags = New-Object System.Collections.Generic.List[object]

    if (-not $User.Enabled)  { $tags.Add(@{ Text = '[Disabled]'; Kind = 'bad' }) }
    if ($User.LockedOut)     { $tags.Add(@{ Text = '[Locked]';   Kind = 'bad' }) }

    if ($User.PSObject.Properties['PasswordExpired'] -and $User.PasswordExpired) {
        $tags.Add(@{ Text = '[PW Expired]'; Kind = 'bad' })
    }
    elseif ($User.PSObject.Properties['PasswordExpiryDate'] -and $User.PasswordExpiryDate) {
        $tags.Add(@{ Text = ('[PW Expire : {0}]' -f $User.PasswordExpiryDate.ToString('yyyy-MM-dd')); Kind = 'info' })
    }

    if ($User.PSObject.Properties['AccountExpired'] -and $User.AccountExpired) {
        $tags.Add(@{ Text = '[Account Expired]'; Kind = 'bad' })
    }
    elseif ($User.PSObject.Properties['AccountExpiryDate'] -and $User.AccountExpiryDate) {
        $tags.Add(@{ Text = ('[Account Expire : {0}]' -f $User.AccountExpiryDate.ToString('yyyy-MM-dd')); Kind = 'info' })
    }

    return $tags.ToArray()
}
