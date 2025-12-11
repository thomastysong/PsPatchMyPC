function Install-ApplicationUpdate {
    <#
    .SYNOPSIS
        Installs an application update using winget
    .DESCRIPTION
        Handles the actual installation of an application update with pre/post scripts
    .PARAMETER AppId
        The winget app ID to update
    .PARAMETER AppConfig
        Optional managed application configuration
    .PARAMETER Force
        Force installation even if conflicting processes are running
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId,
        
        [Parameter()]
        [ManagedApplication]$AppConfig,
        
        [Parameter()]
        [switch]$Force
    )
    
    $result = [InstallationResult]::new()
    $result.AppId = $AppId
    $result.Status = [InstallationStatus]::InProgress
    
    $startTime = Get-Date
    
    try {
        Write-PatchLog "Starting update for $AppId" -Type Info
        
        # Get app name
        $pkg = Get-WinGetPackage -Id $AppId -ErrorAction SilentlyContinue
        if ($pkg) {
            $result.AppName = $pkg.Name
        }
        else {
            $result.AppName = $AppId
        }
        
        # Check for conflicting processes
        if ($AppConfig -and $AppConfig.ConflictingProcesses.Count -gt 0) {
            $running = Test-ConflictingProcess -ProcessNames $AppConfig.ConflictingProcesses
            if ($running -and -not $Force) {
                $result.Status = [InstallationStatus]::Deferred
                $result.Message = "Conflicting processes running: $($AppConfig.ConflictingProcesses -join ', ')"
                $result.ExitCode = 1602  # User cancelled / deferred
                Write-PatchLog $result.Message -Type Warning
                return $result
            }
            elseif ($running -and $Force) {
                # Force close conflicting processes
                Write-PatchLog "Force closing conflicting processes for $AppId" -Type Warning
                foreach ($procName in $AppConfig.ConflictingProcesses) {
                    $procNameClean = $procName -replace '\.exe$', ''
                    Get-Process -Name $procNameClean -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                }
                Start-Sleep -Seconds 2
            }
        }
        
        # Run pre-installation script if configured
        if ($AppConfig -and $AppConfig.PreScript) {
            Write-PatchLog "Running pre-install script for $AppId" -Type Info
            try {
                $scriptBlock = [ScriptBlock]::Create($AppConfig.PreScript)
                Invoke-Command -ScriptBlock $scriptBlock -ErrorAction Stop
            }
            catch {
                Write-PatchLog "Pre-install script failed: $_" -Type Warning
            }
        }
        
        # Build update parameters
        $updateParams = @{
            Id = $AppId
            Mode = 'Silent'
        }
        
        if ($AppConfig -and $AppConfig.InstallArguments) {
            $updateParams['Override'] = $AppConfig.InstallArguments
        }
        
        # Perform the update
        Write-PatchLog "Installing update for $AppId" -Type Info
        $updateResult = Update-WinGetPackage @updateParams -ErrorAction Stop
        
        # Check result
        if ($updateResult.Status -eq 'Ok' -or $updateResult.RebootRequired) {
            $result.Status = [InstallationStatus]::Success
            $result.ExitCode = 0
            $result.Message = "Successfully updated $($result.AppName)"
            
            if ($updateResult.RebootRequired) {
                $result.RebootRequired = $true
                $result.Message += " (reboot required)"
            }
            
            Write-PatchLog $result.Message -Type Info
        }
        else {
            $result.Status = [InstallationStatus]::Failed
            $result.ExitCode = 1
            $result.Message = "Update failed for $($result.AppName): $($updateResult.Status)"
            Write-PatchLog $result.Message -Type Error
        }
        
        # Run post-installation script if configured
        if ($AppConfig -and $AppConfig.PostScript -and $result.Status -eq [InstallationStatus]::Success) {
            Write-PatchLog "Running post-install script for $AppId" -Type Info
            try {
                $scriptBlock = [ScriptBlock]::Create($AppConfig.PostScript)
                Invoke-Command -ScriptBlock $scriptBlock -ErrorAction Stop
            }
            catch {
                Write-PatchLog "Post-install script failed: $_" -Type Warning
            }
        }
        
        # Check if app config indicates reboot required
        if ($AppConfig -and $AppConfig.RequiresReboot) {
            $result.RebootRequired = $true
        }
    }
    catch {
        $result.Status = [InstallationStatus]::Failed
        $result.ExitCode = 1
        $result.Message = "Update failed for $AppId : $_"
        Write-PatchLog $result.Message -Type Error
    }
    finally {
        $result.Duration = (Get-Date) - $startTime
    }
    
    return $result
}

