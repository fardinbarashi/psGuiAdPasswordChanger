<#
.SYNOPSIS
    Reads the three attribute/value rows of the tree filter from the GUI.
.DESCRIPTION
    A row counts only when the attribute box is filled in. An empty value box means
    "the attribute must have some value" rather than "match everything".
.OUTPUTS
    Array of [pscustomobject] @{ Attribute; Value }.
#>
function Get-AttributeFilter {
    [CmdletBinding()] param()

    $c = $script:App.Controls
    $pairs = New-Object System.Collections.Generic.List[object]
    if (-not $c) { return $pairs.ToArray() }

    foreach ($i in 1..3) {
        $attrBox = $c["TxtAttr$i"]
        $valBox  = $c["TxtVal$i"]
        if (-not $attrBox) { continue }

        $attr = ([string]$attrBox.Text).Trim()
        $val  = ([string]$valBox.Text).Trim()
        if ([string]::IsNullOrWhiteSpace($attr)) { continue }

        $pairs.Add([pscustomobject]@{ Attribute = $attr; Value = $val })
    }

    return $pairs.ToArray()
}
