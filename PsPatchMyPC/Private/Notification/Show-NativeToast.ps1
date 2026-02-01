function Show-NativeToast {
    <#
    .SYNOPSIS
        Shows a native Windows toast notification using Windows.UI.Notifications
    .DESCRIPTION
        Creates and displays a Windows toast notification with proper Action Center
        integration. Supports scenarios (Default, Reminder, Urgent), action buttons,
        and custom icons. Falls back to BurntToast or WPF if native APIs unavailable.
    .PARAMETER Title
        The notification title
    .PARAMETER Message
        The notification body message
    .PARAMETER AppName
        Optional application name to display
    .PARAMETER Scenario
        Toast scenario: Default, Reminder, Alarm, IncomingCall, Urgent
    .PARAMETER Actions
        Array of action hashtables with Label and Action keys
    .PARAMETER DeferralsRemaining
        Number of deferrals remaining (shown on defer button)
    .PARAMETER CanDefer
        Whether deferral is allowed
    .PARAMETER IconPath
        Path to notification icon image
    .PARAMETER HeroImagePath
        Path to hero image (displayed at top of toast)
    .PARAMETER ExpirationTime
        When the notification should expire from Action Center
    .PARAMETER Tag
        Unique tag for the notification (for updates/replacement)
    .PARAMETER Group
        Group identifier for notification grouping
    .EXAMPLE
        Show-NativeToast -Title "Update Available" -Message "Chrome needs updating" -Scenario Reminder
    .EXAMPLE
        Show-NativeToast -Title "Critical Update" -Message "Security patch required" -Scenario Urgent -CanDefer $false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter()]
        [string]$Message,

        [Parameter()]
        [string]$AppName,

        [Parameter()]
        [ValidateSet('Default', 'Reminder', 'Alarm', 'IncomingCall', 'Urgent')]
        [string]$Scenario = 'Default',

        [Parameter()]
        [hashtable[]]$Actions,

        [Parameter()]
        [int]$DeferralsRemaining = 5,

        [Parameter()]
        [bool]$CanDefer = $true,

        [Parameter()]
        [string]$IconPath,

        [Parameter()]
        [string]$HeroImagePath,

        [Parameter()]
        [datetime]$ExpirationTime,

        [Parameter()]
        [string]$Tag,

        [Parameter()]
        [string]$Group = 'PsPatchMyPC'
    )

    $config = Get-PatchMyPCConfig

    # Try native Windows toast notification first
    if (Test-NativeToastSupport) {
        try {
            $result = Send-NativeWindowsToast @PSBoundParameters
            if ($result) {
                Write-PatchLog "Displayed native Windows toast: $Title" -Type Info
                return $result
            }
        }
        catch {
            Write-PatchLog "Native toast failed, trying fallback: $_" -Type Warning
        }
    }

    # Fallback to BurntToast if available
    try {
        $bt = Get-Module -Name BurntToast -ListAvailable -ErrorAction SilentlyContinue
        if ($bt) {
            Import-Module BurntToast -Force -ErrorAction Stop
            $btParams = @{
                Text = @($Title, $Message)
            }

            if ($IconPath -and (Test-Path $IconPath)) {
                $btParams.AppLogo = $IconPath
            }
            elseif ($config.Notifications.CompanyLogoPath -and (Test-Path $config.Notifications.CompanyLogoPath)) {
                $btParams.AppLogo = $config.Notifications.CompanyLogoPath
            }

            # Add buttons if actions enabled
            if ($config.Notifications.Enterprise.EnableToastActions) {
                $buttons = @()
                $updateLabel = $config.Notifications.Enterprise.ToastActionUpdateLabel
                $deferLabel = $config.Notifications.Enterprise.ToastActionDeferLabel

                $buttons += New-BTButton -Content $updateLabel -Arguments "action=update" -ActivationType Protocol
                if ($CanDefer) {
                    $deferText = if ($DeferralsRemaining -gt 0) { "$deferLabel ($DeferralsRemaining)" } else { $deferLabel }
                    $buttons += New-BTButton -Content $deferText -Arguments "action=defer" -ActivationType Protocol
                }

                $btParams.Button = $buttons
            }

            New-BurntToastNotification @btParams
            Write-PatchLog "Displayed BurntToast notification: $Title" -Type Info
            return @{ Success = $true; Method = 'BurntToast' }
        }
    }
    catch {
        Write-PatchLog "BurntToast failed: $_" -Type Warning
    }

    # Final fallback: WPF toast with actions
    try {
        Add-Type -AssemblyName PresentationFramework, System.Windows.Forms -ErrorAction SilentlyContinue

        $xamlParams = @{
            Title = $Title
            Message = $Message
            AccentColor = $config.Notifications.AccentColor
        }

        if ($AppName) { $xamlParams.AppName = $AppName }
        if ($CanDefer) {
            $xamlParams.CanDefer = $true
            $xamlParams.DeferralsRemaining = $DeferralsRemaining
        }

        $xaml = Get-ToastNotificationWithActionsXaml @xamlParams
        return Show-WPFToastWithActions -Xaml $xaml -Timeout 15
    }
    catch {
        Write-PatchLog "All toast methods failed: $_" -Type Error
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Test-NativeToastSupport {
    <#
    .SYNOPSIS
        Tests if native Windows toast notifications are supported
    #>
    [CmdletBinding()]
    param()

    try {
        # Check Windows version (10+)
        $osVersion = [System.Environment]::OSVersion.Version
        if ($osVersion.Major -lt 10) {
            return $false
        }

        # Check if WinRT is available
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        return $true
    }
    catch {
        return $false
    }
}

function Send-NativeWindowsToast {
    <#
    .SYNOPSIS
        Sends a toast notification using Windows.UI.Notifications WinRT API
    .DESCRIPTION
        Creates XML-based toast notification with full Action Center support
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter()]
        [string]$Message,

        [Parameter()]
        [string]$AppName,

        [Parameter()]
        [string]$Scenario = 'Default',

        [Parameter()]
        [hashtable[]]$Actions,

        [Parameter()]
        [int]$DeferralsRemaining = 5,

        [Parameter()]
        [bool]$CanDefer = $true,

        [Parameter()]
        [string]$IconPath,

        [Parameter()]
        [string]$HeroImagePath,

        [Parameter()]
        [datetime]$ExpirationTime,

        [Parameter()]
        [string]$Tag,

        [Parameter()]
        [string]$Group = 'PsPatchMyPC'
    )

    $config = Get-PatchMyPCConfig

    # Load WinRT assemblies
    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]
    }
    catch {
        throw "WinRT assemblies not available: $_"
    }

    # Build toast scenario attribute
    $scenarioAttr = switch ($Scenario) {
        'Reminder' { ' scenario="reminder"' }
        'Alarm' { ' scenario="alarm"' }
        'IncomingCall' { ' scenario="incomingCall"' }
        'Urgent' { ' scenario="urgent"' }
        default { '' }
    }

    # Build image elements
    $iconElement = ""
    if ($IconPath -and (Test-Path $IconPath)) {
        $iconElement = "<image placement='appLogoOverride' src='file:///$($IconPath -replace '\\','/')'/>"
    }
    elseif ($config.Notifications.CompanyLogoPath -and (Test-Path $config.Notifications.CompanyLogoPath)) {
        $logoPath = $config.Notifications.CompanyLogoPath -replace '\\', '/'
        $iconElement = "<image placement='appLogoOverride' src='file:///$logoPath'/>"
    }

    $heroElement = ""
    if ($HeroImagePath -and (Test-Path $HeroImagePath)) {
        $heroPath = $HeroImagePath -replace '\\', '/'
        $heroElement = "<image placement='hero' src='file:///$heroPath'/>"
    }

    # Build action buttons
    $actionsXml = ""
    if ($config.Notifications.Enterprise.EnableToastActions) {
        $protocol = $config.Notifications.Enterprise.ProtocolScheme
        $updateLabel = $config.Notifications.Enterprise.ToastActionUpdateLabel
        $deferLabel = $config.Notifications.Enterprise.ToastActionDeferLabel

        $buttonsXml = "<action content='$updateLabel' arguments='$($protocol):action=update' activationType='protocol'/>"

        if ($CanDefer -and $DeferralsRemaining -gt 0) {
            $deferText = "$deferLabel ($DeferralsRemaining)"
            $buttonsXml += "<action content='$deferText' arguments='$($protocol):action=defer' activationType='protocol'/>"
        }

        $actionsXml = "<actions>$buttonsXml</actions>"
    }

    # Build complete toast XML
    $appNameLine = if ($AppName) { "<text hint-style='captionSubtle'>$AppName</text>" } else { "" }

    $toastXml = @"
