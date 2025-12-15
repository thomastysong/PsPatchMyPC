function Get-DriverManagementWorkItemInternal {
    <#
    .SYNOPSIS
        Creates a pseudo PatchStatus item representing DriverManagement updates.
    .DESCRIPTION
        PsPatchMyPC treats DriverManagement as a work item (not a WinGet app) so it can reuse
        existing deferral UI + state persistence.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PsPatchMyPCConfig]$Config
    )

    if (-not $Config) { $Config = Get-PatchMyPCConfig }

    $status = [PatchStatus]::new()
    $status.AppId = 'PSDriverManagement.DriverManagement'
    $status.AppName = 'Drivers & Windows Updates'
    $status.InstalledVersion = 'N/A'
    $status.AvailableVersion = 'Latest'
    $status.UpdateAvailable = $true
    $status.Priority = [UpdatePriority]::High
    $status.ConflictingProcesses = @()
    $status.ProcessesRunning = $false
    $status.LastChecked = [datetime]::UtcNow

    return $status
}


