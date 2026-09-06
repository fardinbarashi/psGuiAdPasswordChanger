<#
.SYNOPSIS
    Reads the generator panel controls into a hashtable for New-CompliantPassword /
    Invoke-PasswordRun. When "Override" is off, returns an empty hashtable so config
    defaults are used.
#>
function Get-GuiGeneratorSetting {
    [CmdletBinding()] param()
    $c = $script:App.Controls

    # A password in the box is used for everyone ONLY when "Same password for all"
    # is checked (otherwise the box is just a sample preview).
    $fixed = $null
    $sampleText = $c.TxtSample.Text
    if ($c.ChkSameAll.IsChecked -and $sampleText -and $sampleText -ne [string]$c.TxtSample.Tag) {
        $fixed = $sampleText.Trim()
    }

    if (-not $c.ChkOverride.IsChecked) {
        # Still honour "same password for all" (and a typed fixed password) without full override.
        return @{ SamePasswordForAll = [bool]$c.ChkSameAll.IsChecked; FixedPassword = $fixed }
    }

    $len = 12
    if ($c.TxtLength.Text -as [int]) { $len = [int]$c.TxtLength.Text }

    return @{
        Length             = $len
        UseUpper           = [bool]$c.ChkUpper.IsChecked
        UseLower           = [bool]$c.ChkLower.IsChecked
        UseDigit           = [bool]$c.ChkDigit.IsChecked
        UseSpecial         = [bool]$c.ChkSpecial.IsChecked
        SpecialChars       = $script:App.Config.Generator.SpecialChars
        SamePasswordForAll = [bool]$c.ChkSameAll.IsChecked
        FixedPassword      = $fixed
    }
}
