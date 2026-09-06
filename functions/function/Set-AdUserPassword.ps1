<#
.SYNOPSIS
    Resets a single user's password. Honours -WhatIf for Test mode.
.OUTPUTS
    [pscustomobject] result row consumed by the reports.
#>
function Set-AdUserPassword {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [object]$User,
        [Parameter(Mandatory)] [string]$Password,
        [object]$Config = $script:App.Config
    )

    $server = $Config.Domain.Server
    $common = @{ ErrorAction = 'Stop' }
    if ($server) { $common.Server = $server }

    $state   = 'OK'
    $message = ''

    try {
        if ($script:App.DemoMode) {
            if (-not $PSCmdlet.ShouldProcess($User.SamAccountName, 'Set-ADAccountPassword (demo)')) {
                $state = 'WHATIF'
            }
        }
        else {
            $secure = ConvertTo-SecureString -String $Password -AsPlainText -Force
            if ($PSCmdlet.ShouldProcess($User.SamAccountName, 'Set-ADAccountPassword -Reset')) {
                Set-ADAccountPassword -Identity $User.DistinguishedName -Reset -NewPassword $secure @common
            }
            else {
                $state = 'WHATIF'
            }
        }
    }
    catch {
        $state   = 'FAILED'
        $message = $_.Exception.Message
    }

    return (New-ResultRow -User $User -Password $Password -State $state -Message $message `
                          -PasswordChanged $true -Config $Config)
}
