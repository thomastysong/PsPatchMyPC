#Requires -Version 5.1
<#
.SYNOPSIS
    Classes and enums for PsPatchMyPC module
.DESCRIPTION
    Defines typed objects for patch status, deferral state, and configuration
#>

# Deferral phase enum
enum DeferralPhase {
    Initial      # 5hr refresh, all deferral options
    Approaching  # 100min refresh, limited options
    Imminent     # 10min refresh, 1hr/4hr only
    Elapsed      # 5min refresh, 1hr max (aggressive)
}

# Notification type enum (enterprise notifications)
enum NotificationType {
    Toast           # Standard Windows toast notification (Action Center)
    Dialog          # Modal WPF deferral dialog (center screen)
    FullScreen      # Full-screen interstitial prompt (RUXIM-style)
    Reminder        # Persistent toast that stays until dismissed
    Urgent          # Urgent toast that bypasses Focus Assist
}

# Notification scenario for toast behavior
enum ToastScenario {
    Default         # Standard toast behavior (auto-dismiss)
    Reminder        # Stays on screen until user acts, shows in Action Center
    Alarm           # Looping audio, stays on screen
    IncomingCall    # Special call-style UI
    Urgent          # Bypasses Focus Assist (Windows 11+)
}

# Update priority enum
enum UpdatePriority {
    Critical
    High
    Normal
    Low
}

# Installation status enum
enum InstallationStatus {
    Pending
    InProgress
    Success
    Failed
    Deferred
    Cancelled
}

# Patch status class
class PatchStatus {
    [string]$AppId
    [string]$AppName
    [string]$InstalledVersion
    [string]$AvailableVersion
    [bool]$UpdateAvailable
    [UpdatePriority]$Priority
    [string[]]$ConflictingProcesses
    [bool]$ProcessesRunning
    [datetime]$LastChecked
    
    PatchStatus() {
        $this.LastChecked = [datetime]::UtcNow
        $this.UpdateAvailable = $false
        $this.Priority = [UpdatePriority]::Normal
        $this.ConflictingProcesses = @()
        $this.ProcessesRunning = $false
    }
    
    [string] ToString() {
        return "$($this.AppName) [$($this.InstalledVersion) -> $($this.AvailableVersion)]"
    }
}

# Deferral state class
class DeferralState {
    [string]$AppId
    [int]$DeferralCount
    [datetime]$FirstNotification
    [datetime]$LastDeferral
    [string]$TargetVersion
    [datetime]$DeadlineDate
    [DeferralPhase]$Phase
    [int]$MaxDeferrals
    
    DeferralState() {
        $this.DeferralCount = 0
        $this.Phase = [DeferralPhase]::Initial
        $this.MaxDeferrals = 5
        $this.TargetVersion = 'Latest'  # Default to prevent empty strings
    }
    
    [bool] CanDefer() {
        if ($this.Phase -eq [DeferralPhase]::Elapsed) { return $false }
        if ($this.DeferralCount -ge $this.MaxDeferrals) { return $false }
        return $true
    }
    
    [int] GetRemainingDeferrals() {
        return [Math]::Max(0, $this.MaxDeferrals - $this.DeferralCount)
    }
    
    [string[]] GetAvailableOptions() {
        $options = @('1 Hour')
        switch ($this.Phase) {
            'Initial' { $options = @('1 Hour', '4 Hours', 'Tomorrow', 'Custom') }
            'Approaching' { $options = @('1 Hour', '4 Hours', 'Tomorrow') }
            'Imminent' { $options = @('1 Hour', '4 Hours') }
            'Elapsed' { $options = @('1 Hour') }
        }
        return $options
    }
}

# Installation result class
class InstallationResult {
    [string]$AppId
    [string]$AppName
    [InstallationStatus]$Status
    [int]$ExitCode
    [string]$Message
    [datetime]$Timestamp
    [timespan]$Duration
    [bool]$RebootRequired
    
    InstallationResult() {
        $this.Timestamp = [datetime]::UtcNow
        $this.Status = [InstallationStatus]::Pending
        $this.RebootRequired = $false
    }
}

# Patch cycle result class
class PatchCycleResult {
    [bool]$Success
    [string]$Message
    [int]$TotalUpdates
    [int]$Installed
    [int]$Failed
    [int]$Deferred
    [bool]$RebootRequired
    [datetime]$StartTime
    [datetime]$EndTime
    [timespan]$Duration
    [InstallationResult[]]$Results
    [string]$CorrelationId
    
    PatchCycleResult() {
        $this.CorrelationId = [guid]::NewGuid().ToString()
        $this.StartTime = [datetime]::UtcNow
        $this.Results = @()
        $this.Success = $true
        $this.RebootRequired = $false
    }
    
