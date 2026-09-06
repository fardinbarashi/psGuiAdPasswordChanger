<#
.SYNOPSIS
    Turns the attribute/value rows of the tree filter into one LDAP filter string.
.DESCRIPTION
    '*' is passed through as an LDAP wildcard, '?' is mapped to '*' (LDAP has no
    single-character wildcard) and the remaining LDAP special characters are escaped.
    An empty value becomes (attribute=*) - "the attribute is filled in at all".
    All rows are combined with AND.
.OUTPUTS
    [string] LDAP filter.
#>
function New-AttributeLdapFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Pairs
    )

    $clauses = foreach ($p in $Pairs) {
        # The attribute name goes straight into the filter, so accept schema names only.
        if ($p.Attribute -notmatch '^[A-Za-z][A-Za-z0-9-]*$') {
            throw ("'{0}' is not a valid AD attribute name. Use the LDAP name, for example sAMAccountName, department, title or physicalDeliveryOfficeName." -f $p.Attribute)
        }

        if ([string]::IsNullOrWhiteSpace($p.Value)) {
            '({0}=*)' -f $p.Attribute
        }
        else {
            $v = [string]$p.Value -replace '\\', '\5c' -replace '\(', '\28' -replace '\)', '\29' -replace '\?', '*'
            '({0}={1})' -f $p.Attribute, $v
        }
    }

    return ('(&(objectCategory=person)(objectClass=user){0})' -f ($clauses -join ''))
}
