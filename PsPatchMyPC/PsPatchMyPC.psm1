#Requires -Version 5.1
<#
.SYNOPSIS
    PsPatchMyPC - Enterprise Application Patching Module
.DESCRIPTION
    Integrates winget package management with PatchMyPC-style orchestration
    and Nudge-inspired progressive enforcement for enterprise environments.
.NOTES
    Author: Thomas Tyson
    License: MIT
#>

$ErrorActionPreference = 'Stop'

# Module paths
$Script:ModuleRoot = $PSScriptRoot
$Script:PrivatePath = Join-Path $ModuleRoot 'Private'
$Script:PublicPath = Join-Path $ModuleRoot 'Public'
$Script:ClassesPath = Join-Path $ModuleRoot 'Classes'
$Script:ConfigPath = Join-Path $ModuleRoot 'Config'

# Load classes first
$classFiles = @(
    'Classes\PatchMyPCClasses.ps1'
)

foreach ($file in $classFiles) {
    $filePath = Join-Path $ModuleRoot $file
    if (Test-Path $filePath) {
        try {
            . $filePath
        }
        catch {
            Write-Error "Failed to load class file: $file - $_"
        }
    }
}

# Private functions (internal use only)
$privateFiles = @(
    'Private\Logging\Write-PatchLog.ps1'
    'Private\Logging\Write-EventLogEntry.ps1'
    'Private\Core\Get-InstalledApplication.ps1'
    'Private\Core\Get-AvailableUpdate.ps1'
    'Private\Core\Get-DriverManagementWorkItem.ps1'
    'Private\Core\Install-ApplicationUpdate.ps1'
    'Private\Core\Test-ConflictingProcess.ps1'
    'Private\State\Get-StateFromRegistry.ps1'
    'Private\State\Set-StateToRegistry.ps1'
    'Private\Notification\Show-WPFDialog.ps1'
    'Private\Notification\Invoke-AsCurrentUser.ps1'
)

foreach ($file in $privateFiles) {
    $filePath = Join-Path $ModuleRoot $file
    if (Test-Path $filePath) {
        try {
            . $filePath
        }
        catch {
            Write-Error "Failed to load private function: $file - $_"
        }
    }
}

# Public functions (exported)
$publicFiles = @(
    'Public\Get-PatchMyPCConfig.ps1'
    'Public\Initialize-Winget.ps1'
    'Public\Get-PatchStatus.ps1'
    'Public\Start-PatchCycle.ps1'
    'Public\Show-PatchNotification.ps1'
    'Public\Register-PatchSchedule.ps1'
    'Public\Set-PatchDeferral.ps1'
    'Public\Export-PatchReport.ps1'
)

foreach ($file in $publicFiles) {
    $filePath = Join-Path $ModuleRoot $file
    if (Test-Path $filePath) {
        try {
            . $filePath
        }
        catch {
            Write-Error "Failed to load public function: $file - $_"
        }
    }
}

# Initialize module configuration
$Script:ModuleConfig = $null

function Test-PsPatchMyPCPathWritable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }

        $testFile = Join-Path $Path ("._writetest_{0}.tmp" -f ([guid]::NewGuid().ToString()))
        Set-Content -Path $testFile -Value 'test' -Encoding Ascii -Force
        Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
        return $true
    }
    catch {
        return $false
    }
}

