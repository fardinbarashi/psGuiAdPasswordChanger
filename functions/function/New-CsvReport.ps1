<#
.SYNOPSIS
    Writes a CSV report for one OU (sorted by name), including account status,
    password-expiry and account-expiry information.
#>
function New-CsvReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Results,
        [Parameter(Mandatory)] [string]$Path
    )

    function FmtDate($d) { if ($d) { ([datetime]$d).ToString('yyyy-MM-dd') } else { '' } }

    $rows = $Results |
        Sort-Object Ou, Name |
        Select-Object @{N='OU';E={$_.Ou}},
                      Name,
                      @{N='Username';E={$_.SamAccountName}},
                      Account,
                      @{N='State';E={$_.State}},
                      @{N='Enabled';E={$_.Enabled}},
                      @{N='Locked';E={$_.LockedOut}},
                      @{N='PWneverExpires';E={$_.PasswordNeverExpires}},
                      @{N='PWexpired';E={$_.PasswordExpired}},
                      @{N='PWexpire';E={FmtDate $_.PasswordExpiryDate}},
                      @{N='AccountExpired';E={$_.AccountExpired}},
                      @{N='AccountExpire';E={FmtDate $_.AccountExpiryDate}},
                      @{N='Options';E={ if ($_.PSObject.Properties['Options']) { $_.Options } else { '' } }},
                      @{N='PW';E={
                            $changed = if ($_.PSObject.Properties['PasswordChanged']) { [bool]$_.PasswordChanged } else { $true }
                            if ($changed) { $_.Password } else { '- not changed -' }
                        }},
                      Message

    $rows | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -Delimiter ';'
    return $Path
}
