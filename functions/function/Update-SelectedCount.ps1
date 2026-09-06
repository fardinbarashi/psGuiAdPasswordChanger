<#
.SYNOPSIS
    Refreshes the "Selected users: N" label.
#>
function Update-SelectedCount {
    [CmdletBinding()] param()
    $n = (Get-SelectedUser).Count
    $script:App.Controls.TxtSelectedCount.Text = "Selected users: $n"
}
