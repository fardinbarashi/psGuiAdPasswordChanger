<#
.SYNOPSIS
    Offline sample data (generic OU model) so the GUI can be demonstrated without a
    live domain. Enabled by config Demo.Enabled or auto-fallback when AD is missing.
.NOTES
    The OU names are deliberately generic (Staff / IT). The application makes no
    assumption about what kind of organisation the domain belongs to.
#>
function Get-DemoData {
    [CmdletBinding()]
    param(
        [ValidateSet('ChildOus', 'Users')] [string]$Level,
        [string]$Parent
    )

    $root  = 'DC=env,DC=local'
    $dcOu  = "OU=Domain Controllers,$root"
    $demo  = "OU=DEMO,$root"
    $staff = "OU=Staff,$root"
    $it    = "OU=IT,$staff"

    switch ($Level) {
        'ChildOus' {
            switch ($Parent) {
                $root { return @(
                    [pscustomobject]@{ Name='Domain Controllers'; DistinguishedName=$dcOu;  Count=0  },
                    [pscustomobject]@{ Name='DEMO';               DistinguishedName=$demo;  Count=20 },
                    [pscustomobject]@{ Name='Staff';              DistinguishedName=$staff; Count=7  }
                ) }
                $staff { return @(
                    [pscustomobject]@{ Name='IT'; DistinguishedName=$it; Count=4 }
                ) }
                default { return @() }
            }
        }
        'Users' {
            $rows = switch ($Parent) {
                $demo {
                    @(
                        @{ N='Anders Olsson';     En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-11-03' },
                        @{ N='Anna Johansson';    En=$true;  Lo=$false; Pne=$true;  Exp=$false; D=$null; AAD='2027-06-30' },
                        @{ N='Daniel Jakobsson';  En=$true;  Lo=$false; Pne=$false; Exp=$true;  D=$null },
                        @{ N='Elin Jonsson';      En=$false; Lo=$false; Pne=$false; Exp=$false; D='2026-09-15'; AExp=$true },
                        @{ N='Emma Persson';      En=$true;  Lo=$true;  Pne=$false; Exp=$false; D='2026-10-20' },
                        @{ N='Erik Andersson';    En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-12-01'; AAD='2026-12-31' },
                        @{ N='Fredrik Pettersson';En=$true;  Lo=$false; Pne=$false; Exp=$true;  D=$null },
                        @{ N='Ida Lindberg';      En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-09-30' },
                        @{ N='Johan Karlsson';    En=$false; Lo=$true;  Pne=$false; Exp=$false; D='2026-11-11' },
                        @{ N='Julia Magnusson';   En=$true;  Lo=$false; Pne=$true;  Exp=$false; D=$null },
                        @{ N='Karl Eriksson';     En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2027-01-15' },
                        @{ N='Klara Berg';        En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-10-05' },
                        @{ N='Lars Bengtsson';    En=$true;  Lo=$false; Pne=$false; Exp=$true;  D=$null },
                        @{ N='Lena Gustafsson';   En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-12-22' },
                        @{ N='Maria Nilsson';     En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-11-28' },
                        @{ N='Mikael Jansson';    En=$false; Lo=$false; Pne=$false; Exp=$false; D='2026-09-18' },
                        @{ N='Nils Lindqvist';    En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2027-02-01' },
                        @{ N='Per Svensson';      En=$true;  Lo=$true;  Pne=$false; Exp=$true;  D=$null },
                        @{ N='Sara Larsson';      En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-10-12' },
                        @{ N='Sofia Hansson';     En=$true;  Lo=$false; Pne=$true;  Exp=$false; D=$null }
                    )
                }
                $staff {
                    @(
                        @{ N='Oscar Ek';    En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-11-09' },
                        @{ N='Wilma Holm';  En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-12-14' },
                        @{ N='Hugo Falk';   En=$false; Lo=$false; Pne=$false; Exp=$true;  D=$null }
                    )
                }
                $it {
                    @(
                        @{ N='Alva Berg';   En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-10-01' },
                        @{ N='Liam Ahl';    En=$true;  Lo=$false; Pne=$false; Exp=$false; D='2026-11-19' },
                        @{ N='Ebba Ros';    En=$true;  Lo=$true;  Pne=$false; Exp=$false; D='2026-09-25' },
                        @{ N='Noah Ceder';  En=$true;  Lo=$false; Pne=$false; Exp=$true;  D=$null }
                    )
                }
                default { @() }
            }

            return $rows | ForEach-Object {
                $sam = ($_.N -replace '[^A-Za-z]','').ToLower()
                $exp = $null
                if ($_.D) { $exp = [datetime]::ParseExact($_.D, 'yyyy-MM-dd', $null) }
                $aexp = $null
                if ($_.AAD) { $aexp = [datetime]::ParseExact($_.AAD, 'yyyy-MM-dd', $null) }
                [pscustomobject]@{
                    Name                 = $_.N
                    SamAccountName       = $sam
                    Account              = "$sam@env.local"
                    DistinguishedName    = "CN=$($_.N),$Parent"
                    Enabled              = $_.En
                    LockedOut            = $_.Lo
                    PasswordNeverExpires = $_.Pne
                    PasswordExpired      = $_.Exp
                    PasswordExpiryDate   = $exp
                    AccountExpired       = [bool]$_.AExp
                    AccountExpiryDate    = $aexp
                }
            }
        }
    }
}
