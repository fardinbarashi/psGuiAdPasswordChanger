<#
.SYNOPSIS
    Loads every external module / assembly the application depends on.
.DESCRIPTION
    Kept in the modules folder so that all required-module handling lives in one
    place and the loader stays minimal. Works on Windows PowerShell 5.1 and
    PowerShell 7+ (WPF + ActiveDirectory).
#>
function Import-AppModules {
    [CmdletBinding()]
    param()

    # --- WPF / XAML assemblies ---------------------------------------------
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName PresentationCore      -ErrorAction Stop
        Add-Type -AssemblyName WindowsBase           -ErrorAction Stop
        Add-Type -AssemblyName System.Xaml           -ErrorAction Stop
        Add-Type -AssemblyName System.Windows.Forms  -ErrorAction Stop
    }
    catch {
        throw "Unable to load the WPF assemblies. On PowerShell 7 make sure you are on Windows with the Desktop runtime. $($_.Exception.Message)"
    }

    # --- ActiveDirectory module -------------------------------------------
    # Not fatal: the app can still start in demo mode without it.
    $adAvailable = $false
    if (Get-Module -Name ActiveDirectory -ListAvailable -ErrorAction SilentlyContinue) {
        try {
            if (-not (Get-Module -Name ActiveDirectory)) {
                # -UseWindowsPowerShell keeps AD working under PowerShell 7 via the
                # Windows PowerShell compatibility session when needed.
                if ($PSVersionTable.PSVersion.Major -ge 6) {
                    Import-Module ActiveDirectory -UseWindowsPowerShell -ErrorAction Stop -WarningAction SilentlyContinue
                }
                else {
                    Import-Module ActiveDirectory -ErrorAction Stop
                }
            }
            $adAvailable = $true
        }
        catch {
            $adAvailable = $false
        }
    }

    return [pscustomobject]@{
        WpfLoaded          = $true
        ActiveDirectory    = $adAvailable
        PSVersion          = $PSVersionTable.PSVersion.ToString()
    }
}
