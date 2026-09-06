<#
.SYNOPSIS
    Orchestrates a run over the selected users (Test/What-if or live): password
    reset, account options, or account options only.
.DESCRIPTION
    Order per user matters and is fixed here:
      1. Account options that must happen first (enable, unlock, password never expires)
      2. The password reset itself (unless -SkipPassword)
      3. "Must change password at next logon"

    Step 3 has to come last: Set-ADAccountPassword -Reset stamps pwdLastSet, which
    clears the must-change flag if it was set beforehand.

    Every account produces one INFO line in the log while the run is in progress,
    and the run ends with a summary block.
.OUTPUTS
    Array of result rows (one per user) for the reports.
#>
function Invoke-PasswordRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]]$Users,
        [Parameter(Mandatory)] [object]$Policy,
        [bool]$WhatIf = $true,
        [hashtable]$Generator = @{},
        [bool]$ApplyAccountOptions = $false,
        [hashtable]$AccountOptions = @{},
        [bool]$SkipPassword = $false
    )

    $cfg = $script:App.Config
    $g   = $cfg.Generator

    # Merge generator settings (GUI overrides win, else config defaults).
    $len     = if ($Generator.ContainsKey('Length'))     { [int]$Generator.Length }     else { [int]$g.DefaultLength }
    $useU    = if ($Generator.ContainsKey('UseUpper'))   { [bool]$Generator.UseUpper }  else { [bool]$g.UseUpper }
    $useL    = if ($Generator.ContainsKey('UseLower'))   { [bool]$Generator.UseLower }  else { [bool]$g.UseLower }
    $useD    = if ($Generator.ContainsKey('UseDigit'))   { [bool]$Generator.UseDigit }  else { [bool]$g.UseDigit }
    $useS    = if ($Generator.ContainsKey('UseSpecial')) { [bool]$Generator.UseSpecial }else { [bool]$g.UseSpecial }
    $special = if ($Generator.ContainsKey('SpecialChars')){ [string]$Generator.SpecialChars } else { [string]$g.SpecialChars }
    $sameAll = if ($Generator.ContainsKey('SamePasswordForAll')) { [bool]$Generator.SamePasswordForAll } else { [bool]$g.SamePasswordForAll }
    $avoid   = [bool]$g.AvoidAmbiguous

    $fixed = if ($Generator.ContainsKey('FixedPassword') -and $Generator.FixedPassword) { [string]$Generator.FixedPassword } else { $null }

    $sharedPassword = $null
    if (-not $SkipPassword) {
        if ($fixed) {
            # A password typed in the box is used verbatim for every selected user.
            $sharedPassword = $fixed
            Write-AppLog 'Using the manually entered password for all selected users.' 'INFO'
        }
        elseif ($sameAll) {
            $sharedPassword = New-CompliantPassword -Policy $Policy -Length $len -UseUpper $useU -UseLower $useL -UseDigit $useD -UseSpecial $useS -SpecialChars $special -AvoidAmbiguous $avoid
        }
    }

    # ---- What the run is going to do (used for logging and the report) -------
    $wanted = New-Object System.Collections.Generic.List[string]
    if ($ApplyAccountOptions) {
        if ($AccountOptions.ContainsKey('Enabled')) {
            $wanted.Add($(if([bool]$AccountOptions.Enabled){'Account enabled'}else{'Account disabled'}))
        }
        if ($AccountOptions['Unlock']) { $wanted.Add('Unlocked') }
        if ($AccountOptions.ContainsKey('PasswordNeverExpires')) {
            $wanted.Add("PasswordNeverExpires=$([bool]$AccountOptions.PasswordNeverExpires)")
        }
        if ($AccountOptions.ContainsKey('ChangePasswordAtLogon')) {
            $wanted.Add("MustChangeAtNextLogon=$([bool]$AccountOptions.ChangePasswordAtLogon)")
        }
    }
    $optionText = ($wanted -join ', ')

    $total = @($Users).Count
    $mode  = if ($WhatIf) { 'TEST MODE (What-if) - nothing will be changed' } else { 'LIVE MODE - changes ARE written to AD' }

    if ($SkipPassword) {
        Write-AppLog ("Starting account option run on {0} user(s). Mode: {1}. No passwords will be changed." -f $total, $mode) 'INFO'
        Write-AppLog ("Options: {0}" -f $(if($optionText){$optionText}else{'(none selected)'})) 'INFO'
    }
    else {
        Write-AppLog ("Starting {0} user(s). Mode: {1}. Generator via GPO policy (min {2} chars, complexity {3})." -f `
            $total, $mode, $Policy.MinPasswordLength, $(if($Policy.ComplexityEnabled){'ON'}else{'OFF'})) 'INFO'
        if ($optionText) { Write-AppLog ("Account options: {0}" -f $optionText) 'INFO' }
    }
    Write-AppLog ('-' * 60) 'INFO'

    $results = New-Object System.Collections.Generic.List[object]
    $errors  = 0
    $index   = 0

    foreach ($user in $Users) {
        $index++
        $label    = '{0} ({1})' -f $user.Name, $user.SamAccountName
        $prefix   = '[{0}/{1}] {2}' -f $index, $total, $label
        $optError = ''

        # --- 1. Options that must be applied before the reset -----------------
        if ($ApplyAccountOptions) {
            try {
                $pre = @{ User = $user; Stage = 'BeforePassword' }
                if ($AccountOptions.ContainsKey('Enabled'))              { $pre.Enabled = [bool]$AccountOptions.Enabled }
                if ($AccountOptions['Unlock'])                           { $pre.Unlock  = $true }
                if ($AccountOptions.ContainsKey('PasswordNeverExpires')) { $pre.PasswordNeverExpires = [bool]$AccountOptions.PasswordNeverExpires }
                if ($WhatIf) { $pre.WhatIf = $true }
                Set-AdAccountOption @pre | Out-Null
            }
            catch {
                $optError = $_.Exception.Message
                Write-AppLog ("{0}: account option error - {1}" -f $prefix, $optError) 'ERROR'
            }
        }

        # --- 2. The password itself ------------------------------------------
        if ($SkipPassword) {
            $state = if ($WhatIf) { 'WHATIF' } else { 'OK' }
            $row = New-ResultRow -User $user -Password '' -State $state -PasswordChanged $false
        }
        else {
            $pw = if ($sharedPassword) { $sharedPassword } else {
                New-CompliantPassword -Policy $Policy -Length $len -UseUpper $useU -UseLower $useL -UseDigit $useD -UseSpecial $useS -SpecialChars $special -AvoidAmbiguous $avoid
            }

            $row = if ($WhatIf) {
                Set-AdUserPassword -User $user -Password $pw -WhatIf
            } else {
                Set-AdUserPassword -User $user -Password $pw
            }
        }

        # --- 3. Must change at next logon - always AFTER the reset ------------
        # Skipped when stage 1 already failed, so the same error is not logged twice.
        if ($ApplyAccountOptions -and $row.State -ne 'FAILED' -and -not $optError) {
            try {
                $post = @{ User = $user; Stage = 'AfterPassword' }
                if ($AccountOptions.ContainsKey('ChangePasswordAtLogon')) { $post.ChangePasswordAtLogon = [bool]$AccountOptions.ChangePasswordAtLogon }
                if ($WhatIf) { $post.WhatIf = $true }
                Set-AdAccountOption @post | Out-Null
            }
            catch {
                $optError = $_.Exception.Message
                Write-AppLog ("{0}: account option error - {1}" -f $prefix, $optError) 'ERROR'
            }
        }

        # --- Result row + one log line per account ----------------------------
        $row.Options = $optionText
        if ($optError) {
            $errors++
            if ($SkipPassword) { $row.State = 'FAILED' }
            $row.Message = (@($row.Message, ("Option error: {0}" -f $optError)) | Where-Object { $_ }) -join ' | '
        }

        if ($row.State -eq 'FAILED') {
            if (-not $optError) { $errors++ }
            Write-AppLog ("{0}: FAILED - {1}" -f $prefix, $row.Message) 'ERROR'
        }
        else {
            $what = if ($SkipPassword) {
                if ($WhatIf) { 'account options WOULD be applied' } else { 'account options applied' }
            }
            elseif ($WhatIf) { 'password WOULD be changed (simulated)' }
            else             { 'password changed' }

            $line = "{0}: {1}" -f $prefix, $what
            if ($optionText -and -not $SkipPassword) { $line = "{0} + options [{1}]" -f $line, $optionText }
            elseif ($optionText) { $line = "{0} [{1}]" -f $line, $optionText }
            Write-AppLog $line 'INFO'
        }

        $results.Add($row)
    }

    $done = ($results | Where-Object { $_.State -in @('OK', 'WHATIF') }).Count

    $verb = if ($SkipPassword) {
        if ($WhatIf) { 'would get new account options' } else { 'got new account options' }
    }
    elseif ($WhatIf) { 'would get a new password' }
    else             { 'got a new password' }

    Write-AppLog ('-' * 60) 'INFO'
    Write-AppLog ("DONE - {0} of {1} account(s) {2}. Failed: {3}." -f $done, $total, $verb, $errors) $(if($errors){'WARN'}else{'INFO'})

    return $results.ToArray()
}
