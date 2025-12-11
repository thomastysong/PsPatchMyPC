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
    
    try {
        Add-Type -AssemblyName PresentationFramework, System.Windows.Forms -ErrorAction SilentlyContinue
        
        $message = $Config.Notifications.DialogMessage
        if (-not $message) {
            $message = "Critical updates are ready to install. Save your work - applications may close automatically."
        }
        
        $xaml = Get-DeferralDialogXaml `
            -Title $Config.Notifications.DialogTitle `
            -Message $message `
            -AppName "$($update.AppName) ($($update.InstalledVersion) -> $($update.AvailableVersion))" `
            -DeferralsRemaining $deferralState.GetRemainingDeferrals() `
            -AccentColor $Config.Notifications.AccentColor
        
        $window = Show-WPFDialog -Xaml $xaml -Timeout $Timeout
        
        if (-not $window) {
            return 'Error'
        }
        
        $result = 'Timeout'
        $remainingSeconds = $Timeout
        
        # Get UI elements
        $countdownText = $window.FindName("CountdownText")
        $deferButton = $window.FindName("DeferButton")
        $updateButton = $window.FindName("UpdateButton")
        
        # Disable defer button if no deferrals remaining
        if (-not $deferralState.CanDefer() -and $deferButton) {
            $deferButton.IsEnabled = $false
            $deferButton.Content = "No deferrals remaining"
        }
        
        # Countdown timer
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(1)
        $timer.Add_Tick({
            $remainingSeconds--
            $mins = [Math]::Floor($remainingSeconds / 60)
            $secs = $remainingSeconds % 60
            $countdownText.Text = "{0}:{1:D2}" -f $mins, $secs
            
            if ($remainingSeconds -le 0) {
                $timer.Stop()
                $result = 'Install'
                $window.Close()
            }
        }.GetNewClosure())
        
        # Button handlers
        if ($deferButton) {
            $deferButton.Add_Click({
                $timer.Stop()
                $result = 'Defer'
                $window.Close()
            }.GetNewClosure())
        }
        
        if ($updateButton) {
            $updateButton.Add_Click({
                $timer.Stop()
                $result = 'Install'
                $window.Close()
            }.GetNewClosure())
        }
        
        $window.Add_Loaded({ $timer.Start() })
        $window.ShowDialog() | Out-Null
        
        Write-PatchLog "Deferral dialog result: $result" -Type Info
        return $result
    }
    catch {
        Write-PatchLog "Failed to show deferral dialog: $_" -Type Error
        return 'Error'
    }
}

