<#
.SYNOPSIS
    Creates a TreeViewItem (with a checkbox header) for an OU or a user node.
    OU nodes get a placeholder child so they can be lazy-loaded on expand.
#>
function New-TreeNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Node,
        [Parameter(Mandatory)] [ValidateSet('OU','User')] [string]$Type
    )

    $item = New-Object System.Windows.Controls.TreeViewItem

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Orientation = 'Horizontal'

    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.VerticalAlignment = 'Center'
    $cb.Margin = '0,0,6,0'

    $text = New-Object System.Windows.Controls.TextBlock
    $text.VerticalAlignment = 'Center'

    if ($Type -eq 'OU') {
        $text.Text = ('{0} ({1})' -f $Node.Name, $Node.Count)
        $text.FontWeight = 'SemiBold'
    }
    else {
        # Display name + username, then colored status tags.
        $red   = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(192,57,43))
        $info  = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(138,90,0))
        $gray  = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(120,128,138))

        [void]$text.Inlines.Add((New-Object System.Windows.Documents.Run($Node.Name)))
        $userRun = New-Object System.Windows.Documents.Run(' (' + $Node.SamAccountName + ')')
        $userRun.Foreground = $gray
        [void]$text.Inlines.Add($userRun)

        foreach ($tag in (Get-UserStatusTag -User $Node)) {
            $r = New-Object System.Windows.Documents.Run('  ' + $tag.Text)
            $r.Foreground = if ($tag.Kind -eq 'bad') { $red } else { $info }
            $r.FontWeight = 'SemiBold'
            [void]$text.Inlines.Add($r)
        }
    }

    [void]$panel.Children.Add($cb)
    [void]$panel.Children.Add($text)
    $item.Header = $panel

    $item.Tag = @{
        Type     = $Type
        Name     = $Node.Name
        DN       = $Node.DistinguishedName
        Count    = if ($Node.PSObject.Properties['Count']) { $Node.Count } else { 0 }
        Loaded   = ($Type -eq 'User')
        CheckBox = $cb
        Text     = $text
        User  = if ($Type -eq 'User') { $Node } else { $null }
    }

    if ($Type -eq 'OU') {
        $dummy = New-Object System.Windows.Controls.TreeViewItem
        $dummy.Tag = @{ Type = '__dummy' }
        [void]$item.Items.Add($dummy)
    }

    $script:App.CheckMap[$cb] = $item

    $cb.Add_Click({
        param($s, $e)
        $owner = $script:App.CheckMap[$s]
        if ($null -ne $owner) {
            Set-NodeCheckState -Item $owner -IsChecked ([bool]$s.IsChecked)
            Update-SelectedCount
        }
    })

    return $item
}
