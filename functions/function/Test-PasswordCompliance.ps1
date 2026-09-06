<#
.SYNOPSIS
    Validates a password against the effective domain policy.
.OUTPUTS
    [pscustomobject] with Ok (bool) and Reasons (string[]).
#>
function Test-PasswordCompliance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Password,
        [Parameter(Mandatory)] [object]$Policy
    )

    $reasons = New-Object System.Collections.Generic.List[string]

    if ($Password.Length -lt $Policy.MinPasswordLength) {
        $reasons.Add(("Too short (min {0})" -f $Policy.MinPasswordLength))
    }

    if ($Policy.ComplexityEnabled) {
        $categories = 0
        if ($Password -cmatch '[A-Z]')                    { $categories++ }
        if ($Password -cmatch '[a-z]')                    { $categories++ }
        if ($Password -match  '[0-9]')                    { $categories++ }
        if ($Password -match  '[^a-zA-Z0-9]')             { $categories++ }
        if ($categories -lt 3) {
            $reasons.Add("Does not meet 3-of-4 character categories")
        }
    }

    return [pscustomobject]@{
        Ok      = ($reasons.Count -eq 0)
        Reasons = $reasons.ToArray()
    }
}
