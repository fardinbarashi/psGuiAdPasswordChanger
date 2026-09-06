<#
.SYNOPSIS
    Applies the attribute filter: works out which accounts in the domain match the
    attribute/value rows, then hides every user node in the tree that is not one of them.
.DESCRIPTION
    The matching itself is done by Active Directory through one LDAP query, so any
    attribute the schema has can be used - not only the ones the application reads for
    its own columns. '*' is passed straight through as an LDAP wildcard and '?' is
    mapped to '*' (LDAP has no single-character wildcard). An empty value becomes
    (attribute=*), i.e. "the attribute is filled in at all".

    All filled rows are combined with AND. Demo mode has no directory to query, so the
    rows are matched against the properties of the sample objects instead.
#>
function Invoke-AttributeFilter {
    [CmdletBinding()] param()

    $c     = $script:App.Controls
    $pairs = @(Get-AttributeFilter)

    if ($pairs.Count -eq 0) {
        Clear-AttributeFilter -KeepText
        Write-AppLog 'Attribute filter cleared (no attribute name entered).' 'INFO'
        return
    }

    # Build (and thereby validate) the LDAP filter before touching the directory.
    try   { $ldap = New-AttributeLdapFilter -Pairs $pairs }
    catch {
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Invalid attribute',
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    $describe = (($pairs | ForEach-Object {
        if ($_.Value) { '{0}={1}' -f $_.Attribute, $_.Value } else { '{0}=<any value>' -f $_.Attribute }
    }) -join ' AND ')

    $dns = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)

    try {
        $script:App.Window.Cursor = [System.Windows.Input.Cursors]::Wait
        $c.BtnAttrFilter.IsEnabled = $false

        if ($script:App.DemoMode) {
            # No directory available - match the sample objects property by property.
            foreach ($item in (Get-TreeItem -Parent $c.TreeAd -OnlyLoaded)) {
                $meta = $item.Tag
                if ($meta.Type -ne 'User') { continue }
                $user = $meta.User
                if (Test-UserAttributeMatch -User $user -Pairs $pairs) {
                    [void]$dns.Add([string]$user.DistinguishedName)
                }
            }
        }
        else {
            $common = @{ ErrorAction = 'Stop' }
            if ($script:App.Config.Domain.Server) { $common.Server = $script:App.Config.Domain.Server }
            $searchBase = $script:App.Config.Domain.SearchBase
            if ([string]::IsNullOrWhiteSpace($searchBase)) {
                try { $searchBase = (Get-ADDomain @common).DistinguishedName } catch { }
            }
            if ($searchBase) { $common.SearchBase = $searchBase; $common.SearchScope = 'Subtree' }

            Write-AppLog ("Attribute filter: querying AD for {0}" -f $describe) 'INFO'
            foreach ($u in (Get-ADUser -LDAPFilter $ldap @common)) {
                [void]$dns.Add([string]$u.DistinguishedName)
            }
        }
    }
    catch {
        Write-AppLog ("Attribute filter failed: {0}" -f $_.Exception.Message) 'ERROR'
        [System.Windows.MessageBox]::Show(
            ("The attribute filter could not be applied:`n{0}`n`nCheck that the attribute name exists in your AD schema." -f $_.Exception.Message),
            'Filter failed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }
    finally {
        $c.BtnAttrFilter.IsEnabled = $true
        $script:App.Window.Cursor  = $null
    }

    $script:App.AttrFilterDns = $dns
    Update-UserFilter

    $shown = @(Get-TreeItem -Parent $c.TreeAd -OnlyLoaded | Where-Object {
        $_.Tag.Type -eq 'User' -and $_.Visibility -eq [System.Windows.Visibility]::Visible
    }).Count

    $c.TxtAttrInfo.Text = ("Filter: {0} - {1} match(es) in the domain, {2} of them visible in the loaded part of the tree." -f `
        $describe, $dns.Count, $shown)
    Write-AppLog ("Attribute filter applied: {0} - {1} match(es), {2} visible in the tree." -f $describe, $dns.Count, $shown) 'INFO'

    if ($dns.Count -gt 0 -and $shown -eq 0) {
        Write-AppLog 'No matching account is loaded yet - expand the OUs you want to see, or use the search box above.' 'WARN'
    }
}
