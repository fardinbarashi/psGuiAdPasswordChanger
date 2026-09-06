<#
.SYNOPSIS
    Applies the Show (active/disabled) dropdown and the attribute filter to the
    visibility of loaded user nodes in the OU tree.
.NOTES
    Hidden users are also excluded from Get-SelectedUser, so a filtered-out account can
    never be picked up by a run by accident.
#>
function Update-UserFilter {
    [CmdletBinding()] param()

    $c = $script:App.Controls

    $showIdx = $c.CmbShow.SelectedIndex   # 0 all, 1 active, 2 disabled
    $dnSet   = $script:App.AttrFilterDns  # $null when no attribute filter is active

    foreach ($item in (Get-TreeItem -Parent $c.TreeAd -OnlyLoaded)) {
        $meta = $item.Tag
        if ($meta.Type -ne 'User') { continue }
        $user = $meta.User
        $visible = $true

        # Status
        if ($showIdx -eq 1 -and -not $user.Enabled) { $visible = $false }
        if ($showIdx -eq 2 -and $user.Enabled)      { $visible = $false }

        # Attribute filter
        if ($visible -and $dnSet -and -not $dnSet.Contains([string]$user.DistinguishedName)) {
            $visible = $false
        }

        $item.Visibility = if ($visible) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    }

    Update-SelectedCount
}
