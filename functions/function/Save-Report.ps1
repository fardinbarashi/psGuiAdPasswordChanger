<#
.SYNOPSIS
    Persists HTML + CSV reports (one per top-level OU) and an optional combined report.
    Opens the output folder when configured.
.DESCRIPTION
    Report.OutputFolder in config.json is relative to the script root by default
    ('files\report'), so reports stay next to the application. An absolute path
    (for example 'D:\Reports') is still honoured as-is. The legacy default
    'C:\Temp\psGuiAdPasswordChanger\files\report' is mapped to the local
    'files\report' folder so old config files keep working.
#>
function Save-Report {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]]$Results,
        [bool]$WhatIf = $true,
        [bool]$Combined = $false,
        [bool]$OptionsOnly = $false,
        [object]$Config = $script:App.Config
    )

    $defaultFolder = 'files\report'
    $legacyFolder  = 'C:\Temp\psGuiAdPasswordChanger\files\report'

    $outFolder = $Config.Report.OutputFolder
    if ([string]::IsNullOrWhiteSpace($outFolder)) {
        $outFolder = $defaultFolder
    }

    # Old config files pointed at C:\Temp - keep them working by using the local folder.
    if ($outFolder.TrimEnd('\', '/') -ieq $legacyFolder) {
        $outFolder = $defaultFolder
    }

    # Relative paths are resolved against the application root (same rule as the log folder).
    if (-not [System.IO.Path]::IsPathRooted($outFolder)) {
        $outFolder = Join-Path $script:App.Root $outFolder
    }

    if (-not (Test-Path $outFolder)) {
        New-Item -ItemType Directory -Path $outFolder -Force | Out-Null
    }

    $stamp  = Get-Date -Format 'yyyy-MM-dd_HH-mm'
    # An account-options-only run is marked _Options so it is never mistaken for a
    # password run when someone browses the report folder later.
    $kind   = if ($OptionsOnly) { '_Options' } else { '' }
    $suffix = if ($WhatIf) { "${kind}_WhatIf" } else { "${kind}_Live" }
    $written = New-Object System.Collections.Generic.List[string]

    function Get-SafeName([string]$name) {
        $invalid = [IO.Path]::GetInvalidFileNameChars() -join ''
        $re = "[{0}]" -f [regex]::Escape($invalid)
        return (($name -replace $re, '_') -replace '\s+', '_')
    }

    $groups = $Results | Group-Object Ou
    foreach ($grp in $groups) {
        $safe    = Get-SafeName $grp.Name
        $rows    = @($grp.Group)

        $htmlPath = Join-Path $outFolder ("OU_{0}_{1}{2}.html" -f $safe, $stamp, $suffix)
        $csvPath  = Join-Path $outFolder ("OU_{0}_{1}{2}.csv"  -f $safe, $stamp, $suffix)

        (New-HtmlReport -OuName $grp.Name -Results $rows -WhatIf:$WhatIf -OptionsOnly:$OptionsOnly) | Set-Content -Path $htmlPath -Encoding UTF8
        Write-AppLog ("Report saved: {0}" -f $htmlPath) 'INFO'
        [void]$written.Add($htmlPath)

        New-CsvReport -Results $rows -Path $csvPath | Out-Null
        Write-AppLog ("CSV saved: {0}" -f $csvPath) 'INFO'
        [void]$written.Add($csvPath)
    }

    if ($Combined -and $groups.Count -gt 1) {
        $htmlPath = Join-Path $outFolder ("OU_ALL_{0}{1}.html" -f $stamp, $suffix)
        $csvPath  = Join-Path $outFolder ("OU_ALL_{0}{1}.csv"  -f $stamp, $suffix)
        (New-HtmlReport -OuName 'All OUs (combined)' -Results $Results -WhatIf:$WhatIf -OptionsOnly:$OptionsOnly) | Set-Content -Path $htmlPath -Encoding UTF8
        New-CsvReport -Results $Results -Path $csvPath | Out-Null
        Write-AppLog ("Combined report saved: {0}" -f $htmlPath) 'INFO'
        [void]$written.Add($htmlPath); [void]$written.Add($csvPath)
    }

    if ($Config.Report.OpenAfterRun -and -not $script:App.DemoMode) {
        try { Start-Process -FilePath $outFolder } catch { }
    }

    return [pscustomobject]@{ Folder = $outFolder; Files = $written.ToArray() }
}