    [void] Complete() {
        $this.EndTime = [datetime]::UtcNow
        $this.Duration = $this.EndTime - $this.StartTime
    }
}

# Managed application class
class ManagedApplication {
    [string]$Id
    [string]$Name
    [bool]$Enabled
    [UpdatePriority]$Priority
    [string[]]$ConflictingProcesses
    [string]$PreScript
    [string]$PostScript
    [string]$InstallArguments
    [bool]$RequiresReboot
    [hashtable]$DeferralOverride
    # New properties for install missing and version pinning
    [bool]$InstallIfMissing
    [bool]$DeferInitialInstall
    [string]$VersionPinMode      # max, exact, freeze, or $null for normal
    [string]$PinnedVersion
    
    ManagedApplication() {
        $this.Enabled = $true
        $this.Priority = [UpdatePriority]::Normal
        $this.ConflictingProcesses = @()
        $this.RequiresReboot = $false
        $this.InstallIfMissing = $false
        $this.DeferInitialInstall = $false
        $this.VersionPinMode = $null
        $this.PinnedVersion = $null
    }
    
    static [ManagedApplication] FromHashtable([hashtable]$ht) {
        $app = [ManagedApplication]::new()
        $app.Id = $ht.Id
        $app.Name = $ht.Name
        if ($null -ne $ht.Enabled) { $app.Enabled = $ht.Enabled }
        if ($ht.Priority) { $app.Priority = [UpdatePriority]$ht.Priority }
        if ($ht.ConflictingProcesses) { $app.ConflictingProcesses = $ht.ConflictingProcesses }
        if ($ht.PreScript) { $app.PreScript = $ht.PreScript }
        if ($ht.PostScript) { $app.PostScript = $ht.PostScript }
        if ($ht.InstallArguments) { $app.InstallArguments = $ht.InstallArguments }
        if ($null -ne $ht.RequiresReboot) { $app.RequiresReboot = $ht.RequiresReboot }
        if ($ht.DeferralOverride) { $app.DeferralOverride = $ht.DeferralOverride }
        # New properties
        if ($null -ne $ht.InstallIfMissing) { $app.InstallIfMissing = $ht.InstallIfMissing }
        if ($null -ne $ht.DeferInitialInstall) { $app.DeferInitialInstall = $ht.DeferInitialInstall }
        if ($ht.VersionPinMode) { $app.VersionPinMode = $ht.VersionPinMode }
        if ($ht.PinnedVersion) { $app.PinnedVersion = $ht.PinnedVersion }
        return $app
    }
}

# Module configuration class
class PsPatchMyPCConfig {
    [string]$LogPath
    [string]$StatePath
    [string]$ConfigPath
    [string]$EventLogName
    [string]$EventLogSource
    [string]$StateRegistryKey
    [hashtable]$Deferrals
    [hashtable]$Notifications
    [hashtable]$Updates
    [hashtable]$DriverManagement
    [ManagedApplication[]]$Applications
    
    PsPatchMyPCConfig() {
        $this.Deferrals = @{
            Mode = 'CountAndDeadline'
            MaxCount = 5
            DeadlineDays = 7
            ApproachingWindowHours = 72
            ImminentWindowHours = 24
            InitialRefreshSeconds = 18000
            ApproachingRefreshSeconds = 6000
            ImminentRefreshSeconds = 600
            ElapsedRefreshSeconds = 300
        }
        $this.Notifications = @{
            EnableToasts = $true
            EnableDeferralDialog = $true
            EnableProgressDialog = $true
            EnableAggressiveMode = $true
            CompanyName = 'IT Department'
            AccentColor = '#0078D4'
            Enterprise = @{
                EnableFullScreenPrompts = $true
                FullScreenTimeoutSeconds = 300
                FullScreenTitle = 'Action Required'
                FullScreenMessage = 'Important updates must be installed now.'
                InitialToastScenario = 'Default'
                ApproachingToastScenario = 'Reminder'
                ImminentToastScenario = 'Urgent'
                ElapsedToastScenario = 'Urgent'
                EnableToastActions = $true
                ProtocolScheme = 'pspatchmypc'
                EscalateToFullScreen = $true
                EscalateAfterDismissals = 3
            }
        }
        $this.Updates = @{
            CheckIntervalHours = 4
            InstallWindowStart = '03:00'
            InstallWindowEnd = '05:00'
            SkipMeteredConnections = $true
        }
        $this.DriverManagement = @{
            Enabled = $false
            IncludeWindowsUpdates = $true
            UiTimeoutSeconds = 60
            DeferralOverride = @{
                MaxCount = 3
                DeadlineDays = 7
            }
        }
        $this.Applications = @()
    }
}

