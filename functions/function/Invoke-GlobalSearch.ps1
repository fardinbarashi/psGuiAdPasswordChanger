<#
.SYNOPSIS
    Runs the global directory search and shows the results (with checkboxes) in the
    left panel. Checked results feed into the same selection used by the run buttons.
#>
function Invoke-GlobalSearch {
    [CmdletBinding()] param()
    $c = $script:App.Controls

    $term = $c.TxtGlobalSearch.Text
    if ($term -eq [string]$c.TxtGlobalSearch.Tag) { $term = '' }
    $term = $term.Trim()
    if ([string]::IsNullOrWhiteSpace($term)) {
        [System.Windows.MessageBox]::Show('Type something to search for.', 'Search',
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        return
    }
    if (-not $script:App.Policy) {
        [System.Windows.MessageBox]::Show('Connect to AD first (Connect & Load AD).', 'Not connected',
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    try {
        $c.BtnSearch.IsEnabled = $false
        $script:App.Window.Cursor = [System.Windows.Input.Cursors]::Wait
        Write-AppLog ("Searching directory for '{0}'..." -f $term) 'INFO'
        $found = @(Search-AdUser -Term $term)

        $c.LstSearch.Items.Clear()
        foreach ($user in $found) {
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Margin = '2'
            $cb.Tag = $user

            $tags = (Get-UserStatusTag -User $user | ForEach-Object { $_.Text }) -join ' '
            $label = ('{0} ({1})   -   {2}' -f $user.Name, $user.SamAccountName, $user.Account)
            if ($tags) { $label = "$label   $tags" }
            $cb.Content = $label
            if (-not $user.Enabled) { $cb.Foreground = [System.Windows.Media.Brushes]::Gray }

            $cb.Add_Click({ Update-SelectedCount })
            [void]$c.LstSearch.Items.Add($cb)
        }

        $c.TxtSearchInfo.Text = ("{0} match(es) for '{1}'. Tick people to include them in the run." -f $found.Count, $term)
        $c.TreeAd.Visibility          = [System.Windows.Visibility]::Collapsed
        $c.PnlSearchResults.Visibility= [System.Windows.Visibility]::Visible
        $c.BtnSearchClear.Visibility  = [System.Windows.Visibility]::Visible
        Write-AppLog ("Search returned {0} result(s)." -f $found.Count) 'INFO'
        Update-SelectedCount
    }
    catch {
        Write-AppLog ("Search failed: {0}" -f $_.Exception.Message) 'ERROR'
    }
    finally {
        $c.BtnSearch.IsEnabled = $true
        $script:App.Window.Cursor = $null
    }
}
