@{
    SchemaVersion = '1.0.0'
    
    Application = @{
        Name              = 'PsPatchMyPC'
        LogLevel          = 'Information'
        MaxLogSizeMB      = 50
        LogRetentionDays  = 30
    }
    
    Updates = @{
        CheckIntervalHours     = 4
        InstallWindowStart     = '03:00'
        InstallWindowEnd       = '05:00'
        RebootGraceMinutes     = 1440
        SkipMeteredConnections = 'true'
        MaxConcurrentInstalls  = 1
        RetryCount             = 3
        RetryDelayMinutes      = 5
    }
    
    Deferrals = @{
        Mode                      = 'CountAndDeadline'
        MaxCount                  = 5
        DeadlineDays              = 7
        ApproachingWindowHours    = 72
        ImminentWindowHours       = 24
        InitialRefreshSeconds     = 18000
        ApproachingRefreshSeconds = 6000
        ImminentRefreshSeconds    = 600
        ElapsedRefreshSeconds     = 300
    }
    
    Notifications = @{
        EnableToasts          = 'true'
        EnableDeferralDialog  = 'true'
        EnableProgressDialog  = 'true'
        ToastDurationSeconds  = 10
        DialogTimeoutSeconds  = 300
        EnableAggressiveMode  = 'true'
        HideOtherWindows      = 'true'
        BlurBackground        = 'false'
        CompanyName           = 'IT Department'
        CompanyLogoPath       = ''
        AccentColor           = '#0078D4'
        ToastTitle            = 'Software Update Available'
        ToastMessage          = 'A software update is ready to install. Click to proceed.'
        DialogTitle           = 'Update Required'
        DialogMessage         = 'Critical updates are ready to install. Save your work.'

        # Enterprise notification settings (RUXIM-style)
        Enterprise = @{
            # Full-screen interstitial prompts
            EnableFullScreenPrompts = 'true'      # Show full-screen prompts for elapsed deadlines
            FullScreenTimeoutSeconds = 300         # Auto-proceed timeout for full-screen prompt
            FullScreenTitle          = 'Action Required'
            FullScreenMessage        = 'Important updates must be installed now. Your device will restart after updates are applied.'
            FullScreenHeroImage      = ''         # Optional hero image path (1364x300 recommended)

            # Toast scenarios based on deferral phase
            InitialToastScenario     = 'Default'   # Standard toast for initial phase
            ApproachingToastScenario = 'Reminder'  # Persistent toast for approaching deadline
            ImminentToastScenario    = 'Urgent'    # Urgent toast (bypasses Focus Assist)
            ElapsedToastScenario     = 'Urgent'    # Urgent toast for elapsed deadline

            # Native toast actions (buttons)
            EnableToastActions       = 'true'      # Enable Update Now/Defer buttons on toasts
            ToastActionUpdateLabel   = 'Update Now'
            ToastActionDeferLabel    = 'Remind Later'
            ToastActionDismissLabel  = 'Dismiss'

            # Protocol handler for toast activation
            ProtocolScheme           = 'pspatchmypc'  # Custom protocol scheme

            # Escalation behavior
            EscalateToFullScreen     = 'true'      # Escalate to full-screen when deadline elapsed
            EscalateAfterDismissals  = 3           # Show full-screen after N toast dismissals
        }
    }
    
    ApplicationManagement = @{
        Mode              = 'Allowlist'
        CatalogPath       = ''
        AutoAddNewApps    = 'false'
        ProcessTimeout    = 300
        ForceCloseOnTimeout = 'true'
    }
    
    Enterprise = @{
        EnableIntuneReporting    = 'false'
        IntuneLogSymlink         = 'true'
        EnableEventLog           = 'true'
        EventLogSource           = 'PsPatchMyPC'
        EnableFleetDMReporting   = 'false'
        PrivateSourceName        = ''
        PrivateSourceUrl         = ''
        PrivateSourceType        = 'Microsoft.Rest'
    }
    
    Scheduling = @{
        EnableScheduledTasks = 'true'
        UpdateEngineTime     = '03:00'
        UserNotificationTime = '09:00'
        TaskPath             = '\PsPatchMyPC\'
    }

    # DriverManagement integration (Driver/Intel/WU) - treated as a pseudo work item for deferral UI
    DriverManagement = @{
        Enabled              = $true
        IncludeWindowsUpdates = $true
        UiTimeoutSeconds     = 60
        DeferralOverride     = @{
            MaxCount     = 3
            DeadlineDays = 7
        }
    }
}
