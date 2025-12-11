function Start-PatchCycle {
    <#
    .SYNOPSIS
        Starts a patch cycle to install available updates
    .DESCRIPTION
        Orchestrates the installation of pending updates with deferral handling,
        notifications, and logging. This is the main entry point for update installation.
    .PARAMETER Interactive
        Run in interactive mode with user notifications
    .PARAMETER Force
        Force installation without deferral options
    .PARAMETER NoReboot
        Suppress automatic reboots
    .PARAMETER Priority
        Only install updates of specified priority or higher
    .PARAMETER AppId
        Only update specific application(s)
    .EXAMPLE
        Start-PatchCycle
        Runs a full patch cycle for all managed applications
    .EXAMPLE
        Start-PatchCycle -Interactive
        Runs with user notifications and deferral dialogs
    .EXAMPLE
        spc -Force -NoReboot
        Uses alias to force updates without rebooting
    #>
    [CmdletBinding()]
    [Alias('spc')]
    param(
        [Parameter()]
        [switch]$Interactive,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$NoReboot,
        
        [Parameter()]
        [ValidateSet('Critical', 'High', 'Normal', 'Low')]
        [string]$Priority,
        
        [Parameter()]
        [string[]]$AppId
    )
    
    $result = [PatchCycleResult]::new()
    Write-PatchLog "Starting patch cycle (CorrelationId: $($result.CorrelationId))" -Type Info
    
    try {
        # Ensure winget is available
        if (-not (Test-WingetAvailable -AutoInstall)) {
            $result.Success = $false
            $result.Message = "Winget not available"
            Write-PatchLog $result.Message -Type Error
            $result.Complete()
            return $result
        }
        
        # Get available updates
        $updates = Get-PatchStatus -ManagedOnly
        
        # Filter by priority if specified
        if ($Priority) {
            $priorityLevel = [UpdatePriority]$Priority
            $updates = $updates | Where-Object { $_.Priority -ge $priorityLevel }
        }
        
        # Filter by AppId if specified
        if ($AppId) {
            $updates = $updates | Where-Object { $AppId -contains $_.AppId }
        }
        
        $result.TotalUpdates = $updates.Count
        
        if ($updates.Count -eq 0) {
            $result.Success = $true
            $result.Message = "No updates available"
            Write-PatchLog $result.Message -Type Info
            $result.Complete()
            return $result
        }
        
        Write-PatchLog "Found $($updates.Count) updates to process" -Type Info
        
        # Get configuration and managed apps
        $config = Get-PatchMyPCConfig
        $managedApps = Get-ManagedApplicationsInternal
        
        # Process each update
        foreach ($update in $updates) {
            Write-PatchLog "Processing update for $($update.AppName) ($($update.AppId))" -Type Info
            
            # Get or initialize deferral state
            $targetVersion = [string]$update.AvailableVersion
            if ([string]::IsNullOrWhiteSpace($targetVersion)) {
                $targetVersion = 'Latest'
            }
            $deferralState = Initialize-DeferralState -AppId $update.AppId -TargetVersion $targetVersion -Config $config
            
            # Update deferral phase based on time
            $deferralState.Phase = Get-DeferralPhaseInternal -Deadline $deferralState.DeadlineDate -Config $config
            Set-StateToRegistry -State $deferralState
            
            # Check if deferral is allowed (unless Force)
            if (-not $Force -and $deferralState.CanDefer()) {
                # In interactive mode, show notification/dialog
                if ($Interactive) {
                    $userChoice = Show-DeferralDialogFull -Updates @($update) -Config $config -Timeout 60
                    
                    if ($userChoice -eq 'Defer') {
                        # Record deferral
                        $deferralState.DeferralCount++
                        $deferralState.LastDeferral = [datetime]::UtcNow
                        Set-StateToRegistry -State $deferralState
                        
                        $installResult = [InstallationResult]::new()
                        $installResult.AppId = $update.AppId
                        $installResult.AppName = $update.AppName
                        $installResult.Status = [InstallationStatus]::Deferred
                        $installResult.Message = "Deferred by user ($($deferralState.GetRemainingDeferrals()) remaining)"
                        $installResult.ExitCode = 1602
                        
                        $result.Results += $installResult
                        $result.Deferred++
                        
                        Write-PatchLog "Update deferred for $($update.AppName)" -Type Info
                        continue
                    }
                }
                elseif (-not $Force) {
                    # Non-interactive mode with deferrals still available - check processes
                    if ($update.ProcessesRunning) {
                        $installResult = [InstallationResult]::new()
                        $installResult.AppId = $update.AppId
                        $installResult.AppName = $update.AppName
                        $installResult.Status = [InstallationStatus]::Deferred
                        $installResult.Message = "Conflicting processes running"
                        $installResult.ExitCode = 1602
                        
                        $result.Results += $installResult
                        $result.Deferred++
                        
                        Write-PatchLog "Skipping $($update.AppName) - conflicting processes running" -Type Info
                        continue
                    }
                }
            }
            
            # Get app configuration
            $appConfig = $managedApps | Where-Object { $_.Id -eq $update.AppId } | Select-Object -First 1
            
            # Install the update
            $installResult = Install-ApplicationUpdate -AppId $update.AppId -AppConfig $appConfig -Force:$Force
            $result.Results += $installResult
            
            if ($installResult.Status -eq [InstallationStatus]::Success) {
                $result.Installed++
                
                # Clear deferral state on success
                Remove-StateFromRegistry -AppId $update.AppId
                
                if ($installResult.RebootRequired) {
                    $result.RebootRequired = $true
                }
            }
            elseif ($installResult.Status -eq [InstallationStatus]::Deferred) {
                $result.Deferred++
            }
            else {
                $result.Failed++
            }
        }
        
        # Determine overall success
        $result.Success = ($result.Failed -eq 0)
        $result.Message = "Patch cycle complete: $($result.Installed) installed, $($result.Failed) failed, $($result.Deferred) deferred"
        
        Write-PatchLog $result.Message -Type $(if ($result.Success) { 'Info' } else { 'Warning' })
        
        # Handle reboot if required and not suppressed
        if ($result.RebootRequired -and -not $NoReboot) {
            Write-PatchLog "Reboot required - scheduling restart" -Type Warning
            # Note: In production, this would schedule a reboot with user notification
        }
    }
    catch {
        $result.Success = $false
        $result.Message = "Patch cycle failed: $_"
        Write-PatchLog $result.Message -Type Error
    }
    finally {
        $result.Complete()
        
        # Write compliance status for MDM systems
        Export-ComplianceStatus -Result $result
    }
    
    return $result
}

