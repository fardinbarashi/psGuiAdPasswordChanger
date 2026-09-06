<#
.SYNOPSIS
    Loads the WPF window, wires all events and shows the GUI.
#>
function Show-MainWindow {
    [CmdletBinding()] param()

    $xamlPath = Join-Path $script:App.Root 'asset\xaml\MainWindow.xaml'
    [xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $script:App.Window = $window

    # ---- Resolve named controls -----------------------------------------
    $names = @(
        'ImgLogo','SubtitleText','TxtVersion','ChkTestMode','BtnConnect','BtnReload',
        'CmbShow','TreeAd',
        'TxtGlobalSearch','BtnSearch','BtnSearchClear','PnlSearchResults','LstSearch','TxtSearchInfo',
        'TxtAttr1','TxtVal1','TxtAttr2','TxtVal2','TxtAttr3','TxtVal3','BtnAttrFilter','BtnAttrClear','TxtAttrInfo',
        'TxtSelectedCount',
        'ChkOverride','PnlGen','TxtLength','ChkUpper','ChkLower','ChkDigit','ChkSpecial',
        'ChkSameAll','BtnGenerateSample','TxtSample','TxtPolicy',
        'ChkChangeOptions','PnlOpts','ChkEnabled','ChkUnlock','ChkPne','ChkMustChange','ChkNoPassword',
        'BtnWhatIf','BtnLive','BtnClear','TxtLogSearch','LogBox'
    )
    $script:App.Controls = @{}
    foreach ($n in $names) { $script:App.Controls[$n] = $window.FindName($n) }
    $c = $script:App.Controls

    # ---- Shared state ----------------------------------------------------
    $script:App.CheckMap = @{}
    $script:App.Suppress = 0
    $script:App.AttrFilterDns = $null
    if (-not $script:App.LogLines) { $script:App.LogLines = New-Object System.Collections.ArrayList }

    # ---- Version (from settings\version.json) ---------------------------
    if (-not $script:App.Version) { $script:App.Version = Get-AppVersion }
    $ver = $script:App.Version
    $window.Title = 'psGuiAdPasswordChanger v{0}' -f $ver.VersionLabel
    $c.TxtVersion.Text = 'v{0}' -f $ver.VersionLabel
    $tip = @($ver.Description, $ver.Link) | Where-Object { $_ }
    if ($tip) { $c.TxtVersion.ToolTip = ($tip -join [Environment]::NewLine) }
    if ($ver.Link) {
        # Clicking the version opens the project page in the default browser.
        $c.TxtVersion.Add_MouseLeftButtonUp({
            try { Start-Process $script:App.Version.Link } catch { }
        })
    }

    # ---- Logo ------------------------------------------------------------
    $logoFile = Join-Path $script:App.Root 'asset\logo\logo-white.png'
    if (-not (Test-Path $logoFile)) { $logoFile = Join-Path $script:App.Root 'asset\logo\logo.png' }
    if (Test-Path $logoFile) {
        try {
            $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
            $bmp.BeginInit()
            $bmp.UriSource = New-Object System.Uri($logoFile)
            $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bmp.EndInit()
            $c.ImgLogo.Source = $bmp
        } catch { }
    }

    # ---- Test-mode default from config ----------------------------------
    if ($script:App.Config.Ui.TestModeDefault -ne $null) {
        $c.ChkTestMode.IsChecked = [bool]$script:App.Config.Ui.TestModeDefault
    }

    # ---- Placeholder helper for search boxes ----------------------------
    $setPlaceholder = {
        param($tb)
        if ([string]::IsNullOrEmpty($tb.Text) -and $tb.Tag) {
            $tb.Text = [string]$tb.Tag
            $tb.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(150,160,172))
        }
    }
    foreach ($tb in @($c.TxtGlobalSearch, $c.TxtLogSearch)) {
        & $setPlaceholder $tb
        $tb.Add_GotFocus({
            param($s,$e)
            if ($s.Text -eq [string]$s.Tag) { $s.Text = ''; $s.Foreground = [System.Windows.Media.Brushes]::White }
            if ($s -eq $script:App.Controls.TxtGlobalSearch) { $s.Foreground = [System.Windows.Media.Brushes]::Black }
        })
        $tb.Add_LostFocus({
            param($s,$e)
            if ([string]::IsNullOrEmpty($s.Text)) {
                $s.Text = [string]$s.Tag
                $s.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(150,160,172))
            }
        })
    }

    # ---- Editable "password for all" box (placeholder, black text) -------
    $grayBrush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(150,160,172))
    if ([string]::IsNullOrEmpty($c.TxtSample.Text)) {
        $c.TxtSample.Text = [string]$c.TxtSample.Tag
        $c.TxtSample.Foreground = $grayBrush
    }
    $c.TxtSample.Add_GotFocus({
        $s = $script:App.Controls.TxtSample
        if ($s.Text -eq [string]$s.Tag) { $s.Text = ''; $s.Foreground = [System.Windows.Media.Brushes]::Black }
    })
    $c.TxtSample.Add_LostFocus({
        $s = $script:App.Controls.TxtSample
        if ([string]::IsNullOrWhiteSpace($s.Text)) {
            $s.Text = [string]$s.Tag
            $s.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(150,160,172))
        }
    })

    # ---- Header buttons --------------------------------------------------
    $c.BtnConnect.Add_Click({ Connect-AdData })
    $c.BtnReload.Add_Click({ Connect-AdData })

    # ---- Tree lazy-load on expand ---------------------------------------
    $c.TreeAd.AddHandler(
        [System.Windows.Controls.TreeViewItem]::ExpandedEvent,
        [System.Windows.RoutedEventHandler]{
            param($s,$e)
            $src = $e.OriginalSource
            if ($src -is [System.Windows.Controls.TreeViewItem]) { Expand-TreeNode -Item $src }
        })

    # ---- Filters ---------------------------------------------------------
    $c.CmbShow.Add_SelectionChanged({ if ($script:App.Controls) { Update-UserFilter } })

    # ---- Global directory search ----------------------------------------
    $c.BtnSearch.Add_Click({ Invoke-GlobalSearch })
    $c.TxtGlobalSearch.Add_KeyDown({
        param($s,$e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) { Invoke-GlobalSearch }
    })
    $c.BtnSearchClear.Add_Click({
        $cc = $script:App.Controls
        $cc.PnlSearchResults.Visibility = [System.Windows.Visibility]::Collapsed
        $cc.TreeAd.Visibility           = [System.Windows.Visibility]::Visible
        $cc.BtnSearchClear.Visibility   = [System.Windows.Visibility]::Collapsed
    })

    # ---- Attribute filter (3 attribute/value rows over the tree) ---------
    $c.BtnAttrFilter.Add_Click({ Invoke-AttributeFilter })
    $c.BtnAttrClear.Add_Click({ Clear-AttributeFilter })
    foreach ($box in @($c.TxtAttr1, $c.TxtVal1, $c.TxtAttr2, $c.TxtVal2, $c.TxtAttr3, $c.TxtVal3)) {
        $box.Add_KeyDown({
            param($s, $e)
            if ($e.Key -eq [System.Windows.Input.Key]::Enter) { Invoke-AttributeFilter }
        })
    }

    # ---- Generator panel -------------------------------------------------
    # The sample box is editable (a typed value = fixed password for all users),
    # so it is only filled on demand via "Generate sample" - never auto-overwritten.
    $c.ChkOverride.Add_Click({
        $script:App.Controls.PnlGen.IsEnabled = [bool]$script:App.Controls.ChkOverride.IsChecked
    })
    $c.BtnGenerateSample.Add_Click({ Invoke-GenerateSample })

    # ---- Account options + mutual exclusion -----------------------------
    $c.ChkChangeOptions.Add_Click({
        $cc = $script:App.Controls
        $on = [bool]$cc.ChkChangeOptions.IsChecked
        $cc.PnlOpts.IsEnabled = $on
        # Leaving "no password change" ticked on a disabled panel would be misleading.
        if (-not $on) { $cc.ChkNoPassword.IsChecked = $false }
        Update-RunButtonText
    })
    # "No password change - only account options": the run buttons then apply the
    # account options and never touch a password.
    $c.ChkNoPassword.Add_Click({ Update-RunButtonText })
    $c.ChkPne.Add_Click({
        if ($script:App.Controls.ChkPne.IsChecked) {
            $script:App.Controls.ChkMustChange.IsChecked = $false
            $script:App.Controls.ChkMustChange.IsEnabled = $false
        } else { $script:App.Controls.ChkMustChange.IsEnabled = $true }
    })
    $c.ChkMustChange.Add_Click({
        if ($script:App.Controls.ChkMustChange.IsChecked) {
            $script:App.Controls.ChkPne.IsChecked = $false
            $script:App.Controls.ChkPne.IsEnabled = $false
        } else { $script:App.Controls.ChkPne.IsEnabled = $true }
    })

    # ---- Run buttons -----------------------------------------------------
    $c.BtnWhatIf.Add_Click({ Invoke-GuiRun -Live $false })
    $c.BtnLive.Add_Click({ Invoke-GuiRun -Live $true })

    # ---- Clear selection -------------------------------------------------
    $c.BtnClear.Add_Click({
        $script:App.Suppress++
        try {
            foreach ($item in (Get-TreeItem -Parent $script:App.Controls.TreeAd -OnlyLoaded)) {
                if ($item.Tag.CheckBox) { $item.Tag.CheckBox.IsChecked = $false }
            }
            foreach ($cb in $script:App.Controls.LstSearch.Items) {
                if ($cb -is [System.Windows.Controls.CheckBox]) { $cb.IsChecked = $false }
            }
        } finally { $script:App.Suppress-- }
        Update-SelectedCount
        Write-AppLog 'Selection cleared.' 'INFO'
    })

    # ---- Log search ------------------------------------------------------
    $c.TxtLogSearch.Add_TextChanged({ if ($script:App.Controls) { Update-LogFilter } })

    Write-AppLog 'GUI ready. Click "Connect & Load AD" to load the domain.' 'INFO'

    # Auto-connect in demo mode so the tree is populated for a quick look.
    if ($script:App.Config.Demo.Enabled) { Connect-AdData }

    $window.Add_Closed({ Write-AppLog 'Application closed.' 'INFO' })
    [void]$window.ShowDialog()
}
