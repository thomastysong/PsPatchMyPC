@{
    # Module identification
    RootModule        = 'PsPatchMyPC.psm1'
    ModuleVersion     = '1.0.3'
    GUID              = 'b8e7c3a1-4f2d-4e9a-8b1c-3d5e7f9a2b4c'
    Author            = 'Thomas Tyson'
    CompanyName       = 'Community'
    Copyright         = '(c) 2024 Thomas Tyson. MIT License.'
    Description       = 'Enterprise application patching module integrating winget with PatchMyPC-style orchestration and Nudge-inspired progressive enforcement. Supports deferrals, notifications, dual logging, and orchestrator-agnostic deployment.'

    # Requirements
    PowerShellVersion = '5.1'
    
    # Type and format files
    # TypesToProcess = @()
    # FormatsToProcess = @()

    # Functions to export
    FunctionsToExport = @(
        # Core functions
        'Get-PatchStatus'
        'Start-PatchCycle'
        'Get-PatchMyPCConfig'
        
        # Winget management
        'Initialize-Winget'
        'Test-WingetAvailable'
        'Get-WingetUpdates'
        'Install-WingetUpdate'
        
        # Notifications
        'Show-PatchNotification'
        'Show-DeferralDialog'
        'Show-ToastNotification'
        
        # Scheduling
        'Register-PatchSchedule'
        'Unregister-PatchSchedule'
        'Get-PatchSchedule'
        
        # Deferrals
        'Get-DeferralState'
        'Set-PatchDeferral'
        'Reset-DeferralState'
        'Test-DeferralAllowed'
        'Get-DeferralPhase'
        
        # Reporting
        'Export-PatchReport'
        'Get-PatchCompliance'
        
        # Application catalog
        'Get-ManagedApplications'
        'Add-ManagedApplication'
        'Remove-ManagedApplication'
        
        # Logging
        'Get-PatchMyPCLogs'
    )

    # Cmdlets to export
    CmdletsToExport   = @()

    # Variables to export
    VariablesToExport = @()

    # Aliases to export
    AliasesToExport   = @(
        'gpst'   # Get-PatchStatus
        'spc'    # Start-PatchCycle
    )

    # Private data
    PrivateData       = @{
        PSData = @{
            Tags         = @(
                'Patching', 'Winget', 'Enterprise', 'Updates', 'Intune', 
                'FleetDM', 'SCCM', 'Notifications', 'Deferrals', 'Compliance'
            )
            LicenseUri   = 'https://github.com/thomastysong/PsPatchMyPC/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/thomastysong/PsPatchMyPC'
            ReleaseNotes = @'
## Version 1.0.3
### Bug Fixes
- Fixed empty AvailableVersion causing Start-PatchCycle to fail
- Normalizes blank winget versions to "Latest" in both detection and state initialization

## Version 1.0.2
### Bug Fixes
- Fixed `Start-PatchCycle` failing when winget returns an empty AvailableVersion (normalizes to `Latest`)
- Hardened winget version selection to pick the first non-empty entry from `AvailableVersions`

## Version 1.0.1
### Bug Fixes
- Fixed WPF dialog requiring STA thread - now uses runspace for MTA compatibility
- Fixed AvailableVersion not populated (uses AvailableVersions array from winget)
- Fixed registry state fallback to file-based state when not running as admin
- Fixed interactive mode now properly shows deferral dialog

## Version 1.0.0
### Initial Release
- Winget integration with auto-installation support
- Progressive deferral system (Nudge-inspired)
- WPF notification dialogs with countdown timers
- BurntToast integration for toast notifications
- Dual logging (CMTrace format + Windows Event Log)
- Registry-based state persistence
- Scheduled task management (SYSTEM + User context)
- Enterprise application catalog
- Intune/FleetDM/SCCM compatible
- Compliance reporting and JSON output

### Environment Variables
- `PSPMPC_LOG_PATH`: Custom log directory
- `PSPMPC_CONFIG_PATH`: Custom config location
- `PSPMPC_EVENT_LOG`: Enable/disable Event Log (true/false)
- `PSPMPC_WINGET_SOURCE`: Private winget source URL
'@
        }

        # Module configuration defaults (paths expanded at runtime)
        ModuleConfig = @{
            LogPath          = 'PsPatchMyPC\Logs'
            StatePath        = 'PsPatchMyPC\State'
            ConfigPath       = 'PsPatchMyPC\Config'
            EventLogName     = 'PsPatchMyPC'
            EventLogSource   = 'PsPatchMyPC'
            StateRegistryKey = 'HKLM:\SOFTWARE\PsPatchMyPC\State'
        }
    }
}

