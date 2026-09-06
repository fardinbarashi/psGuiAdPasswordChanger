<#
.SYNOPSIS
    Fills the grey example box with a sample password produced by the generator,
    proving it satisfies the domain policy.
#>
function Invoke-GenerateSample {
    [CmdletBinding()] param()
    $c = $script:App.Controls

    if (-not $script:App.Policy) {
        $c.TxtSample.Text = 'Connect first to load the policy'
        return
    }

    $g   = Get-GuiGeneratorSetting
    $cfg = $script:App.Config.Generator

    $params = @{
        Policy         = $script:App.Policy
        Length         = if ($g.ContainsKey('Length'))     { $g.Length }     else { [int]$cfg.DefaultLength }
        UseUpper       = if ($g.ContainsKey('UseUpper'))   { $g.UseUpper }   else { [bool]$cfg.UseUpper }
        UseLower       = if ($g.ContainsKey('UseLower'))   { $g.UseLower }   else { [bool]$cfg.UseLower }
        UseDigit       = if ($g.ContainsKey('UseDigit'))   { $g.UseDigit }   else { [bool]$cfg.UseDigit }
        UseSpecial     = if ($g.ContainsKey('UseSpecial')) { $g.UseSpecial } else { [bool]$cfg.UseSpecial }
        SpecialChars   = $cfg.SpecialChars
        AvoidAmbiguous = [bool]$cfg.AvoidAmbiguous
    }

    $sample = New-CompliantPassword @params
    $c.TxtSample.Text = $sample
    # Black: the box is editable and this value will be used for all users when set.
    $c.TxtSample.Foreground = [System.Windows.Media.Brushes]::Black

    $check = Test-PasswordCompliance -Password $sample -Policy $script:App.Policy
    Write-AppLog ("Sample generated (len {0}) - policy compliant: {1}" -f $sample.Length, $check.Ok) 'DEBUG'
}
