<#
.SYNOPSIS
    General directory search: finds people anywhere in the domain (not just the
    nodes already loaded in the tree). Matches name, display name and account.
.DESCRIPTION
    Wildcards are supported. Use '*' to match any sequence of characters
    (e.g. "Fardin*", "*konto*", "SA24*"). '?' matches a single character.
    Without a wildcard the term is matched as a "contains" search.
.OUTPUTS
    Array of normalized user objects (with Ou derived from the DN).
#>
function Search-AdUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Term,
        [int]$MaxResults = 300,
        [object]$Config = $script:App.Config
    )

    $Term = $Term.Trim()
    if ([string]::IsNullOrWhiteSpace($Term)) { return @() }

    $hasWildcard = ($Term -match '[\*\?]')

    # ---- Demo mode -------------------------------------------------------
    if ($script:App.DemoMode) {
        $parents = @(
            'OU=DEMO,DC=env,DC=local',
            'OU=Staff,DC=env,DC=local',
            'OU=IT,OU=Staff,DC=env,DC=local'
        )
        $all = foreach ($p in $parents) {
            Get-DemoData -Level Users -Parent $p | ForEach-Object {
                $_ | Add-Member Ou (Get-TopOuFromDn -DistinguishedName $_.DistinguishedName -Config $Config) -Force -PassThru
            }
        }
        # -like handles * and ? natively; wrap a plain term as *term* (contains).
        $pattern = if ($hasWildcard) { $Term } else { "*$Term*" }
        return @($all | Where-Object {
            $_.Name           -like $pattern -or
            $_.SamAccountName -like $pattern -or
            $_.Account        -like $pattern
        } | Select-Object -First $MaxResults)
    }

    # ---- Live AD ---------------------------------------------------------
    $server     = $Config.Domain.Server
    $searchBase = $Config.Domain.SearchBase
    $common = @{ ErrorAction = 'Stop' }
    if ($server) { $common.Server = $server }
    if ([string]::IsNullOrWhiteSpace($searchBase)) {
        try { $searchBase = (Get-ADDomain @common).DistinguishedName } catch { }
    }
    if ($searchBase) { $common.SearchBase = $searchBase; $common.SearchScope = 'Subtree' }

    if ($hasWildcard) {
        # Preserve the user's '*' as an LDAP wildcard; map '?' -> '*' (LDAP has no
        # single-char wildcard). Escape the other LDAP special characters.
        $wild = $Term -replace '\\','\5c' -replace '\(','\28' -replace '\)','\29' -replace '\?','*'
        $ldap = "(&(objectCategory=person)(objectClass=user)(|(name=$wild)(displayName=$wild)(sAMAccountName=$wild)(userPrincipalName=$wild)))"
    }
    else {
        # No wildcard: ANR (ambiguous name resolution) covers name, display name,
        # sAMAccountName and UPN in one go.
        $esc  = $Term -replace '\\','\5c' -replace '\*','\2a' -replace '\(','\28' -replace '\)','\29'
        $ldap = "(&(objectCategory=person)(objectClass=user)(anr=$esc))"
    }

    $props = @('DisplayName','Enabled','LockedOut','PasswordNeverExpires','UserPrincipalName',
               'PasswordExpired','msDS-UserPasswordExpiryTimeComputed','AccountExpirationDate')
    $nameAttr = $Config.Attributes.DisplayNameAttribute
    if ($nameAttr -and $props -notcontains $nameAttr) { $props += $nameAttr }

    $users = Get-ADUser -LDAPFilter $ldap -Properties $props -ResultSetSize $MaxResults @common |
             Sort-Object Name

    return @($users | ConvertTo-UserObject -Config $Config | ForEach-Object {
        $_ | Add-Member Ou (Get-TopOuFromDn -DistinguishedName $_.DistinguishedName -Config $Config) -Force -PassThru
    })
}
