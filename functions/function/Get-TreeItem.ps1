<#
.SYNOPSIS
    Recursively enumerates TreeViewItems under a parent (TreeView or TreeViewItem).
    Skips lazy placeholders.
#>
function Get-TreeItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Parent,
        [switch]$OnlyLoaded
    )

    $result = New-Object System.Collections.Generic.List[object]

    foreach ($child in $Parent.Items) {
        if (-not ($child -is [System.Windows.Controls.TreeViewItem])) { continue }
        $meta = $child.Tag
        if ($meta -and $meta.Type -eq '__dummy') { continue }

        $result.Add($child)

        if ($child.Items.Count -gt 0) {
            if ($OnlyLoaded -and $meta -and -not $meta.Loaded) { continue }
            foreach ($g in (Get-TreeItem -Parent $child -OnlyLoaded:$OnlyLoaded)) {
                $result.Add($g)
            }
        }
    }

    return $result
}
