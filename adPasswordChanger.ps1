#Requires -Version 5.1
<#
.SYNOPSIS
    Minimal launcher for psGuiAdPasswordChanger.
.DESCRIPTION
    Keeps almost no logic of its own: it guarantees an STA thread (required by WPF),
    dot-sources every module and function file, loads config + logging and shows the
    GUI. All real work lives in .\modules and .\functions\function.

    Runs on PowerShell 7 (recommended) and Windows PowerShell 5.1 on Windows.
.EXAMPLE
    pwsh -STA -File .\adPasswordChanger.ps1
#>
[CmdletBinding()]
param()

# Files copied from a zip are blocked by Windows - unblock the whole folder first.
Get-ChildItem -Path $PSScriptRoot -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

$ErrorActionPreference = 'Stop'

# --- Ensure a single-threaded apartment (WPF requirement) -------------------
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    $exe = $null
    try { $exe = (Get-Process -Id $PID).Path } catch { }
    if (-not $exe) { $exe = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'powershell' } }
    Write-Host 'Relaunching in STA mode for WPF...' -ForegroundColor Cyan
    & $exe -NoProfile -STA -ExecutionPolicy Bypass -File $PSCommandPath @args
    return
}

# --- Paths & shared state ---------------------------------------------------
$root = Split-Path -Parent $PSCommandPath
$script:App = @{
    Root     = $root
    LogLines = New-Object System.Collections.ArrayList
}

# --- Dot-source everything (loader stays minimal) ---------------------------
$moduleDir   = Join-Path $root 'modules'
$functionDir = Join-Path $root 'functions\function'

if (Test-Path $moduleDir) {
    Get-ChildItem -Path $moduleDir -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object { . $_.FullName }
}
if (Test-Path $functionDir) {
    Get-ChildItem -Path $functionDir -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object { . $_.FullName }
}

# --- Required modules / assemblies ------------------------------------------
$loaded = Import-AppModules
$script:App.AdAvailable = [bool]$loaded.ActiveDirectory

# --- Config + logging -------------------------------------------------------
$script:App.Config = Get-AppConfig -Root $root
Initialize-AppLog -Root $root -Config $script:App.Config | Out-Null

# --- Version (settings\version.json is the single source) --------------------
$script:App.Version = Get-AppVersion -Root $root

Write-AppLog ("psGuiAdPasswordChanger {0} starting - PowerShell {1}, ActiveDirectory available: {2}." -f `
    ('v' + $script:App.Version.VersionLabel), $PSVersionTable.PSVersion, $script:App.AdAvailable) 'INFO'
if ($script:App.Version.Description) { Write-AppLog ("This version: {0}" -f $script:App.Version.Description) 'INFO' }

# --- Go ---------------------------------------------------------------------
Show-MainWindow
