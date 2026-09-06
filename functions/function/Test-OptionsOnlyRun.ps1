<#
.SYNOPSIS
    True when the GUI is set to change account options only, without touching passwords.
.DESCRIPTION
    Both boxes must be ticked: "Change account options on selected" (otherwise there is
    nothing to apply) and "No password change - only account options".
#>
function Test-OptionsOnlyRun {
    [CmdletBinding()] param()

    $c = $script:App.Controls
    if (-not $c -or -not $c.ChkNoPassword) { return $false }

    return ([bool]$c.ChkChangeOptions.IsChecked -and [bool]$c.ChkNoPassword.IsChecked)
}
