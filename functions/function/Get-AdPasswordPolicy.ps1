<#
.SYNOPSIS
    Reads the effective GPO password policy from the domain (default domain policy).
.DESCRIPTION
    Returns a normalized object describing minimum length, complexity, history, etc.
    Falls back to a sane demo policy when AD is not available.
#>
function Get-AdPasswordPolicy {
    [CmdletBinding()]
    param(
        [string]$Server = $script:App.Config.Domain.Server
    )

    if (-not $script:App.AdAvailable) {
        Write-AppLog 'ActiveDirectory not available - using demo password policy.' 'WARN'
        return [pscustomobject]@{
            MinPasswordLength = 8
            ComplexityEnabled = $true
            PasswordHistory   = 24
            MaxPasswordAgeDays= 42
            LockoutThreshold  = 5
        }
    }

    try {
        $params = @{ ErrorAction = 'Stop' }
        if ($Server) { $params.Server = $Server }
        $p = Get-ADDefaultDomainPasswordPolicy @params

        return [pscustomobject]@{
            MinPasswordLength = [int]$p.MinPasswordLength
            ComplexityEnabled = [bool]$p.ComplexityEnabled
            PasswordHistory   = [int]$p.PasswordHistoryCount
            MaxPasswordAgeDays= [int]$p.MaxPasswordAge.TotalDays
            LockoutThreshold  = [int]$p.LockoutThreshold
        }
    }
    catch {
        Write-AppLog "Could not read domain password policy: $($_.Exception.Message)" 'ERROR'
        throw
    }
}
