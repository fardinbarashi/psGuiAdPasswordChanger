<#
.SYNOPSIS
    Derives the ou (top-level OU under the search base) name from a DN.
#>
function Get-TopOuFromDn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$DistinguishedName,
        [object]$Config = $script:App.Config
    )

    $searchBase = if ($Config -and $Config.Domain) { $Config.Domain.SearchBase } else { '' }

    # Collect the OU RDNs from the DN (force an array so single-OU DNs don't get
    # indexed as a string, which would return a single character).
    $ous = @([regex]::Matches($DistinguishedName, 'OU=([^,]+)') | ForEach-Object { $_.Groups[1].Value })
    if ($ous.Count -eq 0) { return '(root)' }

    if ($searchBase) {
        $baseOus = @([regex]::Matches($searchBase, 'OU=([^,]+)') | ForEach-Object { $_.Groups[1].Value })
        # The ou is the OU immediately "above" (outside) the base, i.e. the last
        # OU in the DN that is NOT part of the base.
        $ouCandidates = @($ous | Where-Object { $baseOus -notcontains $_ })
        if ($ouCandidates.Count -gt 0) { return $ouCandidates[-1] }
    }

    # Fallback (no SearchBase configured): assume the outermost OU is a container
    # such as OU=Ous and the ou is the OU one level inside it.
    if ($ous.Count -ge 2) { return $ous[-2] }
    return $ous[-1]
}
