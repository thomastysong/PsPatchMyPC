function Get-AvailableUpdate {
    <#
    .SYNOPSIS
        Gets available updates for managed applications
    .DESCRIPTION
        Checks for available updates using winget and compares versions
    .PARAMETER AppId
        Optional app ID to check for specific application
    .PARAMETER ManagedOnly
        Only check applications in the managed catalog
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$AppId,
        
        [Parameter()]
        [switch]$ManagedOnly
    )
    
    $updates = @()
    
    if (-not (Test-WingetAvailableInternal)) {
        Write-PatchLog "Winget not available - cannot check for updates" -Type Warning
        return $updates
    }
    
    try {
        # Get managed applications if filtering
        $managedApps = @()
        if ($ManagedOnly) {
            $managedApps = Get-ManagedApplicationsInternal
            if ($managedApps.Count -eq 0) {
                Write-PatchLog "No managed applications configured" -Type Info
                return $updates
            }
        }
        
        # Get all packages with updates
        $packages = Get-WinGetPackage -ErrorAction SilentlyContinue | 
            Where-Object { $_.IsUpdateAvailable }
        
        foreach ($pkg in $packages) {
            # Filter by AppId if specified
            if ($AppId -and $pkg.Id -ne $AppId) { continue }
            
            # Filter by managed apps if specified
            if ($ManagedOnly) {
                $managed = $managedApps | Where-Object { $_.Id -eq $pkg.Id -and $_.Enabled }
                if (-not $managed) { continue }
            }
            
            # Get managed app config for priority and processes
            $appConfig = $managedApps | Where-Object { $_.Id -eq $pkg.Id } | Select-Object -First 1
            
            $status = [PatchStatus]::new()
            $status.AppId = $pkg.Id
            $status.AppName = $pkg.Name
            $status.InstalledVersion = $pkg.InstalledVersion
            # AvailableVersions is an array; pick the first non-empty entry (some packages return blank strings)
            $available = $null
            if ($pkg.AvailableVersions -and $pkg.AvailableVersions.Count -gt 0) {
                foreach ($v in $pkg.AvailableVersions) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$v)) {
                        $available = [string]$v
                        break
                    }
                }
            }
            if ([string]::IsNullOrWhiteSpace($available)) {
                $available = 'Latest'
            }
            $status.AvailableVersion = $available
            $status.UpdateAvailable = $true
            
            if ($appConfig) {
                $status.Priority = $appConfig.Priority
                $status.ConflictingProcesses = $appConfig.ConflictingProcesses
                
                # Check if conflicting processes are running
                if ($appConfig.ConflictingProcesses.Count -gt 0) {
                    $status.ProcessesRunning = Test-ConflictingProcess -ProcessNames $appConfig.ConflictingProcesses
                }
            }
            
            $updates += $status
        }
        
        Write-PatchLog "Found $($updates.Count) available updates" -Type Info
    }
    catch {
        Write-PatchLog "Failed to check for updates: $_" -Type Error
    }
    
    return $updates
}

function Compare-Version {
    <#
    .SYNOPSIS
        Compares two version strings
    .DESCRIPTION
        Returns -1 if Version1 < Version2, 0 if equal, 1 if Version1 > Version2
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version1,
        
        [Parameter(Mandatory)]
        [string]$Version2
    )
    
    try {
        $v1 = [Version]$Version1
        $v2 = [Version]$Version2
        return $v1.CompareTo($v2)
    }
    catch {
        # Fall back to string comparison if not valid versions
        return [string]::Compare($Version1, $Version2, $true)
    }
}

