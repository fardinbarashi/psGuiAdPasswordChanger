<#
.SYNOPSIS
    Keeps the two run buttons labelled after what they will actually do.
.DESCRIPTION
    With "No password change - only account options" ticked, the buttons apply account
    options and never touch a password, so they should not say "password". Called every
    time one of the two account-option checkboxes is clicked.
#>
function Update-RunButtonText {
    [CmdletBinding()] param()

    $c = $script:App.Controls
    if (-not $c -or -not $c.BtnWhatIf) { return }

    if ((Test-OptionsOnlyRun)) {
        $c.BtnWhatIf.Content = 'What if ( Simulate Account Options )'
        $c.BtnLive.Content   = 'Change account options ( Live )'
    }
    else {
        $c.BtnWhatIf.Content = 'What if ( Simulate Change Password )'
        $c.BtnLive.Content   = 'Change password ( Live )'
    }
}
