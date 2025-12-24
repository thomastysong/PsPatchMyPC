@{
    # Module identification
    RootModule        = 'PsPatchMyPC.psm1'
    ModuleVersion     = '1.1.8'
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
## Version 1.1.8
### Bug Fixes
- **DriverManagement result accuracy**: When DriverManagement runs successfully but applies 0 updates, PsPatchMyPC no longer reports `1 installed` / `TotalUpdates = 1`. It now reports no updates available (and shows the same "no updates" toast in interactive mode).
- **Clearer summaries**: Patch cycle summary now includes `TotalUpdates` (so the message always matches the returned counters).
- **Less confusing verbose output**: Suppresses nested verbose lines from DriverManagement/PSWindowsUpdate that can say “0 updates found” even when driver updates were applied; PsPatchMyPC logs DriverManagement `UpdatesApplied` when available.

## Version 1.1.7
### Changes
- **DriverManagement enabled by default**: `DriverManagement.Enabled` is now `$true` in the default config
- When running `Start-PatchCycle -Interactive`, DriverManagement (OEM/Intel/Windows Updates) will appear as a work item in the deferral UI

## Version 1.1.6
### New Features
- **DriverManagement integration (UI reuse)**: Optional DriverManagement pseudo work item so `Start-PatchCycle -Interactive` can enforce deferrals using the same dialog and registry state.
- **Reboot prompt**: If DriverManagement reports `RebootRequired`, PsPatchMyPC shows a **Restart now / Later** prompt in interactive mode (including in the active user session when running as SYSTEM).
- **Config**: Added `DriverManagement` settings to `Config/config.psd1` and `PsPatchMyPCConfig`.

## Version 1.1.5
### Improvements
- Default applications.json catalog now includes `installIfMissing: true` for all enabled applications
- Enables `-InstallMissing` parameter to work out of the box without manual catalog edits
- Affected apps: Teams, Zoom, Slack, Chrome, Firefox, Edge, VLC, 7-Zip, Adobe Reader, Notepad++, VS Code, PowerShell 7, Git, KeePassXC

## Version 1.1.4
### Improvements
- Interactive mode now shows a toast notification when no updates are available
- Users are informed that the system is up to date when running `Start-PatchCycle -Interactive`
- Improves user experience by providing feedback even when there's nothing to update

## Version 1.1.3
### Bug Fixes
- Fixed array filtering bug in Remove-ManagedApplication that could leave null element in catalog

## Version 1.1.2
### Bug Fixes
- Fixed misleading message when `-InstallMissing` not passed
- Now shows "No updates available (use -InstallMissing to install missing catalog apps)"

## Version 1.1.1
### Improvements
- Event Viewer logging now uses pre-existing "WSH" (Windows Script Host) source
- No admin privileges required to write events to Event Viewer
- Events prefixed with [PsPatchMyPC] for easy filtering
- Query events: `Get-EventLog -LogName Application -Source WSH | Where-Object { $_.Message -match 'PsPatchMyPC' }`

## Version 1.1.0
### New Features
- **Install Missing Applications**: Use `-InstallMissing` parameter to install catalog apps that are not yet installed
- **Version Pinning**: Three modes to control updates:
  - `max`: Allow updates up to a specified version (e.g., don't update Chrome past v130)
  - `exact`: Install and maintain a specific version only (e.g., always keep Python 3.11.9)
  - `freeze`: Never update (keep current version)
- **Per-App Initial Install Deferral**: Configure `deferInitialInstall` to allow users to defer first-time installations
- New catalog fields: `installIfMissing`, `deferInitialInstall`, `versionPin`

### Usage Examples
```powershell
# Install missing apps and update existing ones
Start-PatchCycle -InstallMissing -NoReboot

# Force install all missing apps without deferrals
Start-PatchCycle -InstallMissing -Force
```

## Version 1.0.5
### Bug Fixes
- Fixed non-admin scenarios where deferral state and compliance output could not be persisted (ProgramData not writable)
- Added automatic fallback of Log/State/Config paths to a user-writable TEMP location
- Hardened UTC parsing for deferral timestamps (prevents deadline calculations from drifting)

## Version 1.0.4
### Bug Fixes
- Added defensive validation to prevent empty TargetVersion in DeferralState objects
- Default TargetVersion to 'Latest' in DeferralState constructor
- Validate TargetVersion in state loading and initialization functions

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
            EventLogName     = 'Application'
            EventLogSource   = 'WSH'
            StateRegistryKey = 'HKLM:\SOFTWARE\PsPatchMyPC\State'
        }
    }
}

