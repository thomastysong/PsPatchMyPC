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
                
                # Apply version pin filtering
                if ($appConfig.VersionPinMode) {
                    switch ($appConfig.VersionPinMode) {
                        'freeze' {
                            # Skip - don't offer updates for frozen apps
                            Write-PatchLog "Skipping update for $($pkg.Id) - version is frozen" -Type Info
                            continue
                        }
                        'max' {
                            # Only offer update if available version <= pinned max
                            if ($appConfig.PinnedVersion -and $available -ne 'Latest') {
                                $comparison = Compare-Version -Version1 $available -Version2 $appConfig.PinnedVersion
                                if ($comparison -gt 0) {
                                    Write-PatchLog "Skipping update for $($pkg.Id) - available version $available exceeds max pin $($appConfig.PinnedVersion)" -Type Info
                                    continue
                                }
                            }
                        }
                        'exact' {
                            # Only offer update if current version != pinned version
                            if ($appConfig.PinnedVersion) {
                                if ($pkg.InstalledVersion -eq $appConfig.PinnedVersion) {
                                    Write-PatchLog "Skipping update for $($pkg.Id) - already at pinned version $($appConfig.PinnedVersion)" -Type Info
                                    continue
                                }
                                # Set the target version to the pinned version
                                $available = $appConfig.PinnedVersion
                                $status.AvailableVersion = $available
                            }
                        }
                    }
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

function Get-MissingApplication {
    <#
    .SYNOPSIS
        Gets applications from the catalog that are not installed
    .DESCRIPTION
        Checks which managed applications are missing from the system and returns
        those that have InstallIfMissing enabled
    .EXAMPLE
        Get-MissingApplication
        Returns all missing applications that should be installed
    #>
    [CmdletBinding()]
    param()
    
    $missing = @()
    
    if (-not (Test-WingetAvailableInternal)) {
        Write-PatchLog "Winget not available - cannot check for missing applications" -Type Warning
        return $missing
    }
    
    try {
        $managedApps = Get-ManagedApplicationsInternal
        if ($managedApps.Count -eq 0) {
            Write-PatchLog "No managed applications configured" -Type Info
            return $missing
        }
        
        # Get all installed packages
        $installedPackages = Get-WinGetPackage -ErrorAction SilentlyContinue
        $installedIds = @()
        if ($installedPackages) {
            $installedIds = $installedPackages | ForEach-Object { $_.Id }
        }
        
        foreach ($app in $managedApps) {
            # Skip disabled apps or those not marked for install
            if (-not $app.Enabled -or -not $app.InstallIfMissing) { continue }
            
            # Check if installed
            $isInstalled = $installedIds -contains $app.Id
            if (-not $isInstalled) {
                $missingApp = [PSCustomObject]@{
                    AppId = $app.Id
                    AppName = $app.Name
                    Priority = $app.Priority
                    AppConfig = $app
                    TargetVersion = if ($app.VersionPinMode -eq 'exact' -and $app.PinnedVersion) { $app.PinnedVersion } else { 'Latest' }
                }
                $missing += $missingApp
                Write-PatchLog "Application $($app.Name) ($($app.Id)) is missing and marked for install" -Type Info
            }
        }
        
        Write-PatchLog "Found $($missing.Count) missing applications to install" -Type Info
    }
    catch {
        Write-PatchLog "Failed to check for missing applications: $_" -Type Error
    }
    
    return $missing
}

