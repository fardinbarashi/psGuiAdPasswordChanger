<#
.SYNOPSIS
    Prepares the daily log file and cleans up old logs.
#>
function Initialize-AppLog {
    [CmdletBinding()]
    param(
        [string]$Root = $script:App.Root,
        [object]$Config = $script:App.Config
    )

    $folderName = 'logs'
    $retention  = 30
    if ($Config -and $Config.Logging) {
        if ($Config.Logging.Folder)        { $folderName = $Config.Logging.Folder }
        if ($Config.Logging.RetentionDays) { $retention  = [int]$Config.Logging.RetentionDays }
    }

    $logDir = if ([System.IO.Path]::IsPathRooted($folderName)) { $folderName } else { Join-Path $Root $folderName }
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $stamp   = Get-Date -Format 'yyyy-MM-dd'
    $logFile = Join-Path $logDir ("psGuiAdPasswordChanger_{0}.log" -f $stamp)

    # Retention cleanup
    if ($retention -gt 0) {
        $cutoff = (Get-Date).AddDays(-$retention)
        Get-ChildItem -Path $logDir -Filter 'psGuiAdPasswordChanger_*.log' -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    $script:App.LogFile = $logFile
    return $logFile
}