<toast$scenarioAttr>
    <visual>
        <binding template='ToastGeneric'>
            <text hint-style='title'>$Title</text>
            $appNameLine
            <text>$Message</text>
            $iconElement
            $heroElement
        </binding>
    </visual>
    $actionsXml
    <audio silent='false'/>
</toast>
"@

    # Create and show notification
    try {
        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($toastXml)

        # Use PowerShell as the AUMID (works without requiring custom app registration)
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)

        if ($Tag) {
            $toast.Tag = $Tag
        }
        if ($Group) {
            $toast.Group = $Group
        }
        if ($ExpirationTime) {
            $toast.ExpirationTime = $ExpirationTime
        }

        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
        $notifier.Show($toast)

        return @{
            Success = $true
            Method = 'NativeWinRT'
            Tag = $Tag
            Group = $Group
        }
    }
    catch {
        throw "Failed to display native toast: $_"
    }
}

function Show-WPFToastWithActions {
    <#
    .SYNOPSIS
        Shows a WPF toast with action buttons and returns user choice
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Xaml,

        [Parameter()]
        [int]$Timeout = 15
    )

    # WPF requires STA thread
    $currentThread = [System.Threading.Thread]::CurrentThread
    if ($currentThread.GetApartmentState() -ne 'STA') {
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.ApartmentState = 'STA'
        $runspace.ThreadOptions = 'ReuseThread'
        $runspace.Open()

        $ps = [powershell]::Create()
        $ps.Runspace = $runspace

        $null = $ps.AddScript({
            param($XamlContent, $TimeoutSecs)

            Add-Type -AssemblyName PresentationFramework, System.Windows.Forms -ErrorAction SilentlyContinue

            [xml]$xamlXml = $XamlContent
            $reader = New-Object System.Xml.XmlNodeReader $xamlXml
            $window = [Windows.Markup.XamlReader]::Load($reader)

            # Position bottom-right
            $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $window.Left = $workingArea.Right - 440
            $window.Top = $workingArea.Bottom - 180

            $script:result = 'Dismissed'
            $script:remainingSeconds = $TimeoutSecs

            $closeBtn = $window.FindName("CloseButton")
            $deferBtn = $window.FindName("DeferButton")
            $updateBtn = $window.FindName("UpdateButton")

            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromSeconds(1)
            $timer.Add_Tick({
                $script:remainingSeconds--
                if ($script:remainingSeconds -le 0) {
                    $timer.Stop()
                    $script:result = 'Timeout'
                    $window.Close()
                }
            })

            if ($closeBtn) {
                $closeBtn.Add_Click({
                    $timer.Stop()
                    $script:result = 'Dismissed'
                    $window.Close()
                })
            }
            if ($deferBtn -and $deferBtn.IsEnabled) {
                $deferBtn.Add_Click({
                    $timer.Stop()
                    $script:result = 'Defer'
                    $window.Close()
                })
            }
            if ($updateBtn) {
                $updateBtn.Add_Click({
                    $timer.Stop()
                    $script:result = 'Update'
                    $window.Close()
                })
            }

            $window.Add_Loaded({ $timer.Start() })
            $window.ShowDialog() | Out-Null

            return @{ Success = $true; Method = 'WPFToast'; Result = $script:result }
        })

        $null = $ps.AddArgument($Xaml)
        $null = $ps.AddArgument($Timeout)

        try {
            $result = $ps.Invoke()
            return $result[0]
        }
        finally {
            $ps.Dispose()
            $runspace.Close()
            $runspace.Dispose()
        }
    }

    # Already in STA
    Add-Type -AssemblyName PresentationFramework, System.Windows.Forms -ErrorAction SilentlyContinue

    [xml]$xamlXml = $Xaml
    $reader = New-Object System.Xml.XmlNodeReader $xamlXml
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $window.Left = $workingArea.Right - 440
    $window.Top = $workingArea.Bottom - 180

    $script:result = 'Dismissed'
    $script:remainingSeconds = $Timeout

    $closeBtn = $window.FindName("CloseButton")
    $deferBtn = $window.FindName("DeferButton")
    $updateBtn = $window.FindName("UpdateButton")

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        $script:remainingSeconds--
        if ($script:remainingSeconds -le 0) {
            $timer.Stop()
            $script:result = 'Timeout'
            $window.Close()
        }
    })

    if ($closeBtn) {
        $closeBtn.Add_Click({
            $timer.Stop()
            $script:result = 'Dismissed'
            $window.Close()
        })
    }
    if ($deferBtn -and $deferBtn.IsEnabled) {
        $deferBtn.Add_Click({
            $timer.Stop()
            $script:result = 'Defer'
            $window.Close()
        })
    }
    if ($updateBtn) {
        $updateBtn.Add_Click({
            $timer.Stop()
            $script:result = 'Update'
            $window.Close()
        })
    }

    $window.Add_Loaded({ $timer.Start() })
    $window.ShowDialog() | Out-Null

    return @{ Success = $true; Method = 'WPFToast'; Result = $script:result }
}

function Remove-ToastNotification {
    <#
    .SYNOPSIS
        Removes a toast notification from Action Center
    .PARAMETER Tag
        The tag of the notification to remove
    .PARAMETER Group
        The group of the notification
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Tag,

        [Parameter()]
        [string]$Group = 'PsPatchMyPC'
    )

    if (-not (Test-NativeToastSupport)) {
        return
    }

    try {
        $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

        $history = [Windows.UI.Notifications.ToastNotificationManager]::History

        if ($Tag -and $Group) {
            $history.Remove($Tag, $Group, $appId)
        }
        elseif ($Group) {
            $history.RemoveGroup($Group, $appId)
        }
        else {
            $history.Clear($appId)
        }
    }
    catch {
        Write-PatchLog "Failed to remove toast notification: $_" -Type Warning
    }
}
