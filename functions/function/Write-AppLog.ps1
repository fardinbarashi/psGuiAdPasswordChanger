<#
.SYNOPSIS
    Central logging: writes to the GUI log box (if present) and the daily log file.
.EXAMPLE
    Write-AppLog "Connected to AD" INFO
#>
function Write-AppLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )

    $now   = Get-Date
    $short = '[{0}] [{1}] {2}' -f $now.ToString('HH:mm:ss'), $Level, $Message
    $full  = '[{0}] [{1}] {2}' -f $now.ToString('yyyy-MM-dd HH:mm:ss'), $Level, $Message

    # --- File --------------------------------------------------------------
    if ($script:App -and $script:App.LogFile) {
        try { Add-Content -Path $script:App.LogFile -Value $full -Encoding UTF8 } catch { }
    }

    # --- Keep an in-memory copy for the log box search/filter --------------
    if ($script:App -and $script:App.LogLines) {
        [void]$script:App.LogLines.Add([pscustomobject]@{ Time = $now; Level = $Level; Text = $short })
    }

    # --- GUI textbox (thread-safe) ----------------------------------------
    if ($script:App -and $script:App.Controls -and $script:App.Controls.LogBox) {
        $box = $script:App.Controls.LogBox
        $action = [System.Action]{
            param($t)
            $box.AppendText($t + [Environment]::NewLine)
            $box.ScrollToEnd()
        }
        try {
            if ($box.Dispatcher.CheckAccess()) {
                $box.AppendText($short + [Environment]::NewLine)
                $box.ScrollToEnd()
            }
            else {
                $box.Dispatcher.Invoke($action, @($short)) | Out-Null
            }
        }
        catch { }
    }

    # --- Console (headless / verbose) -------------------------------------
    switch ($Level) {
        'ERROR' { Write-Host $short -ForegroundColor Red }
        'WARN'  { Write-Host $short -ForegroundColor Yellow }
        'DEBUG' { Write-Verbose $short }
        default { Write-Host $short }
    }
}
