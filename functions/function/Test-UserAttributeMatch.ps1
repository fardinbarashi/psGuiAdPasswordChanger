<#
.SYNOPSIS
    Local version of the attribute filter: does this user object match every row?
.DESCRIPTION
    Used in demo mode, where there is no directory to run the LDAP filter against.
    Same semantics as the LDAP path: an empty value means "the attribute must have
    some value", '*' is a wildcard, '?' is treated as '*', and all rows must match.
#>
function Test-UserAttributeMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$User,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Pairs
    )

    foreach ($p in $Pairs) {
        $prop = $User.PSObject.Properties[$p.Attribute]
        if (-not $prop) { return $false }

        $value = [string]$prop.Value
        if ([string]::IsNullOrWhiteSpace($value)) { return $false }

        if (-not [string]::IsNullOrWhiteSpace($p.Value)) {
            $pattern = [string]$p.Value -replace '\?', '*'
            if ($value -notlike $pattern) { return $false }
        }
    }

    return $true
}
