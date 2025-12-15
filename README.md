# PsPatchMyPC

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PsPatchMyPC)](https://www.powershellgallery.com/packages/PsPatchMyPC)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Enterprise application patching module integrating **winget** with **PatchMyPC-style orchestration** and **Nudge-inspired progressive enforcement**.

## Features

- **Winget Integration** - Automatic installation and bootstrapping of Microsoft.WinGet.Client
- **Progressive Deferrals** - Nudge-inspired deferral system with countdown timers
- **WPF Notifications** - Modern dark-themed dialogs with BurntToast fallback
- **Dual Logging** - CMTrace-compatible files + Windows Event Log
- **Registry State** - Persistent deferral tracking across reboots
- **Scheduled Tasks** - SYSTEM context updates + User context notifications
- **Enterprise Catalog** - Configurable application management with per-app settings
- **Orchestrator Agnostic** - Works with Intune, FleetDM, SCCM, Ansible, Chef

## Installation

### From PowerShell Gallery (Recommended)

```powershell
Install-Module -Name PsPatchMyPC -Scope AllUsers
```

### Manual Installation

```powershell
# Clone the repository
git clone https://github.com/thomastysong/PsPatchMyPC.git

# Copy to PowerShell modules directory
Copy-Item -Path ".\PsPatchMyPC\PsPatchMyPC" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PsPatchMyPC" -Recurse
```

## Quick Start

```powershell
# Import the module
Import-Module PsPatchMyPC

# Initialize winget (auto-installs if needed)
Initialize-Winget

# Check for available updates
Get-PatchStatus

# Run a patch cycle interactively
Start-PatchCycle -Interactive

# Or run silently
Start-PatchCycle -NoReboot
```

## DriverManagement integration (deferral UI + reboot prompt)

PsPatchMyPC can optionally treat **DriverManagement** (drivers + Intel + Windows Updates) as a **pseudo work item** so it reuses the same deferral dialog and state persistence as applications.

### Enable

Edit `PsPatchMyPC/PsPatchMyPC/Config/config.psd1` and set:

- `DriverManagement.Enabled = $true`

Optional settings:

- `DriverManagement.IncludeWindowsUpdates` (default `$true`)
- `DriverManagement.UiTimeoutSeconds` (default `60`)
- `DriverManagement.DeferralOverride.MaxCount` / `DriverManagement.DeferralOverride.DeadlineDays`

### Behavior

- In `Start-PatchCycle -Interactive`, users can **Defer** or **Install now** for “Drivers & Windows Updates”.
- PsPatchMyPC calls DriverManagement with `-NoReboot` (reboot is not forced).
- If DriverManagement reports a reboot is required, PsPatchMyPC shows a **Restart now / Later** prompt.

## Deferral System

PsPatchMyPC implements a progressive deferral model inspired by macadmins Nudge:

| Phase | Hours to Deadline | Refresh Interval | Available Options |
|-------|------------------|------------------|-------------------|
| **Initial** | > 72 hours | 5 hours | 1hr, 4hr, Tomorrow, Custom |
| **Approaching** | 24-72 hours | 100 minutes | 1hr, 4hr, Tomorrow |
| **Imminent** | 1-24 hours | 10 minutes | 1hr, 4hr only |
| **Elapsed** | Past due | 5 minutes | 1hr only (aggressive) |

When a new version is detected, deferral counts reset automatically.

## Configuration

### Environment Variables

| Variable | Description |
|----------|-------------|
| `PSPMPC_LOG_PATH` | Custom log directory |
| `PSPMPC_CONFIG_PATH` | Custom configuration location |
| `PSPMPC_EVENT_LOG` | Enable/disable Event Log (`true`/`false`) |
| `PSPMPC_WINGET_SOURCE` | Private winget repository URL |

### Application Catalog

Edit `applications.json` to manage which applications are tracked:

```json
{
  "applications": [
    {
      "id": "Google.Chrome",
      "name": "Google Chrome",
      "enabled": true,
      "priority": "High",
      "conflictingProcesses": ["chrome.exe"],
      "deferralOverride": {
        "maxCount": 3,
        "deadlineDays": 3
      }
    }
  ]
}
```

## Orchestrator Integration

### Intune

```powershell
# Detection Script
Import-Module PsPatchMyPC
$compliance = Get-PatchCompliance
exit $(if ($compliance.Compliant) { 0 } else { 1 })
```

### FleetDM

```sql
-- osquery to check patch status
SELECT * FROM file 
WHERE path = 'C:\ProgramData\FleetDM\patch_status.json';
```

### Scheduled Tasks

```powershell
# Register automated tasks
Register-PatchSchedule -UpdateTime "03:00"

# View task status
Get-PatchSchedule
```

## Commands

### Core Functions

| Command | Description |
|---------|-------------|
| `Get-PatchStatus` | Check for available updates |
| `Start-PatchCycle` | Install pending updates |
| `Get-PatchMyPCConfig` | View current configuration |

### Winget Management

| Command | Description |
|---------|-------------|
| `Initialize-Winget` | Install/repair winget |
| `Test-WingetAvailable` | Check winget status |
| `Get-WingetUpdates` | List available updates |
| `Install-WingetUpdate` | Install specific update |

### Notifications

| Command | Description |
|---------|-------------|
| `Show-PatchNotification` | Display notification |
| `Show-DeferralDialog` | Show deferral dialog |
| `Show-ToastNotification` | Show toast notification |

### Scheduling

| Command | Description |
|---------|-------------|
| `Register-PatchSchedule` | Create scheduled tasks |
| `Unregister-PatchSchedule` | Remove scheduled tasks |
| `Get-PatchSchedule` | View task status |

### Deferrals

| Command | Description |
|---------|-------------|
| `Get-DeferralState` | Get deferral info for app |
| `Set-PatchDeferral` | Record a deferral |
| `Test-DeferralAllowed` | Check if deferral allowed |
| `Get-DeferralPhase` | Get current phase |

### Reporting

| Command | Description |
|---------|-------------|
| `Export-PatchReport` | Generate status report |
| `Get-PatchCompliance` | Get compliance status |
| `Get-PatchMyPCLogs` | View log entries |

### Application Management

| Command | Description |
|---------|-------------|
| `Get-ManagedApplications` | List managed apps |
| `Add-ManagedApplication` | Add app to catalog |
| `Remove-ManagedApplication` | Remove from catalog |

## Logging

### Log Files (CMTrace Format)

```
C:\ProgramData\PsPatchMyPC\Logs\PsPatchMyPC_YYYYMMDD.log
```

### Windows Event Log

- **Log Name**: PsPatchMyPC
- **Event IDs**: 1000 (Info), 2000 (Warning), 3000 (Error)

View in Event Viewer:
```
Applications and Services Logs > PsPatchMyPC
```

## Requirements

- Windows 10 1809+ or Windows 11
- PowerShell 5.1 or later
- Administrator privileges (for SYSTEM tasks)

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please submit issues and pull requests on GitHub.

## Acknowledgments

- Inspired by [PatchMyPC](https://patchmypc.com/) detection and notification patterns
- Deferral model based on [macadmins Nudge](https://github.com/macadmins/nudge)
- Winget integration via [Microsoft.WinGet.Client](https://github.com/microsoft/winget-cli)

