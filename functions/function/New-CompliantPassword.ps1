<#
.SYNOPSIS
    Generates a random password that satisfies the domain GPO password policy.
.DESCRIPTION
    There is NO hard-coded password pattern. The generator only knows the policy
    (minimum length + complexity) and the optional character-set overrides selected
    in the GUI, and guarantees the result satisfies the policy.
.PARAMETER Policy
    Object returned by Get-AdPasswordPolicy.
.PARAMETER Length
    Requested length. Automatically raised to the policy minimum if lower.
.PARAMETER UseUpper / UseLower / UseDigit / UseSpecial
    Character groups to draw from. When complexity is enabled the generator forces
    enough groups on to reach the required 3-of-4 categories.
#>
function New-CompliantPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Policy,
        [int]   $Length      = 12,
        [bool]  $UseUpper    = $true,
        [bool]  $UseLower    = $true,
        [bool]  $UseDigit    = $true,
        [bool]  $UseSpecial  = $false,
        [string]$SpecialChars= '!@#$%&*',
        [bool]  $AvoidAmbiguous = $true
    )

    $upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower   = 'abcdefghijkmnopqrstuvwxyz'
    $digit   = '23456789'
    if (-not $AvoidAmbiguous) {
        $upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        $lower = 'abcdefghijklmnopqrstuvwxyz'
        $digit = '0123456789'
    }
    $special = if ($SpecialChars) { $SpecialChars } else { '!@#$%&*' }

    # Ensure length honours the policy minimum.
    if ($Length -lt $Policy.MinPasswordLength) { $Length = $Policy.MinPasswordLength }
    if ($Length -lt 4) { $Length = 4 }

    # Build the set of enabled groups.
    $groups = @()
    if ($UseUpper)   { $groups += ,@{ Name='U'; Chars=$upper } }
    if ($UseLower)   { $groups += ,@{ Name='L'; Chars=$lower } }
    if ($UseDigit)   { $groups += ,@{ Name='D'; Chars=$digit } }
    if ($UseSpecial) { $groups += ,@{ Name='S'; Chars=$special } }

    # When complexity is on we need at least 3 categories; force groups on in a
    # stable priority order (upper, lower, digit, special) until we have enough.
    if ($Policy.ComplexityEnabled) {
        $needed = [Math]::Min(3, 4)
        $priority = @(
            @{ Name='U'; Chars=$upper },
            @{ Name='L'; Chars=$lower },
            @{ Name='D'; Chars=$digit },
            @{ Name='S'; Chars=$special }
        )
        foreach ($g in $priority) {
            if (($groups | Where-Object { $_.Name -eq $g.Name }).Count -eq 0 -and $groups.Count -lt $needed) {
                $groups += ,$g
            }
        }
    }

    if ($groups.Count -eq 0) {
        # Nothing selected at all - fall back to lower+digit so we still return something usable.
        $groups = @(@{ Name='L'; Chars=$lower }, @{ Name='D'; Chars=$digit })
    }

    # Cryptographically strong RNG.
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        function Get-RandChar([string]$set) {
            $buf = New-Object 'byte[]' 4
            $rng.GetBytes($buf)
            $val = [BitConverter]::ToUInt32($buf, 0)
            return $set[[int]($val % [uint32]$set.Length)]
        }

        $chars = New-Object System.Collections.Generic.List[char]

        # Guarantee at least one from each enabled group.
        foreach ($g in $groups) { $chars.Add((Get-RandChar $g.Chars)) }

        # Fill the rest from the combined pool.
        $pool = -join ($groups | ForEach-Object { $_.Chars })
        while ($chars.Count -lt $Length) { $chars.Add((Get-RandChar $pool)) }

        # Fisher-Yates shuffle so the guaranteed chars are not always at the front.
        for ($i = $chars.Count - 1; $i -gt 0; $i--) {
            $buf = New-Object 'byte[]' 4
            $rng.GetBytes($buf)
            $j = [int]([BitConverter]::ToUInt32($buf, 0) % [uint32]($i + 1))
            $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
        }

        return (-join $chars)
    }
    finally {
        $rng.Dispose()
    }
}
