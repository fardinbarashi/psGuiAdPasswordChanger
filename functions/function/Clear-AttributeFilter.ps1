<#
.SYNOPSIS
    Empties the attribute filter boxes and shows every user in the tree again.
#>
function Clear-AttributeFilter {
    [CmdletBinding()]
    param([switch]$KeepText)

    $c = $script:App.Controls
    if (-not $KeepText) {
        foreach ($i in 1..3) {
            if ($c["TxtAttr$i"]) { $c["TxtAttr$i"].Text = '' }
            if ($c["TxtVal$i"])  { $c["TxtVal$i"].Text  = '' }
        }
    }

    $script:App.AttrFilterDns = $null
    if ($c.TxtAttrInfo) { $c.TxtAttrInfo.Text = 'No attribute filter active.' }
    Update-UserFilter
}
