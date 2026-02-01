function Show-PatchNotification {
    <#
    .SYNOPSIS
        Shows a patch notification to the user
    .DESCRIPTION
        Displays a toast notification or dialog about pending updates.
        Supports enterprise notification escalation based on deferral phase.
    .PARAMETER Type
        Notification type: Toast, Dialog, FullScreen, Both, or Auto
        Auto will select based on deferral phase (enterprise escalation)
    .PARAMETER Updates
        Array of pending updates to notify about
    .PARAMETER Timeout
        Auto-dismiss timeout in seconds
    .PARAMETER DeferralPhase
        Current deferral phase (used for Auto notification type)
    .EXAMPLE
        Show-PatchNotification -Type Toast -Updates $updates
    .EXAMPLE
        Show-PatchNotification -Type Dialog -Updates $updates -Timeout 300
    .EXAMPLE
        Show-PatchNotification -Type Auto -Updates $updates -DeferralPhase Elapsed
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Toast', 'Dialog', 'FullScreen', 'Both', 'Auto')]
        [string]$Type = 'Toast',

        [Parameter()]
        [PatchStatus[]]$Updates,

        [Parameter()]
        [int]$Timeout = 300,

        [Parameter()]
        [DeferralPhase]$DeferralPhase = [DeferralPhase]::Initial
    )

    $config = Get-PatchMyPCConfig

    # Check if we need to run as user
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isSystem = $currentUser.User.Value -eq 'S-1-5-18'

    if ($isSystem -and (Test-UserSessionActive)) {
        # Run notification in user context
        $scriptBlock = {
            param($NotificationType, $UpdateCount, $TimeoutSecs, $Phase)
            Import-Module PsPatchMyPC -Force
            Show-PatchNotificationInternal -Type $NotificationType -UpdateCount $UpdateCount -Timeout $TimeoutSecs -DeferralPhase $Phase
        }

        Invoke-AsCurrentUser -ScriptBlock $scriptBlock -Arguments @($Type, $Updates.Count, $Timeout, $DeferralPhase.ToString()) -Wait
        return
    }

    # Run directly
    Show-PatchNotificationInternal -Type $Type -Updates $Updates -Timeout $Timeout -DeferralPhase $DeferralPhase
}

function Get-NotificationTypeForPhase {
    <#
    .SYNOPSIS
        Determines the appropriate notification type based on deferral phase
    .DESCRIPTION
        Implements enterprise notification escalation logic:
        - Initial: Standard toast
        - Approaching: Reminder toast (persistent)
        - Imminent: Urgent toast + Dialog
        - Elapsed: Full-screen interstitial
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [DeferralPhase]$Phase,

        [Parameter()]
        [int]$DismissalCount = 0,

        [Parameter()]
        [PsPatchMyPCConfig]$Config
    )

    if (-not $Config) { $Config = Get-PatchMyPCConfig }

    $enterprise = $Config.Notifications.Enterprise
    $escalateAfter = if ($enterprise.EscalateAfterDismissals) { [int]$enterprise.EscalateAfterDismissals } else { 3 }

    # Check if should escalate to full-screen based on dismissal count
    if ($DismissalCount -ge $escalateAfter -and $enterprise.EscalateToFullScreen) {
        return @{
            Type = 'FullScreen'
            Scenario = 'Urgent'
            AllowDefer = ($Phase -ne [DeferralPhase]::Elapsed)
        }
    }

    switch ($Phase) {
        'Initial' {
            return @{
                Type = 'Toast'
                Scenario = $enterprise.InitialToastScenario
                AllowDefer = $true
            }
        }
        'Approaching' {
            return @{
                Type = 'Toast'
                Scenario = $enterprise.ApproachingToastScenario
                AllowDefer = $true
            }
        }
        'Imminent' {
            return @{
                Type = 'Both'  # Toast + Dialog
                Scenario = $enterprise.ImminentToastScenario
                AllowDefer = $true
            }
        }
        'Elapsed' {
            if ($enterprise.EscalateToFullScreen) {
                return @{
                    Type = 'FullScreen'
                    Scenario = $enterprise.ElapsedToastScenario
                    AllowDefer = $true  # Allow 1-hour defer even in elapsed
                }
            }
            else {
                return @{
                    Type = 'Dialog'
                    Scenario = 'Urgent'
                    AllowDefer = $true  # 1-hour only
                }
            }
        }
        default {
            return @{
                Type = 'Toast'
                Scenario = 'Default'
                AllowDefer = $true
            }
        }
    }
}

