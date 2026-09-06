<#
.SYNOPSIS
    Runs a What-if (simulate) or a live change from the GUI buttons, then writes the
    HTML + CSV reports.
.DESCRIPTION
    What the run does is decided by two checkboxes in the account-options card:
      "Change account options on selected"          -> the options are applied
      "No password change - only account options"   -> no password is touched at all
    With the second one ticked, both run buttons apply account options only (the button
    captions change to match); Test mode still decides simulated vs live.
#>
function Invoke-GuiRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [bool]$Live
    )

    $c = $script:App.Controls

    if (-not $script:App.Policy) {
        [System.Windows.MessageBox]::Show('Connect to AD first (Connect & Load AD).', 'Not connected',
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
        return
    }

    $users = @(Get-SelectedUser)
    if ($users.Count -eq 0) {
        [System.Windows.MessageBox]::Show('No users selected.', 'Nothing to do',
            [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        return
    }

    # Account options.
    $applyOpts   = [bool]$c.ChkChangeOptions.IsChecked
    $optionsOnly = [bool](Test-OptionsOnlyRun)

    $opts = @{}
    if ($applyOpts) {
        if ($c.ChkPne.IsChecked -and $c.ChkMustChange.IsChecked) {
            [System.Windows.MessageBox]::Show(
                "'Password never expires' and 'Must change password at next logon' cannot both be enabled.",
                'Conflicting options', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
            return
        }
        $opts.Enabled               = [bool]$c.ChkEnabled.IsChecked
        $opts.Unlock                = [bool]$c.ChkUnlock.IsChecked
        $opts.PasswordNeverExpires  = [bool]$c.ChkPne.IsChecked
        $opts.ChangePasswordAtLogon = [bool]$c.ChkMustChange.IsChecked
    }

    # Test mode always forces a simulation, even if the live button was pressed.
    $whatIf = $true
    if ($Live -and -not $c.ChkTestMode.IsChecked) { $whatIf = $false }
    if ($Live -and $c.ChkTestMode.IsChecked) {
        Write-AppLog 'Test mode is ON - live run downgraded to What-if.' 'WARN'
    }

    # Confirm a live run.
    if (-not $whatIf) {
        $confirmText = if ($optionsOnly) {
            "You are about to CHANGE ACCOUNT OPTIONS for {0} user(s) in LIVE mode.`nNo passwords will be changed. Continue?" -f $users.Count
        } else {
            "You are about to CHANGE passwords for {0} user(s) in LIVE mode. Continue?" -f $users.Count
        }
        $answer = [System.Windows.MessageBox]::Show($confirmText, 'Confirm live change',
            [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
            Write-AppLog 'Live run cancelled by user.' 'INFO'
            return
        }
    }

    $generator = @{}
    if (-not $optionsOnly) {
        $generator = Get-GuiGeneratorSetting

        # If a password was typed in the box, it must satisfy the domain policy.
        if ($generator.FixedPassword) {
            $chk = Test-PasswordCompliance -Password $generator.FixedPassword -Policy $script:App.Policy
            if (-not $chk.Ok) {
                [System.Windows.MessageBox]::Show(
                    ("The password you entered does not meet the domain policy:`n - {0}" -f ($chk.Reasons -join "`n - ")),
                    'Password not allowed', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                Write-AppLog 'Manual password rejected - does not meet the domain policy.' 'WARN'
                return
            }
        }
    }

    try {
        $c.BtnWhatIf.IsEnabled = $false
        $c.BtnLive.IsEnabled   = $false

        $results = Invoke-PasswordRun -Users $users -Policy $script:App.Policy -WhatIf $whatIf `
                    -Generator $generator -ApplyAccountOptions $applyOpts -AccountOptions $opts `
                    -SkipPassword $optionsOnly

        $report = Save-Report -Results $results -WhatIf $whatIf `
                    -Combined ([bool]$script:App.Config.Report.CombinedReportByDefault) `
                    -OptionsOnly $optionsOnly

        $ok     = @($results | Where-Object { $_.State -in @('OK','WHATIF') }).Count
        $failed = @($results | Where-Object { $_.State -eq 'FAILED' }).Count

        $headline = if ($optionsOnly) {
            if ($whatIf) { 'FINISHED (simulated) - account options were NOT written' }
            else         { 'FINISHED - account options updated' }
        }
        elseif ($whatIf) { 'FINISHED (simulated) - no passwords were changed' }
        else             { 'FINISHED - passwords changed' }

        Write-AppLog ("{0}: {1} account(s) OK, {2} failed." -f $headline, $ok, $failed) $(if($failed){'WARN'}else{'INFO'})
        Write-AppLog ("Reports in: {0}" -f $report.Folder) 'INFO'
        Write-AppLog ('=' * 60) 'INFO'

        if ($script:App.Config.Ui.ShowDoneDialog -ne $false) {
            [System.Windows.MessageBox]::Show(
                ("{0}`n`nAccounts OK : {1}`nFailed      : {2}`n`nReports:`n{3}" -f $headline, $ok, $failed, $report.Folder),
                'Done', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
        }
    }
    catch {
        Write-AppLog ("Run error: {0}" -f $_.Exception.Message) 'ERROR'
    }
    finally {
        $c.BtnWhatIf.IsEnabled = $true
        $c.BtnLive.IsEnabled   = $true
    }
}
