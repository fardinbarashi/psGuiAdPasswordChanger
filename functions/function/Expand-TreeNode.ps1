<#
.SYNOPSIS
    Lazy-loads an OU node the first time it is expanded: adds its child OUs and the
    users that sit directly in it (no "class" grouping).
#>
function Expand-TreeNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Windows.Controls.TreeViewItem]$Item,
        [switch]$Force
    )

    $meta = $Item.Tag
    if ($null -eq $meta -or $meta.Type -eq '__dummy' -or $meta.Type -eq 'User') { return }
    if ($meta.Loaded) { return }

    $Item.Items.Clear()   # remove placeholder

    try {
        $script:App.Window.Cursor = [System.Windows.Input.Cursors]::Wait

        # Child OUs first.
        $childOus = @(Get-AdChildOu -ParentDN $meta.DN)
        foreach ($ou in $childOus) {
            [void]$Item.Items.Add((New-TreeNode -Node $ou -Type 'OU'))
        }

        # Then users directly in this OU.
        $users = @(Get-AdOuUser -OuDN $meta.DN -Scope OneLevel)
        foreach ($user in $users) {
            $user | Add-Member -NotePropertyName 'Ou' -NotePropertyValue (Get-TopOuFromDn -DistinguishedName $user.DistinguishedName) -Force
            [void]$Item.Items.Add((New-TreeNode -Node $user -Type 'User'))
        }

        Write-AppLog ("Loaded '{0}': {1} sub-OU(s), {2} user(s)." -f $meta.Name, $childOus.Count, $users.Count) 'DEBUG'
        $meta.Loaded = $true
        $Item.Tag = $meta
    }
    catch {
        Write-AppLog ("Failed to expand '{0}': {1}" -f $meta.Name, $_.Exception.Message) 'ERROR'
    }
    finally {
        $script:App.Window.Cursor = $null
    }

    Update-UserFilter
}
