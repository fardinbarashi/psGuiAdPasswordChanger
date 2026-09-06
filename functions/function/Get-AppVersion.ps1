<#
.SYNOPSIS
    Reads settings\version.json and returns the application version.
.DESCRIPTION
    The file is the single place the version lives, so bumping a release means editing
    version.json only - no code change. A missing or unreadable file is not fatal: the
    application still starts and simply reports an unknown version.
.OUTPUTS
    [pscustomobject] with VersionLabel, Description and Link.
#>
function Get-AppVersion {
    [CmdletBinding()]
    param(
        [string]$Root = $script:App.Root
    )

    # Nested Join-Path so the same code works when the sandbox tests run on Linux.
    $path = Join-Path (Join-Path $Root 'settings') 'version.json'

    $label = 'unknown'
    $desc  = ''
    $link  = ''

    if (Test-Path $path) {
        try {
            $raw = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
            $v   = if ($raw.PSObject.Properties['Version']) { $raw.Version } else { $raw }

            if ($v.PSObject.Properties['VersionLabel'] -and $v.VersionLabel) { $label = [string]$v.VersionLabel }
            if ($v.PSObject.Properties['Description'])                       { $desc  = [string]$v.Description }
            # The key is lower case in version.json; match it case-insensitively anyway.
            foreach ($p in $v.PSObject.Properties) {
                if ($p.Name -ieq 'link' -and $p.Value) { $link = [string]$p.Value }
            }
        }
        catch {
            Write-AppLog ("Could not read version.json: {0}" -f $_.Exception.Message) 'WARN'
        }
    }
    else {
        Write-AppLog 'settings\version.json is missing - version reported as unknown.' 'WARN'
    }

    return [pscustomobject]@{
        VersionLabel = $label
        Description  = $desc
        Link         = $link
    }
}