function Get-ToastScenarioForPhase {
    <#
    .SYNOPSIS
        Gets the toast scenario string for the current deferral phase
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [DeferralPhase]$Phase,

        [Parameter()]
        [PsPatchMyPCConfig]$Config
    )

    if (-not $Config) { $Config = Get-PatchMyPCConfig }

    $enterprise = $Config.Notifications.Enterprise
    if (-not $enterprise) { return 'Default' }

    switch ($Phase) {
        'Initial' { return $enterprise.InitialToastScenario }
        'Approaching' { return $enterprise.ApproachingToastScenario }
        'Imminent' { return $enterprise.ImminentToastScenario }
        'Elapsed' { return $enterprise.ElapsedToastScenario }
        default { return 'Default' }
    }
}

function Show-EnterpriseNotification {
    <#
    .SYNOPSIS
        Shows an enterprise notification with automatic escalation
    .DESCRIPTION
        Intelligently selects notification type based on deferral phase,
        dismissal history, and configuration. Implements the full RUXIM-style
        notification escalation pattern.
    .PARAMETER Updates
        Array of pending updates
    .PARAMETER DeferralState
        Current deferral state for the primary update
    .PARAMETER Config
        PsPatchMyPC configuration
    .OUTPUTS
        Hashtable with Result (Install/Defer/Dismissed/Timeout) and Method
    .EXAMPLE
        $result = Show-EnterpriseNotification -Updates $updates -DeferralState $state
        if ($result.Result -eq 'Install') { Install-Updates }
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PatchStatus[]]$Updates,

        [Parameter()]
        [DeferralState]$DeferralState,

        [Parameter()]
        [PsPatchMyPCConfig]$Config,

        [Parameter()]
        [int]$Timeout
    )

    if (-not $Config) { $Config = Get-PatchMyPCConfig }

    $phase = if ($DeferralState) { $DeferralState.Phase } else { [DeferralPhase]::Initial }
    $canDefer = if ($DeferralState) { $DeferralState.CanDefer() } else { $true }
    $deferralsRemaining = if ($DeferralState) { $DeferralState.GetRemainingDeferrals() } else { 5 }

    # Get dismissal count from state
    $dismissalCount = Get-NotificationDismissalCount -AppId ($Updates[0].AppId)

    # Determine notification type
    $notifConfig = Get-NotificationTypeForPhase -Phase $phase -DismissalCount $dismissalCount -Config $Config

    Write-PatchLog "Enterprise notification: Phase=$phase, Type=$($notifConfig.Type), Scenario=$($notifConfig.Scenario), CanDefer=$canDefer" -Type Info

    # Set timeout based on phase if not specified
    if (-not $Timeout) {
        $Timeout = switch ($phase) {
            'Initial' { $Config.Notifications.DialogTimeoutSeconds }
            'Approaching' { $Config.Notifications.DialogTimeoutSeconds }
            'Imminent' { 180 }  # 3 minutes
            'Elapsed' { $Config.Notifications.Enterprise.FullScreenTimeoutSeconds }
            default { $Config.Notifications.DialogTimeoutSeconds }
        }
    }

    $result = @{
        Result = 'Dismissed'
        Method = $notifConfig.Type
        Phase = $phase
    }

    switch ($notifConfig.Type) {
        'Toast' {
            $toastResult = Show-NativeToast `
                -Title $Config.Notifications.ToastTitle `
                -Message $Config.Notifications.ToastMessage `
                -AppName $Updates[0].AppName `
                -Scenario $notifConfig.Scenario `
                -DeferralsRemaining $deferralsRemaining `
                -CanDefer $canDefer

            $result.Result = if ($toastResult.Result) { $toastResult.Result } else { 'Dismissed' }
            $result.Method = $toastResult.Method
        }

        'Dialog' {
            $dialogResult = Show-DeferralDialogFull `
                -Updates $Updates `
                -Config $Config `
                -Timeout $Timeout

            $result.Result = $dialogResult
        }

        'FullScreen' {
            $fsResult = Show-FullScreenPrompt `
                -Updates $Updates `
                -Config $Config `
                -Timeout $Timeout `
                -AllowDefer $notifConfig.AllowDefer

            $result.Result = $fsResult
        }

        'Both' {
            # Show toast first, then dialog
            Show-NativeToast `
                -Title $Config.Notifications.ToastTitle `
                -Message "Updates require your attention" `
                -AppName $Updates[0].AppName `
                -Scenario $notifConfig.Scenario `
                -DeferralsRemaining $deferralsRemaining `
                -CanDefer $canDefer

            Start-Sleep -Seconds 2

            $dialogResult = Show-DeferralDialogFull `
                -Updates $Updates `
                -Config $Config `
                -Timeout $Timeout

            $result.Result = $dialogResult
            $result.Method = 'Toast+Dialog'
        }
    }

    # Update dismissal count if dismissed
    if ($result.Result -in @('Dismissed', 'Timeout')) {
        Update-NotificationDismissalCount -AppId ($Updates[0].AppId) -Increment
    }
    elseif ($result.Result -in @('Install', 'Update')) {
        # Reset dismissal count on action
        Update-NotificationDismissalCount -AppId ($Updates[0].AppId) -Reset
    }

    return $result
}

