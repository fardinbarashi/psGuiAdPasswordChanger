<#
.SYNOPSIS
    Applies the account option changes to a single user (enable/disable, unlock,
    password-never-expires, must-change-at-next-logon).
.DESCRIPTION
    The work is split into two stages because Set-ADAccountPassword -Reset writes a
    new pwdLastSet value on the account. Anything that depends on pwdLastSet - above
    all "Must change password at next logon" - is silently wiped if it is set BEFORE
    the reset, which is why the flag never stuck in earlier versions.

      BeforePassword : Enable/Disable, Unlock, Password never expires
      AfterPassword  : Must change password at next logon

    "Password never expires" is also handled first on purpose: Active Directory
    refuses ChangePasswordAtLogon on an account that still has the never-expires
    flag set, so the flag must be cleared before the must-change flag is written.
.NOTES
    "Password never expires" and "must change at next logon" are mutually exclusive
    in Active Directory. The caller (GUI) blocks selecting both, and this function
    enforces it defensively as well.
#>
function Set-AdAccountOption {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [object]$User,
        [Nullable[bool]]$Enabled,
        [switch]$Unlock,
        [Nullable[bool]]$PasswordNeverExpires,
        [Nullable[bool]]$ChangePasswordAtLogon,
        [ValidateSet('All', 'BeforePassword', 'AfterPassword')] [string]$Stage = 'All',
        [object]$Config = $script:App.Config
    )

    # Defensive mutual-exclusion guard.
    if ($PasswordNeverExpires -eq $true -and $ChangePasswordAtLogon -eq $true) {
        throw "'Password never expires' and 'Must change password at next logon' cannot both be enabled."
    }

    $doBefore = ($Stage -eq 'All' -or $Stage -eq 'BeforePassword')
    $doAfter  = ($Stage -eq 'All' -or $Stage -eq 'AfterPassword')

    $applied = New-Object System.Collections.Generic.List[string]

    if ($script:App.DemoMode) {
        if ($doBefore) {
            if ($Enabled -ne $null)              { $applied.Add($(if($Enabled){'enabled'}else{'disabled'})) }
            if ($Unlock)                         { $applied.Add('unlocked') }
            if ($PasswordNeverExpires -ne $null) { $applied.Add("PasswordNeverExpires=$PasswordNeverExpires") }
        }
        if ($doAfter) {
            if ($ChangePasswordAtLogon -ne $null){ $applied.Add("ChangePasswordAtLogon=$ChangePasswordAtLogon") }
        }
        return ,$applied.ToArray()
    }

    $server = $Config.Domain.Server
    $common = @{ ErrorAction = 'Stop' }
    if ($server) { $common.Server = $server }
    $id = $User.DistinguishedName

    # ---------------- Stage 1: before the password reset ----------------------
    if ($doBefore) {

        if ($Enabled -ne $null) {
            if ($Enabled) {
                if ($PSCmdlet.ShouldProcess($User.SamAccountName, 'Enable-ADAccount')) {
                    Enable-ADAccount -Identity $id @common; $applied.Add('enabled')
                }
            }
            else {
                if ($PSCmdlet.ShouldProcess($User.SamAccountName, 'Disable-ADAccount')) {
                    Disable-ADAccount -Identity $id @common; $applied.Add('disabled')
                }
            }
        }

        if ($Unlock) {
            if ($PSCmdlet.ShouldProcess($User.SamAccountName, 'Unlock-ADAccount')) {
                Unlock-ADAccount -Identity $id @common; $applied.Add('unlocked')
            }
        }

        # Own call, so the never-expires flag is already cleared when the
        # must-change flag is written in stage 2.
        if ($PasswordNeverExpires -ne $null) {
            if ($PSCmdlet.ShouldProcess($User.SamAccountName, 'Set-ADUser -PasswordNeverExpires')) {
                Set-ADUser -Identity $id -PasswordNeverExpires ([bool]$PasswordNeverExpires) @common
                $applied.Add("PasswordNeverExpires=$([bool]$PasswordNeverExpires)")
            }
        }
    }

    # ---------------- Stage 2: after the password reset -----------------------
    # Set-ADAccountPassword -Reset stamps pwdLastSet with the current time, which
    # clears "must change at next logon". Writing the flag here makes it stick.
    if ($doAfter) {
        if ($ChangePasswordAtLogon -ne $null) {
            if ($PSCmdlet.ShouldProcess($User.SamAccountName, 'Set-ADUser -ChangePasswordAtLogon')) {
                Set-ADUser -Identity $id -ChangePasswordAtLogon ([bool]$ChangePasswordAtLogon) @common
                $applied.Add("ChangePasswordAtLogon=$([bool]$ChangePasswordAtLogon)")
            }
        }
    }

    return ,$applied.ToArray()
}
