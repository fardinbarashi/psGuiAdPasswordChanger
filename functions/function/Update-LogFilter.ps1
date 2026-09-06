<#
.SYNOPSIS
    Rebuilds the log box from the in-memory log lines, filtered by the search text.
#>
function Update-LogFilter {
    [CmdletBinding()] param()
    $c = $script:App.Controls

    $search = ''
    if ($c.TxtLogSearch.Text -and $c.TxtLogSearch.Text -ne $c.TxtLogSearch.Tag) {
        $search = $c.TxtLogSearch.Text.Trim().ToLower()
    }

    $lines = $script:App.LogLines
    if ($search) {
        $lines = $lines | Where-Object { $_.Text.ToLower().Contains($search) }
    }

    $c.LogBox.Text = (($lines | ForEach-Object { $_.Text }) -join [Environment]::NewLine)
    $c.LogBox.ScrollToEnd()
}