function Get-NotificationDismissalCount {
    <#
    .SYNOPSIS
        Gets the notification dismissal count for an app
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )

    $regPath = "HKLM:\SOFTWARE\PsPatchMyPC\NotificationState\$AppId"
    try {
        if (Test-Path $regPath) {
            $count = Get-ItemProperty -Path $regPath -Name 'DismissalCount' -ErrorAction SilentlyContinue
            if ($count) { return [int]$count.DismissalCount }
        }
    }
    catch { }

    return 0
}

function Update-NotificationDismissalCount {
    <#
    .SYNOPSIS
        Updates the notification dismissal count for an app
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId,

        [Parameter()]
        [switch]$Increment,

        [Parameter()]
        [switch]$Reset
    )

    $regPath = "HKLM:\SOFTWARE\PsPatchMyPC\NotificationState\$AppId"

    try {
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }

        if ($Reset) {
            Set-ItemProperty -Path $regPath -Name 'DismissalCount' -Value 0 -Type DWord
            Set-ItemProperty -Path $regPath -Name 'LastReset' -Value (Get-Date -Format 'o') -Type String
        }
        elseif ($Increment) {
            $current = Get-NotificationDismissalCount -AppId $AppId
            Set-ItemProperty -Path $regPath -Name 'DismissalCount' -Value ($current + 1) -Type DWord
            Set-ItemProperty -Path $regPath -Name 'LastDismissal' -Value (Get-Date -Format 'o') -Type String
        }
    }
    catch {
        Write-PatchLog "Failed to update notification dismissal count: $_" -Type Warning
    }
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
        [int]$Timeout = 300,

        [Parameter()]
        [string]$DeferralPhase = 'Initial'
    )

    $config = Get-PatchMyPCConfig
    $count = if ($Updates) { $Updates.Count } else { $UpdateCount }

    # Parse deferral phase if string
    $phase = try { [DeferralPhase]$DeferralPhase } catch { [DeferralPhase]::Initial }

    # Handle Auto type - use enterprise escalation logic
    if ($Type -eq 'Auto') {
        if ($Updates -and $Updates.Count -gt 0) {
            $deferralState = Get-StateFromRegistry -AppId $Updates[0].AppId
            $result = Show-EnterpriseNotification -Updates $Updates -DeferralState $deferralState -Config $config -Timeout $Timeout
            return $result.Result
        }
        else {
            # No updates info, fall back to toast
            $Type = 'Toast'
        }
    }

    # Get scenario based on deferral phase for toasts
    $scenario = Get-ToastScenarioForPhase -Phase $phase -Config $config

    switch ($Type) {
        'Toast' {
            $appName = if ($Updates -and $Updates[0]) { $Updates[0].AppName } else { $null }
            $canDefer = $true
            $deferralsRemaining = 5

            if ($Updates -and $Updates[0]) {
                $deferralState = Get-StateFromRegistry -AppId $Updates[0].AppId
                if ($deferralState) {
                    $canDefer = $deferralState.CanDefer()
                    $deferralsRemaining = $deferralState.GetRemainingDeferrals()
                }
            }

            # Use native toast with enterprise features
            Show-NativeToast `
                -Title $config.Notifications.ToastTitle `
                -Message "$count update(s) ready to install. Click to proceed." `
                -AppName $appName `
                -Scenario $scenario `
                -DeferralsRemaining $deferralsRemaining `
                -CanDefer $canDefer
        }
        'Dialog' {
            Show-DeferralDialogFull -Updates $Updates -Config $config -Timeout $Timeout
        }
        'FullScreen' {
            # Determine if defer should be allowed based on phase
            $allowDefer = ($phase -ne [DeferralPhase]::Elapsed) -or ($phase -eq [DeferralPhase]::Elapsed)  # Allow 1hr defer even in elapsed
            Show-FullScreenPrompt -Updates $Updates -Config $config -Timeout $Timeout -AllowDefer $allowDefer
        }
        'Both' {
            $appName = if ($Updates -and $Updates[0]) { $Updates[0].AppName } else { $null }
            Show-NativeToast `
                -Title $config.Notifications.ToastTitle `
                -Message "Updates require your attention" `
                -AppName $appName `
                -Scenario $scenario

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

function Show-FullScreenPrompt {
    <#
    .SYNOPSIS
        Shows a full-screen interstitial prompt (RUXIM-style)
    .DESCRIPTION
        Displays a maximized, topmost window for critical updates when deferral
        deadline has elapsed. Replicates Microsoft's Windows 11 upgrade prompt pattern.
    .PARAMETER Updates
        Array of pending updates
    .PARAMETER Config
        PsPatchMyPC configuration object
    .PARAMETER Timeout
        Auto-proceed timeout in seconds
    .PARAMETER AllowDefer
        Allow one-hour deferral option (for elapsed phase)
    .OUTPUTS
        'Update', 'Defer', or 'Timeout'
    .EXAMPLE
        $result = Show-FullScreenPrompt -Updates $updates -Timeout 300
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PatchStatus[]]$Updates,

        [Parameter()]
        [PsPatchMyPCConfig]$Config,

        [Parameter()]
        [int]$Timeout = 300,

        [Parameter()]
        [bool]$AllowDefer = $false
    )

    if (-not $Config) { $Config = Get-PatchMyPCConfig }

    # Check if we need to run as user
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $isSystem = $currentUser.User.Value -eq 'S-1-5-18'
    }
    catch { $isSystem = $false }

    if ($isSystem -and (Test-UserSessionActive)) {
        # Run in user session
        try {
            $resultDir = Join-Path $env:PUBLIC 'PsPatchMyPC'
            if (-not (Test-Path $resultDir)) { New-Item -Path $resultDir -ItemType Directory -Force | Out-Null }
            $resultFile = Join-Path $resultDir ("fullscreen_prompt_{0}.txt" -f ([guid]::NewGuid().ToString('n')))
            if (Test-Path $resultFile) { Remove-Item -Path $resultFile -Force -ErrorAction SilentlyContinue }

            $moduleRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
            $manifest = Join-Path $moduleRoot 'PsPatchMyPC.psd1'

            $sb = [scriptblock]::Create(@"
Import-Module '$manifest' -Force -ErrorAction SilentlyContinue
`$cfg = Get-PatchMyPCConfig
`$choice = Show-FullScreenPrompt -Config `$cfg -Timeout $Timeout -AllowDefer `$$AllowDefer
Set-Content -Path '$resultFile' -Value `$choice -Encoding ASCII -Force
"@)

            Invoke-AsCurrentUser -ScriptBlock $sb -Wait | Out-Null

            if (Test-Path $resultFile) {
                $choice = (Get-Content -Path $resultFile -ErrorAction SilentlyContinue | Select-Object -First 1)
                Remove-Item -Path $resultFile -Force -ErrorAction SilentlyContinue
                if ($choice -in @('Update', 'Defer', 'Timeout')) { return $choice }
            }
        }
        catch {
            Write-PatchLog "Failed to show full-screen prompt in user session: $_" -Type Warning
        }
        return 'Timeout'
    }

    # WPF requires STA thread
    $currentThread = [System.Threading.Thread]::CurrentThread
    if ($currentThread.GetApartmentState() -ne 'STA') {
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = 'STA'
        $runspace.ThreadOptions = 'ReuseThread'
        $runspace.Open()

        $ps = [powershell]::Create()
        $ps.Runspace = $runspace

        $enterpriseConfig = $Config.Notifications.Enterprise
        $title = if ($enterpriseConfig.FullScreenTitle) { $enterpriseConfig.FullScreenTitle } else { "Action Required" }
        $message = if ($enterpriseConfig.FullScreenMessage) { $enterpriseConfig.FullScreenMessage } else { "Important updates must be installed now." }
        $heroImage = $enterpriseConfig.FullScreenHeroImage

        $null = $ps.AddScript({
            param($Title, $Subtitle, $Message, $AccentColor, $AllowDefer, $Timeout, $HeroImage)

            Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue

            $xamlParams = @{
                Title = $Title
                Subtitle = $Subtitle
                Headline = "Your device requires attention"
                Message = $Message
                AccentColor = $AccentColor
                ShowDeferButton = $AllowDefer
                DeferButtonLabel = "Remind me in 1 hour"
            }
            if ($HeroImage) { $xamlParams.HeroImagePath = $HeroImage }

            $xaml = Get-FullScreenInterstitialXaml @xamlParams

            [xml]$xamlXml = $xaml
            $reader = New-Object System.Xml.XmlNodeReader $xamlXml
            $window = [Windows.Markup.XamlReader]::Load($reader)

            $script:dialogResult = 'Timeout'
            $script:remainingSeconds = $Timeout

            $countdownText = $window.FindName("CountdownText")
            $updateButton = $window.FindName("UpdateButton")
            $deferButton = $window.FindName("DeferButton")

            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromSeconds(1)
            $timer.Add_Tick({
                $script:remainingSeconds--
                $mins = [Math]::Floor($script:remainingSeconds / 60)
                $secs = $script:remainingSeconds % 60
                $countdownText.Text = "{0}:{1:D2}" -f $mins, $secs

                if ($script:remainingSeconds -le 0) {
                    $timer.Stop()
                    $script:dialogResult = 'Update'
                    $window.Close()
                }
            })

            if ($updateButton) {
                $updateButton.Add_Click({
                    $timer.Stop()
                    $script:dialogResult = 'Update'
                    $window.Close()
                })
            }

            if ($deferButton -and $AllowDefer) {
                $deferButton.Add_Click({
                    $timer.Stop()
                    $script:dialogResult = 'Defer'
                    $window.Close()
                })
            }

            # Allow Escape to minimize (not close)
            $window.Add_KeyDown({
                param($sender, $e)
                if ($e.Key -eq 'Escape') {
                    $window.WindowState = 'Minimized'
                }
            })

            $window.Add_Loaded({ $timer.Start() })
            $window.ShowDialog() | Out-Null

            return $script:dialogResult
        })

        $null = $ps.AddArgument($title)
        $null = $ps.AddArgument($Config.Notifications.CompanyName)
        $null = $ps.AddArgument($message)
        $null = $ps.AddArgument($Config.Notifications.AccentColor)
        $null = $ps.AddArgument($AllowDefer)
        $null = $ps.AddArgument($Timeout)
        $null = $ps.AddArgument($heroImage)

        try {
            $r = $ps.Invoke()
            Write-PatchLog "Full-screen prompt result: $($r[0])" -Type Info
            return $r[0]
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

        $enterpriseConfig = $Config.Notifications.Enterprise
        $title = if ($enterpriseConfig.FullScreenTitle) { $enterpriseConfig.FullScreenTitle } else { "Action Required" }
        $message = if ($enterpriseConfig.FullScreenMessage) { $enterpriseConfig.FullScreenMessage } else { "Important updates must be installed now." }

        $xamlParams = @{
            Title = $title
            Subtitle = $Config.Notifications.CompanyName
            Headline = "Your device requires attention"
            Message = $message
            AccentColor = $Config.Notifications.AccentColor
            ShowDeferButton = $AllowDefer
            DeferButtonLabel = "Remind me in 1 hour"
        }
        if ($enterpriseConfig.FullScreenHeroImage) {
            $xamlParams.HeroImagePath = $enterpriseConfig.FullScreenHeroImage
        }

        $xaml = Get-FullScreenInterstitialXaml @xamlParams

        [xml]$xamlXml = $xaml
        $reader = New-Object System.Xml.XmlNodeReader $xamlXml
        $window = [Windows.Markup.XamlReader]::Load($reader)

        $script:dialogResult = 'Timeout'
        $script:remainingSeconds = $Timeout

        $countdownText = $window.FindName("CountdownText")
        $updateButton = $window.FindName("UpdateButton")
        $deferButton = $window.FindName("DeferButton")

        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(1)
        $timer.Add_Tick({
            $script:remainingSeconds--
            $mins = [Math]::Floor($script:remainingSeconds / 60)
            $secs = $script:remainingSeconds % 60
            $countdownText.Text = "{0}:{1:D2}" -f $mins, $secs

            if ($script:remainingSeconds -le 0) {
                $timer.Stop()
                $script:dialogResult = 'Update'
                $window.Close()
            }
        })

        if ($updateButton) {
            $updateButton.Add_Click({
                $timer.Stop()
                $script:dialogResult = 'Update'
                $window.Close()
            })
        }

        if ($deferButton -and $AllowDefer) {
            $deferButton.Add_Click({
                $timer.Stop()
                $script:dialogResult = 'Defer'
                $window.Close()
            })
        }

        $window.Add_KeyDown({
            param($sender, $e)
            if ($e.Key -eq 'Escape') {
                $window.WindowState = 'Minimized'
            }
        })

        $window.Add_Loaded({ $timer.Start() })
        $window.ShowDialog() | Out-Null

        Write-PatchLog "Full-screen prompt result: $script:dialogResult" -Type Info
        return $script:dialogResult
    }
    catch {
        Write-PatchLog "Failed to show full-screen prompt: $_" -Type Error
        return 'Timeout'
    }
}

function Show-RebootPrompt {
    <#
    .SYNOPSIS
        Shows a reboot prompt (Restart now / Later) using the same WPF UX as PsPatchMyPC.
    .OUTPUTS
        'RestartNow' or 'Later'
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PsPatchMyPCConfig]$Config,

        [Parameter()]
        [int]$Timeout = 300
    )
    
    if (-not $Config) { $Config = Get-PatchMyPCConfig }

    # If running as SYSTEM, show the prompt in the active user session via Invoke-AsCurrentUser
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $isSystem = $currentUser.User.Value -eq 'S-1-5-18'
    }
    catch { $isSystem = $false }

    if ($isSystem) {
        try {
            $resultDir = Join-Path $env:PUBLIC 'PsPatchMyPC'
            if (-not (Test-Path $resultDir)) { New-Item -Path $resultDir -ItemType Directory -Force | Out-Null }
            $resultFile = Join-Path $resultDir ("reboot_prompt_{0}.txt" -f ([guid]::NewGuid().ToString('n')))
            if (Test-Path $resultFile) { Remove-Item -Path $resultFile -Force -ErrorAction SilentlyContinue }

            $selfModulePath = $PSScriptRoot  # PsPatchMyPC/Public
            $moduleRoot = Split-Path $selfModulePath -Parent
            $manifest = Join-Path $moduleRoot 'PsPatchMyPC.psd1'

            $sb = [scriptblock]::Create(@"
Import-Module '$manifest' -Force -ErrorAction SilentlyContinue
\$cfg = Get-PatchMyPCConfig
\$choice = Show-RebootPrompt -Config \$cfg -Timeout $Timeout
Set-Content -Path '$resultFile' -Value \$choice -Encoding ASCII -Force
"@)

            Invoke-AsCurrentUser -ScriptBlock $sb -Wait | Out-Null

            if (Test-Path $resultFile) {
                $choice = (Get-Content -Path $resultFile -ErrorAction SilentlyContinue | Select-Object -First 1)
                Remove-Item -Path $resultFile -Force -ErrorAction SilentlyContinue
                if ($choice -in @('RestartNow', 'Later')) { return $choice }
            }
        }
        catch {
            Write-PatchLog "Failed to show reboot prompt in user session: $_" -Type Warning
        }
        return 'Later'
    }
    
    # WPF requires STA thread - run in separate runspace if needed
    $currentThread = [System.Threading.Thread]::CurrentThread
    if ($currentThread.GetApartmentState() -ne 'STA') {
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = 'STA'
        $runspace.ThreadOptions = 'ReuseThread'
        $runspace.Open()
        
        $ps = [powershell]::Create()
        $ps.Runspace = $runspace
        
        $null = $ps.AddScript({
            param($AccentColor, $CompanyName, $Timeout)
            Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
            
            $xaml = Get-RebootPromptDialogXaml -AccentColor $AccentColor -CompanyName $CompanyName
            $window = Show-WPFDialog -Xaml $xaml -Timeout $Timeout
            if (-not $window) { return 'Later' }
            
            $script:dialogResult = 'Later'
            
            $restartButton = $window.FindName("RestartButton")
            $laterButton = $window.FindName("LaterButton")
            
            if ($restartButton) {
                $restartButton.Add_Click({
                    $script:dialogResult = 'RestartNow'
                    $window.Close()
                })
            }
            if ($laterButton) {
                $laterButton.Add_Click({
                    $script:dialogResult = 'Later'
                    $window.Close()
                })
            }
            
            # Auto-close timeout => Later
            $script:remainingSeconds = $Timeout
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromSeconds(1)
            $timer.Add_Tick({
                $script:remainingSeconds--
                if ($script:remainingSeconds -le 0) {
                    $timer.Stop()
                    $script:dialogResult = 'Later'
                    $window.Close()
                }
            })
            $window.Add_Loaded({ $timer.Start() })
            
            $window.ShowDialog() | Out-Null
            return $script:dialogResult
        })
        
        $null = $ps.AddArgument($Config.Notifications.AccentColor)
        $null = $ps.AddArgument($Config.Notifications.CompanyName)
        $null = $ps.AddArgument($Timeout)
        
        try {
            $r = $ps.Invoke()
            return $r[0]
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
        
        $xaml = Get-RebootPromptDialogXaml -AccentColor $Config.Notifications.AccentColor -CompanyName $Config.Notifications.CompanyName
        $window = Show-WPFDialog -Xaml $xaml -Timeout $Timeout
        if (-not $window) { return 'Later' }
        
        $script:dialogResult = 'Later'
        
        $restartButton = $window.FindName("RestartButton")
        $laterButton = $window.FindName("LaterButton")
        
        if ($restartButton) {
            $restartButton.Add_Click({
                $script:dialogResult = 'RestartNow'
                $window.Close()
            })
        }
        if ($laterButton) {
            $laterButton.Add_Click({
                $script:dialogResult = 'Later'
                $window.Close()
            })
        }
        
        $script:remainingSeconds = $Timeout
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(1)
        $timer.Add_Tick({
            $script:remainingSeconds--
            if ($script:remainingSeconds -le 0) {
                $timer.Stop()
                $script:dialogResult = 'Later'
                $window.Close()
            }
        })
        $window.Add_Loaded({ $timer.Start() })
        
        $window.ShowDialog() | Out-Null
        return $script:dialogResult
    }
    catch {
        Write-PatchLog "Failed to show reboot prompt: $_" -Type Warning
        return 'Later'
    }
}

