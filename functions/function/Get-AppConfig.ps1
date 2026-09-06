<#
.SYNOPSIS
    Loads settings\config\config.json (creating a default if it is missing).
#>
function Get-AppConfig {
    [CmdletBinding()]
    param(
        [string]$Root = $script:App.Root
    )

    $configDir  = Join-Path $Root 'settings\config'
    $configPath = Join-Path $configDir 'config.json'

    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    if (-not (Test-Path $configPath)) {
        $default = [ordered]@{
            Domain     = [ordered]@{ Server=''; SearchBase=''; IncludeEmptyOus=$true }
            Attributes = [ordered]@{ DisplayNameAttribute='displayName' }
            Generator  = [ordered]@{ DefaultLength=12; UseUpper=$true; UseLower=$true; UseDigit=$true; UseSpecial=$false; SpecialChars='!@#$%&*'; AvoidAmbiguous=$true; SamePasswordForAll=$false }
            Report     = [ordered]@{ OutputFolder='files\report'; OpenAfterRun=$true; CombinedReportByDefault=$false }
            Logging    = [ordered]@{ Folder='logs'; RetentionDays=30 }
            Ui         = [ordered]@{ DomainLabel=''; TestModeDefault=$true; ShowDoneDialog=$true }
            Demo       = [ordered]@{ Enabled=$false; AutoFallbackWhenNoAd=$true }
        }
        ($default | ConvertTo-Json -Depth 6) | Set-Content -Path $configPath -Encoding UTF8
    }

    try {
        $cfg = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        throw "Failed to parse config.json: $($_.Exception.Message)"
    }

    $cfg | Add-Member -NotePropertyName '_Path' -NotePropertyValue $configPath -Force
    return $cfg
}