function Install-MissingApplication {
    <#
    .SYNOPSIS
        Installs a missing application using winget
    .DESCRIPTION
        Handles the initial installation of an application that is not yet installed
    .PARAMETER AppId
        The winget app ID to install
    .PARAMETER AppConfig
        Optional managed application configuration
    .PARAMETER Force
        Force installation even if conflicting processes are running
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId,
        
        [Parameter()]
        [ManagedApplication]$AppConfig,
        
        [Parameter()]
        [switch]$Force
    )
    
    $result = [InstallationResult]::new()
    $result.AppId = $AppId
    $result.AppName = if ($AppConfig) { $AppConfig.Name } else { $AppId }
    $result.Status = [InstallationStatus]::InProgress
    
    $startTime = Get-Date
    
    try {
        Write-PatchLog "Starting initial installation for $AppId" -Type Info
        
        # Run pre-installation script if configured
        if ($AppConfig -and $AppConfig.PreScript) {
            Write-PatchLog "Running pre-install script for $AppId" -Type Info
            try {
                $scriptBlock = [ScriptBlock]::Create($AppConfig.PreScript)
                Invoke-Command -ScriptBlock $scriptBlock -ErrorAction Stop
            }
            catch {
                Write-PatchLog "Pre-install script failed: $_" -Type Warning
            }
        }
        
        # Build install parameters
        $installParams = @{
            Id = $AppId
            Mode = 'Silent'
        }
        
        # Handle version pinning for exact mode - install specific version
        if ($AppConfig -and $AppConfig.VersionPinMode -eq 'exact' -and $AppConfig.PinnedVersion) {
            $installParams['Version'] = $AppConfig.PinnedVersion
            Write-PatchLog "Installing pinned version $($AppConfig.PinnedVersion) for $AppId" -Type Info
        }
        
        # Handle max version pinning - install up to max version
        if ($AppConfig -and $AppConfig.VersionPinMode -eq 'max' -and $AppConfig.PinnedVersion) {
            # For max pin, we install the latest version <= pinned version
            # WinGet will install latest by default, but we can specify --version to limit
            $installParams['Version'] = $AppConfig.PinnedVersion
            Write-PatchLog "Installing max version $($AppConfig.PinnedVersion) for $AppId" -Type Info
        }
        
        if ($AppConfig -and $AppConfig.InstallArguments) {
            $installParams['Override'] = $AppConfig.InstallArguments
        }
        
        # Perform the installation
        Write-PatchLog "Installing $AppId" -Type Info
        $installResult = Install-WinGetPackage @installParams -ErrorAction Stop
        
        # Check result
        if ($installResult.Status -eq 'Ok' -or $installResult.RebootRequired) {
            $result.Status = [InstallationStatus]::Success
            $result.ExitCode = 0
            $result.Message = "Successfully installed $($result.AppName)"
            
            if ($installResult.RebootRequired) {
                $result.RebootRequired = $true
                $result.Message += " (reboot required)"
            }
            
            Write-PatchLog $result.Message -Type Info
        }
        else {
            $result.Status = [InstallationStatus]::Failed
            $result.ExitCode = 1
            $result.Message = "Installation failed for $($result.AppName): $($installResult.Status)"
            Write-PatchLog $result.Message -Type Error
        }
        
        # Run post-installation script if configured
        if ($AppConfig -and $AppConfig.PostScript -and $result.Status -eq [InstallationStatus]::Success) {
            Write-PatchLog "Running post-install script for $AppId" -Type Info
            try {
                $scriptBlock = [ScriptBlock]::Create($AppConfig.PostScript)
                Invoke-Command -ScriptBlock $scriptBlock -ErrorAction Stop
            }
            catch {
                Write-PatchLog "Post-install script failed: $_" -Type Warning
            }
        }
        
        # Check if app config indicates reboot required
        if ($AppConfig -and $AppConfig.RequiresReboot) {
            $result.RebootRequired = $true
        }
    }
    catch {
        $result.Status = [InstallationStatus]::Failed
        $result.ExitCode = 1
        $result.Message = "Installation failed for $AppId : $_"
        Write-PatchLog $result.Message -Type Error
    }
    finally {
        $result.Duration = (Get-Date) - $startTime
    }
    
    return $result
}

