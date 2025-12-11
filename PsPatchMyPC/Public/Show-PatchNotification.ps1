function Show-PatchNotification {
    <#
    .SYNOPSIS
        Shows a patch notification to the user
    .DESCRIPTION
        Displays a toast notification or dialog about pending updates
    .PARAMETER Type
        Notification type: Toast, Dialog, or Both
    .PARAMETER Updates
        Array of pending updates to notify about
    .PARAMETER Timeout
        Auto-dismiss timeout in seconds
    .EXAMPLE
        Show-PatchNotification -Type Toast -Updates $updates
    .EXAMPLE
        Show-PatchNotification -Type Dialog -Updates $updates -Timeout 300
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Toast', 'Dialog', 'Both')]
        [string]$Type = 'Toast',
        
        [Parameter()]
        [PatchStatus[]]$Updates,
        
        [Parameter()]
        [int]$Timeout = 300
    )
    
    $config = Get-PatchMyPCConfig
    
    # Check if we need to run as user
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isSystem = $currentUser.User.Value -eq 'S-1-5-18'
    
    if ($isSystem -and (Test-UserSessionActive)) {
        # Run notification in user context
        $scriptBlock = {
            param($NotificationType, $UpdateCount, $TimeoutSecs)
            Import-Module PsPatchMyPC -Force
            Show-PatchNotificationInternal -Type $NotificationType -UpdateCount $UpdateCount -Timeout $TimeoutSecs
        }
        
        Invoke-AsCurrentUser -ScriptBlock $scriptBlock -Arguments @($Type, $Updates.Count, $Timeout) -Wait
        return
    }
    
    # Run directly
    Show-PatchNotificationInternal -Type $Type -Updates $Updates -Timeout $Timeout
}

function Show-PatchNotificationInternal {
    <#
    .SYNOPSIS
        Internal implementation of notification display
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Type = 'Toast',
        
        [Parameter()]
        [PatchStatus[]]$Updates,
        
        [Parameter()]
        [int]$UpdateCount,
        
        [Parameter()]
        [int]$Timeout = 300
    )
    
    $config = Get-PatchMyPCConfig
    $count = if ($Updates) { $Updates.Count } else { $UpdateCount }
    
    switch ($Type) {
        'Toast' {
            Show-ToastNotificationInternal -UpdateCount $count -Config $config
        }
        'Dialog' {
            Show-DeferralDialogFull -Updates $Updates -Config $config -Timeout $Timeout
        }
        'Both' {
            Show-ToastNotificationInternal -UpdateCount $count -Config $config
            Start-Sleep -Seconds 2
            Show-DeferralDialogFull -Updates $Updates -Config $config -Timeout $Timeout
        }
    }
}

function Show-ToastNotification {
    <#
    .SYNOPSIS
        Shows a toast notification about available updates
    .DESCRIPTION
        Displays a Windows toast notification using BurntToast or fallback WPF
    .PARAMETER Title
        Notification title
    .PARAMETER Message
        Notification message
    .PARAMETER Duration
        How long to show the toast (seconds)
    .EXAMPLE
        Show-ToastNotification -Title "Updates Available" -Message "3 updates ready to install"
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Title = "Software Update Available",
        
        [Parameter()]
        [string]$Message = "Updates are ready to install.",
        
        [Parameter()]
        [int]$Duration = 10
    )
    
    Show-ToastNotificationInternal -Title $Title -Message $Message -Duration $Duration
}

function Show-ToastNotificationInternal {
    <#
    .SYNOPSIS
        Internal toast notification implementation
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$UpdateCount,
        
        [Parameter()]
        [PsPatchMyPCConfig]$Config,
        
        [Parameter()]
        [string]$Title,
        
        [Parameter()]
        [string]$Message,
        
        [Parameter()]
        [int]$Duration = 10
    )
    
    if (-not $Config) {
        $Config = Get-PatchMyPCConfig
    }
    
    if (-not $Title) {
        $Title = $Config.Notifications.ToastTitle
        if (-not $Title) { $Title = "Software Update Available" }
    }
    
    if (-not $Message) {
        $Message = "$UpdateCount update(s) ready to install. Click to proceed."
    }
    
    # Try BurntToast first
    try {
        $bt = Get-Module -Name BurntToast -ListAvailable -ErrorAction SilentlyContinue
        if ($bt) {
            Import-Module BurntToast -Force
            
            $toastParams = @{
                Text = @($Title, $Message)
                AppLogo = $Config.Notifications.CompanyLogoPath
            }
            
            New-BurntToastNotification @toastParams
            Write-PatchLog "Displayed BurntToast notification" -Type Info
            return
        }
    }
    catch {
        Write-PatchLog "BurntToast failed, falling back to WPF: $_" -Type Warning
    }
    
    # Fallback to WPF toast
    try {
        Add-Type -AssemblyName PresentationFramework, System.Windows.Forms -ErrorAction SilentlyContinue
        
        $xaml = Get-ToastNotificationXaml -Title $Title -Message $Message -AccentColor $Config.Notifications.AccentColor
        $window = Show-WPFDialog -Xaml $xaml -Timeout $Duration
        
        if ($window) {
            # Position bottom-right
            $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $window.Left = $workingArea.Right - 420
            $window.Top = $workingArea.Bottom - 140
            
            # Auto-dismiss timer
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromSeconds($Duration)
            $timer.Add_Tick({ 
                $timer.Stop()
                $window.Close() 
            })
            
            $window.Add_Loaded({ $timer.Start() })
            
            # Close button handler
            $closeBtn = $window.FindName("CloseButton")
            if ($closeBtn) {
                $closeBtn.Add_Click({ $window.Close() })
            }
            
            $window.ShowDialog() | Out-Null
            Write-PatchLog "Displayed WPF toast notification" -Type Info
        }
    }
    catch {
        Write-PatchLog "Failed to show toast notification: $_" -Type Error
    }
}