function Get-ModuleConfiguration {
    if ($null -eq $Script:ModuleConfig) {
        # Initialize with defaults (expand ProgramData path at runtime)
        $programData = $env:ProgramData
        if (-not $programData) { $programData = 'C:\ProgramData' }

        $tempBase = $env:TEMP
        if (-not $tempBase) { $tempBase = $env:TMP }
        if (-not $tempBase) { $tempBase = 'C:\Windows\Temp' }
        
        $defaultLogPath = Join-Path $programData 'PsPatchMyPC\Logs'
        $defaultStatePath = Join-Path $programData 'PsPatchMyPC\State'
        $defaultConfigPath = Join-Path $programData 'PsPatchMyPC\Config'

        # If ProgramData is not writable (common when not elevated), fall back to a user-writable temp location.
        if (-not (Test-PsPatchMyPCPathWritable -Path (Split-Path $defaultLogPath -Parent))) {
            $defaultLogPath = Join-Path $tempBase 'PsPatchMyPC\Logs'
        }
        if (-not (Test-PsPatchMyPCPathWritable -Path (Split-Path $defaultStatePath -Parent))) {
            $defaultStatePath = Join-Path $tempBase 'PsPatchMyPC\State'
        }
        if (-not (Test-PsPatchMyPCPathWritable -Path (Split-Path $defaultConfigPath -Parent))) {
            $defaultConfigPath = Join-Path $tempBase 'PsPatchMyPC\Config'
        }

        $Script:ModuleConfig = @{
            LogPath          = $defaultLogPath
            StatePath        = $defaultStatePath
            ConfigPath       = $defaultConfigPath
            EventLogName     = 'Application'
            EventLogSource   = 'WSH'  # Use existing Windows Script Host source (no admin required)
            StateRegistryKey = 'HKLM:\SOFTWARE\PsPatchMyPC\State'
        }
        
        # Apply environment variable overrides
        if ($env:PSPMPC_LOG_PATH) {
            $Script:ModuleConfig.LogPath = $env:PSPMPC_LOG_PATH
        }
        if ($env:PSPMPC_STATE_PATH) {
            $Script:ModuleConfig.StatePath = $env:PSPMPC_STATE_PATH
        }
        if ($env:PSPMPC_CONFIG_PATH) {
            $Script:ModuleConfig.ConfigPath = $env:PSPMPC_CONFIG_PATH
        }
        
        # Ensure directories exist
        foreach ($path in @($Script:ModuleConfig.LogPath, $Script:ModuleConfig.StatePath, $Script:ModuleConfig.ConfigPath)) {
            if (-not (Test-PsPatchMyPCPathWritable -Path $path)) {
                # As a final fallback, move to temp (best effort). This prevents "deferrals never expire" scenarios
                # caused by failing to persist state when running non-elevated.
                $fallback = Join-Path $tempBase (Split-Path $path -Leaf)
                $null = Test-PsPatchMyPCPathWritable -Path $fallback

                if ($path -eq $Script:ModuleConfig.LogPath) { $Script:ModuleConfig.LogPath = $fallback }
                elseif ($path -eq $Script:ModuleConfig.StatePath) { $Script:ModuleConfig.StatePath = $fallback }
                elseif ($path -eq $Script:ModuleConfig.ConfigPath) { $Script:ModuleConfig.ConfigPath = $fallback }
            }
        }
        
        # Event Log uses pre-existing WSH source (no creation needed)
        # Users can override with $env:PSPMPC_EVENT_LOG = 'false' to disable
    }
    return $Script:ModuleConfig
}

# Initialize on module load
$null = Get-ModuleConfiguration

# Set up aliases
Set-Alias -Name 'gpst' -Value 'Get-PatchStatus' -Scope Global -Force
Set-Alias -Name 'spc' -Value 'Start-PatchCycle' -Scope Global -Force

# Module cleanup
$ExecutionContext.SessionState.Module.OnRemove = {
    Remove-Item -Path Alias:gpst -Force -ErrorAction SilentlyContinue
    Remove-Item -Path Alias:spc -Force -ErrorAction SilentlyContinue
}

# Export public functions
Export-ModuleMember -Function @(
    'Get-PatchStatus'
    'Start-PatchCycle'
    'Get-PatchMyPCConfig'
    'Initialize-Winget'
    'Test-WingetAvailable'
    'Get-WingetUpdates'
    'Install-WingetUpdate'
    'Show-PatchNotification'
    'Show-DeferralDialog'
    'Show-ToastNotification'
    'Register-PatchSchedule'
    'Unregister-PatchSchedule'
    'Get-PatchSchedule'
    'Get-DeferralState'
    'Set-PatchDeferral'
    'Reset-DeferralState'
    'Test-DeferralAllowed'
    'Get-DeferralPhase'
    'Export-PatchReport'
    'Get-PatchCompliance'
    'Get-ManagedApplications'
    'Add-ManagedApplication'
    'Remove-ManagedApplication'
    'Get-PatchMyPCLogs'
) -Alias @('gpst', 'spc')

