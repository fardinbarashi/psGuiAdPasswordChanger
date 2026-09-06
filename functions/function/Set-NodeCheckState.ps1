<#
.SYNOPSIS
    Propagates a checkbox state to all descendant nodes (lazy-loading them first
    so that checking a ou really selects every user underneath).
#>
function Set-NodeCheckState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [System.Windows.Controls.TreeViewItem]$Item,
        [Parameter(Mandatory)] [bool]$IsChecked
    )

    $meta = $Item.Tag
    if ($null -eq $meta -or $meta.Type -eq '__dummy') { return }

    # Load children so the whole subtree can be selected.
    if ($meta.Type -ne 'User' -and $IsChecked -and -not $meta.Loaded) {
        Expand-TreeNode -Item $Item
        $Item.IsExpanded = $true
    }

    $script:App.Suppress++
    try {
        foreach ($child in $Item.Items) {
            if (-not ($child -is [System.Windows.Controls.TreeViewItem])) { continue }
            $cmeta = $child.Tag
            if ($null -eq $cmeta -or $cmeta.Type -eq '__dummy') { continue }
            if ($cmeta.CheckBox) { $cmeta.CheckBox.IsChecked = $IsChecked }
            Set-NodeCheckState -Item $child -IsChecked $IsChecked
        }
    }
    finally {
        $script:App.Suppress--
    }
}
