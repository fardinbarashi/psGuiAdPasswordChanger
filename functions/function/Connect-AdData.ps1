<#
.SYNOPSIS
    Connects to AD (or demo), reads the password policy and loads the ou nodes
    into the tree root. Backs "Connect & Load AD" and "Reload AD".
#>
function Connect-AdData {
    [CmdletBinding()] param()

    $c   = $script:App.Controls
    $cfg = $script:App.Config

    # Decide data source.
    $script:App.DemoMode = $false
    if ($cfg.Demo.Enabled) {
        $script:App.DemoMode = $true
    }
    elseif (-not $script:App.AdAvailable -and $cfg.Demo.AutoFallbackWhenNoAd) {
        $script:App.DemoMode = $true
        Write-AppLog 'ActiveDirectory module not available - starting in DEMO mode with sample data.' 'WARN'
    }
    elseif (-not $script:App.AdAvailable) {
        Write-AppLog 'ActiveDirectory module not available and demo fallback disabled. Cannot load.' 'ERROR'
        return
    }

    try {
        Write-AppLog ('Connecting to AD{0}...' -f $(if($script:App.DemoMode){' (DEMO)'}else{''})) 'INFO'

        # Password policy -> GUI.
        $policy = Get-AdPasswordPolicy
        $script:App.Policy = $policy
        $c.TxtPolicy.Text = Get-PasswordPolicyText -Policy $policy
        Write-AppLog ("Password policy: min length {0}, complexity {1}." -f $policy.MinPasswordLength, $(if($policy.ComplexityEnabled){'ON'}else{'OFF'})) 'INFO'

        # Align generator character sets to complexity requirement (visual hint).
        if ($policy.ComplexityEnabled) {
            $c.ChkUpper.IsChecked = $true; $c.ChkLower.IsChecked = $true; $c.ChkDigit.IsChecked = $true
        }
        if ($c.TxtLength.Text -as [int]) {
            if (([int]$c.TxtLength.Text) -lt $policy.MinPasswordLength) { $c.TxtLength.Text = "$($policy.MinPasswordLength)" }
        }

        # Determine the tree root (search base or domain root).
        if ($script:App.DemoMode) {
            $rootDn = 'DC=env,DC=local'
        }
        elseif ($cfg.Domain.SearchBase) {
            $rootDn = $cfg.Domain.SearchBase
        }
        else {
            $adArgs = @{ ErrorAction = 'Stop' }; if ($cfg.Domain.Server) { $adArgs.Server = $cfg.Domain.Server }
            $rootDn = (Get-ADDomain @adArgs).DistinguishedName
        }

        # Load the OU structure (top-level OUs + any users directly at the root).
        $c.TreeAd.Items.Clear()
        $rootOus = @(Get-AdChildOu -ParentDN $rootDn)
        foreach ($ou in $rootOus) {
            [void]$c.TreeAd.Items.Add((New-TreeNode -Node $ou -Type 'OU'))
        }
        $rootUsers = @(Get-AdOuUser -OuDN $rootDn -Scope OneLevel)
        foreach ($user in $rootUsers) {
            $user | Add-Member -NotePropertyName 'Ou' -NotePropertyValue (Get-TopOuFromDn -DistinguishedName $user.DistinguishedName) -Force
            [void]$c.TreeAd.Items.Add((New-TreeNode -Node $user -Type 'User'))
        }

        $domainLabel = if ($cfg.Ui.DomainLabel) { $cfg.Ui.DomainLabel }
                       elseif ($script:App.DemoMode) { 'env.local (demo)' }
                       elseif ($cfg.Domain.Server) { $cfg.Domain.Server }
                       else { try { (Get-ADDomain).DNSRoot } catch { 'domain' } }

        $total = (($rootOus | Measure-Object -Property Count -Sum).Sum) + $rootUsers.Count
        $c.SubtitleText.Text = ("Connected to AD ({0}) - {1} users" -f $domainLabel, $total)
        Write-AppLog ("Loaded {0} top-level OU(s), {1} users total." -f $rootOus.Count, $total) 'INFO'
        Update-SelectedCount
    }
    catch {
        Write-AppLog ("Connect failed: {0}" -f $_.Exception.Message) 'ERROR'
    }
}
