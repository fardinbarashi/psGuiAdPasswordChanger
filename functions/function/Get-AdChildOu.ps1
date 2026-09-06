<#
.SYNOPSIS
    Lazy-load: returns the child OUs directly under a parent OU (or the search base),
    each with the number of users in its whole subtree.
.DESCRIPTION
    Counting is fast: ONE query for all users under the parent, then bucketed per
    child OU by DN suffix (no per-OU subtree queries).
#>
function Get-AdChildOu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$ParentDN,
        [object]$Config = $script:App.Config
    )

    if ($script:App.DemoMode) {
        return Get-DemoData -Level 'ChildOus' -Parent $ParentDN
    }

    $server = $Config.Domain.Server
    $common = @{ ErrorAction = 'Stop' }
    if ($server) { $common.Server = $server }

    $ous = Get-ADOrganizationalUnit -SearchBase $ParentDN -SearchScope OneLevel -Filter * -Properties Name @common |
           Sort-Object Name
    if (-not $ous) { return @() }

    $childKeys = @($ous | ForEach-Object { $_.DistinguishedName })
    $counts    = @{}; foreach ($k in $childKeys) { $counts[$k] = 0 }

    try {
        $people = Get-ADUser -SearchBase $ParentDN -SearchScope Subtree `
                    -LDAPFilter '(&(objectCategory=person)(objectClass=user))' @common
        foreach ($p in $people) {
            $dn = $p.DistinguishedName
            foreach ($ck in $childKeys) {
                if ($dn.EndsWith(',' + $ck, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $counts[$ck]++
                    break
                }
            }
        }
    }
    catch {
        Write-AppLog ("Could not pre-count users under '{0}': {1}" -f $ParentDN, $_.Exception.Message) 'WARN'
    }

    $nodes = foreach ($ou in $ous) {
        $count = [int]$counts[$ou.DistinguishedName]
        if (-not $Config.Domain.IncludeEmptyOus -and $count -eq 0) { continue }
        [pscustomobject]@{
            Name              = $ou.Name
            DistinguishedName = $ou.DistinguishedName
            Count             = $count
        }
    }

    return $nodes
}
