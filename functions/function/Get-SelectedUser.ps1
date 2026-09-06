<#
.SYNOPSIS
    Returns the user objects for all checked + visible user nodes in the tree.
#>
function Get-SelectedUser {
    [CmdletBinding()] param()

    $users = New-Object System.Collections.Generic.List[object]
    $seen     = New-Object System.Collections.Generic.HashSet[string]

    # From the OU tree.
    foreach ($item in (Get-TreeItem -Parent $script:App.Controls.TreeAd -OnlyLoaded)) {
        $meta = $item.Tag
        if ($meta.Type -ne 'User') { continue }
        if ($item.Visibility -ne [System.Windows.Visibility]::Visible) { continue }
        if ($meta.CheckBox -and $meta.CheckBox.IsChecked -eq $true) {
            if ($seen.Add([string]$meta.User.DistinguishedName)) { $users.Add($meta.User) }
        }
    }

    # From the global search results (checked entries), regardless of panel visibility.
    if ($script:App.Controls.LstSearch) {
        foreach ($cb in $script:App.Controls.LstSearch.Items) {
            if ($cb -is [System.Windows.Controls.CheckBox] -and $cb.IsChecked -eq $true -and $cb.Tag) {
                if ($seen.Add([string]$cb.Tag.DistinguishedName)) { $users.Add($cb.Tag) }
            }
        }
    }

    return $users.ToArray()
}