function Get-DeferralPhaseInternal {
    <#
    .SYNOPSIS
        Determines the current deferral phase based on deadline
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [datetime]$Deadline,
        
        [Parameter(Mandatory)]
        [PsPatchMyPCConfig]$Config
    )
    
    $hoursRemaining = ($Deadline - [datetime]::UtcNow).TotalHours
    
    if ($hoursRemaining -le 0) { return [DeferralPhase]::Elapsed }
    if ($hoursRemaining -le $Config.Deferrals.ImminentWindowHours) { return [DeferralPhase]::Imminent }
    if ($hoursRemaining -le $Config.Deferrals.ApproachingWindowHours) { return [DeferralPhase]::Approaching }
    return [DeferralPhase]::Initial
}

function Show-DeferralDialogInternal {
    <#
    .SYNOPSIS
        Internal function to show deferral dialog (placeholder for full WPF implementation)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PatchStatus]$Update,
        
        [Parameter(Mandatory)]
        [DeferralState]$DeferralState,
        
        [Parameter(Mandatory)]
        [PsPatchMyPCConfig]$Config
    )
    
    # This is a simplified implementation - full WPF dialog is in Show-PatchNotification.ps1
    # In aggressive mode (Elapsed phase), return 'Install'
    if ($DeferralState.Phase -eq [DeferralPhase]::Elapsed) {
        return 'Install'
    }
    
    # Default to defer in non-WPF scenarios (actual WPF shows dialog)
    return 'Defer'
}

function Export-ComplianceStatus {
    <#
    .SYNOPSIS
        Exports compliance status for MDM integration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PatchCycleResult]$Result
    )
    
    try {
        $config = Get-ModuleConfiguration
        
        # Write to state file for FleetDM/Intune
        $statusPath = Join-Path $config.StatePath 'compliance.json'
        
        $status = @{
            Timestamp    = $Result.EndTime.ToString('o')
            CorrelationId = $Result.CorrelationId
            Success      = $Result.Success
            Installed    = $Result.Installed
            Failed       = $Result.Failed
            Deferred     = $Result.Deferred
            Reboot       = $Result.RebootRequired
            Duration     = $Result.Duration.TotalSeconds
        }
        
        $status | ConvertTo-Json | Out-File -FilePath $statusPath -Encoding UTF8 -Force
        
        # Also write FleetDM-specific status if configured
        $fleetPath = "C:\ProgramData\FleetDM\patch_status.json"
        if (Test-Path (Split-Path $fleetPath -Parent)) {
            $status | ConvertTo-Json | Out-File -FilePath $fleetPath -Encoding UTF8 -Force
        }
    }
    catch {
        Write-PatchLog "Failed to export compliance status: $_" -Type Warning
    }
}

