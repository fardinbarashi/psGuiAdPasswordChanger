<#
.SYNOPSIS
    Produces the human-readable "how complex the password must be" text shown in the GUI.
#>
function Get-PasswordPolicyText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Policy
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(("Minimum length: {0} characters" -f $Policy.MinPasswordLength))

    if ($Policy.ComplexityEnabled) {
        $lines.Add("Complexity: ENABLED - the password must contain characters from at least 3 of these 4 groups:")
        $lines.Add("   * Upper case (A-Z)   * Lower case (a-z)   * Digits (0-9)   * Symbols (!@#...)")
        $lines.Add("It must not contain the user's account or display name.")
    }
    else {
        $lines.Add("Complexity: disabled (no category requirement).")
    }

    if ($Policy.PasswordHistory -gt 0) {
        $lines.Add(("Cannot reuse the last {0} passwords." -f $Policy.PasswordHistory))
    }
    if ($Policy.MaxPasswordAgeDays -gt 0) {
        $lines.Add(("Passwords expire after {0} days." -f $Policy.MaxPasswordAgeDays))
    }
    if ($Policy.LockoutThreshold -gt 0) {
        $lines.Add(("Account locks out after {0} failed attempts." -f $Policy.LockoutThreshold))
    }

    return ($lines -join [Environment]::NewLine)
}