function Show-DeferralDialog {
    <#
    .SYNOPSIS
        Shows a deferral dialog for a pending update
    .DESCRIPTION
        Displays a modal dialog allowing user to defer or proceed with update
    .PARAMETER AppId
        The application ID to show dialog for
    .PARAMETER Timeout
        Auto-proceed timeout in seconds
    .EXAMPLE
        $result = Show-DeferralDialog -AppId 'Google.Chrome'
        if ($result -eq 'Install') { Install-WingetUpdate -Id 'Google.Chrome' }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId,
        
        [Parameter()]
        [int]$Timeout = 300
    )
    
    # Get update info
    $update = Get-PatchStatus -AppId $AppId | Select-Object -First 1
    if (-not $update) {
        Write-PatchLog "No update found for $AppId" -Type Warning
        return 'NoUpdate'
    }
    
    $config = Get-PatchMyPCConfig
    return Show-DeferralDialogFull -Updates @($update) -Config $config -Timeout $Timeout
}

function Show-DeferralDialogFull {
    <#
    .SYNOPSIS
        Shows full deferral dialog with countdown
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PatchStatus[]]$Updates,
        
        [Parameter()]
        [PsPatchMyPCConfig]$Config,
        
        [Parameter()]
        [int]$Timeout = 300
    )
    
    if (-not $Config) {
        $Config = Get-PatchMyPCConfig
    }
    
    if (-not $Updates -or $Updates.Count -eq 0) {
        return 'NoUpdates'
    }
    
    $update = $Updates[0]
    $deferralState = Get-StateFromRegistry -AppId $update.AppId
    $deferralsRemaining = $deferralState.GetRemainingDeferrals()
    $canDefer = $deferralState.CanDefer()
    
    # WPF requires STA thread - run in separate runspace if needed
    $currentThread = [System.Threading.Thread]::CurrentThread
    if ($currentThread.GetApartmentState() -ne 'STA') {
        Write-PatchLog "Running dialog in STA runspace..." -Type Info
        
        # Create STA runspace for WPF
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = 'STA'
        $runspace.ThreadOptions = 'ReuseThread'
        $runspace.Open()
        
        $ps = [powershell]::Create()
        $ps.Runspace = $runspace
        
        $null = $ps.AddScript({
            param($AppName, $InstalledVersion, $AvailableVersion, $DeferralsRemaining, $CanDefer, $AccentColor, $Timeout)
            
            Add-Type -AssemblyName PresentationFramework
            
            $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Update Required" Height="300" Width="500"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Border CornerRadius="12" Background="#FF2D2D30" BorderBrush="$AccentColor" 
            BorderThickness="2" Margin="10">
        <Grid Margin="25">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Grid.Row="0" Text="Software Update Required" 
                      FontSize="20" FontWeight="Bold" Foreground="White"/>
            
            <TextBlock Grid.Row="1" Text="$AppName ($InstalledVersion -> $AvailableVersion)"
                      FontSize="16" Foreground="$AccentColor" Margin="0,15,0,5"/>
            
            <TextBlock Grid.Row="2" TextWrapping="Wrap" Foreground="#CCCCCC" FontSize="14" Margin="0,10">
                A software update is ready to install. Save your work and click Update Now.
            </TextBlock>
            
            <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10">
                <TextBlock Text="Auto-installing in: " Foreground="#888888" FontSize="14"/>
                <TextBlock Name="CountdownText" Text="5:00" Foreground="$AccentColor" FontSize="14" FontWeight="Bold"/>
            </StackPanel>
            
            <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,10,0,0">
                <Button Name="DeferButton" Content="Defer ($DeferralsRemaining remaining)" Width="160" Height="36" 
                       Margin="0,0,12,0" Background="#FF3F3F3F" Foreground="White" BorderThickness="0"/>
                <Button Name="UpdateButton" Content="Update Now" Width="120" Height="36" 
                       Background="$AccentColor" Foreground="White" BorderThickness="0"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@
            
            [xml]$xamlXml = $xaml
            $reader = New-Object System.Xml.XmlNodeReader $xamlXml
            $window = [Windows.Markup.XamlReader]::Load($reader)
            
            $script:dialogResult = 'Timeout'
            $script:remainingSeconds = $Timeout
            
            $countdownText = $window.FindName("CountdownText")
            $deferButton = $window.FindName("DeferButton")
            $updateButton = $window.FindName("UpdateButton")
            
            if (-not $CanDefer) {
                $deferButton.IsEnabled = $false
                $deferButton.Content = "No deferrals left"
            }
            
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromSeconds(1)
            $timer.Add_Tick({
                $script:remainingSeconds--
                $mins = [Math]::Floor($script:remainingSeconds / 60)
                $secs = $script:remainingSeconds % 60
                $countdownText.Text = "{0}:{1:D2}" -f $mins, $secs
                
                if ($script:remainingSeconds -le 0) {
                    $timer.Stop()
                    $script:dialogResult = 'Install'
                    $window.Close()
                }
            })
            
            $deferButton.Add_Click({
                $timer.Stop()
                $script:dialogResult = 'Defer'
                $window.Close()
            })
            
            $updateButton.Add_Click({
                $timer.Stop()
                $script:dialogResult = 'Install'
                $window.Close()
            })
            
            $window.Add_Loaded({ $timer.Start() })
            $window.ShowDialog() | Out-Null
            
            return $script:dialogResult
        })
        
        $null = $ps.AddArgument($update.AppName)
        $null = $ps.AddArgument($update.InstalledVersion)
        $null = $ps.AddArgument($update.AvailableVersion)
        $null = $ps.AddArgument($deferralsRemaining)
        $null = $ps.AddArgument($canDefer)
        $null = $ps.AddArgument($Config.Notifications.AccentColor)
        $null = $ps.AddArgument($Timeout)
        
        try {
            $result = $ps.Invoke()
            Write-PatchLog "Deferral dialog result: $($result[0])" -Type Info
            return $result[0]
        }
        finally {
            $ps.Dispose()
            $runspace.Close()
            $runspace.Dispose()
        }
    }
    
    # Already in STA - run directly
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        
        $message = $Config.Notifications.DialogMessage
        if (-not $message) {
            $message = "Critical updates are ready to install. Save your work - applications may close automatically."
        }
        
        $xaml = Get-DeferralDialogXaml `
            -Title $Config.Notifications.DialogTitle `
            -Message $message `
            -AppName "$($update.AppName) ($($update.InstalledVersion) -> $($update.AvailableVersion))" `
            -DeferralsRemaining $deferralsRemaining `
            -AccentColor $Config.Notifications.AccentColor
        
        $window = Show-WPFDialog -Xaml $xaml -Timeout $Timeout
        
        if (-not $window) {
            return 'Error'
        }
        
        $script:result = 'Timeout'
        $script:remainingSeconds = $Timeout
        
        $countdownText = $window.FindName("CountdownText")
        $deferButton = $window.FindName("DeferButton")
        $updateButton = $window.FindName("UpdateButton")
        
        if (-not $canDefer -and $deferButton) {
            $deferButton.IsEnabled = $false
            $deferButton.Content = "No deferrals remaining"
        }
        
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(1)
        $timer.Add_Tick({
            $script:remainingSeconds--
            $mins = [Math]::Floor($script:remainingSeconds / 60)
            $secs = $script:remainingSeconds % 60
            $countdownText.Text = "{0}:{1:D2}" -f $mins, $secs
            
            if ($script:remainingSeconds -le 0) {
                $timer.Stop()
                $script:result = 'Install'
                $window.Close()
            }
        })
        
        if ($deferButton) {
            $deferButton.Add_Click({
                $timer.Stop()
                $script:result = 'Defer'
                $window.Close()
            })
        }
        
        if ($updateButton) {
            $updateButton.Add_Click({
                $timer.Stop()
                $script:result = 'Install'
                $window.Close()
            })
        }
        
        $window.Add_Loaded({ $timer.Start() })
        $window.ShowDialog() | Out-Null
        
        Write-PatchLog "Deferral dialog result: $script:result" -Type Info
        return $script:result
    }
    catch {
        Write-PatchLog "Failed to show deferral dialog: $_" -Type Error
        return 'Error'
    }
}

