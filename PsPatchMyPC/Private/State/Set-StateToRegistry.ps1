function Set-StateToRegistry {
    <#
    .SYNOPSIS
        Saves deferral state to registry
    .DESCRIPTION
        Persists deferral state for an application to the registry
    .PARAMETER State
        The DeferralState object to save
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [DeferralState]$State
    )
    
    $config = Get-ModuleConfiguration
    $appKey = Join-Path $config.StateRegistryKey $State.AppId
    
    try {
        # Ensure parent key exists
        if (-not (Test-Path $config.StateRegistryKey)) {
            New-Item -Path $config.StateRegistryKey -Force | Out-Null
        }
        
        # Ensure app key exists
        if (-not (Test-Path $appKey)) {
            New-Item -Path $appKey -Force | Out-Null
        }
        
        # Save state values
        Set-ItemProperty -Path $appKey -Name 'DeferralCount' -Value $State.DeferralCount
        Set-ItemProperty -Path $appKey -Name 'Phase' -Value $State.Phase.ToString()
        Set-ItemProperty -Path $appKey -Name 'MaxDeferrals' -Value $State.MaxDeferrals
        
        if ($State.FirstNotification -ne [datetime]::MinValue) {
            Set-ItemProperty -Path $appKey -Name 'FirstNotification' -Value $State.FirstNotification.ToString('o')
        }
        
        if ($State.LastDeferral -ne [datetime]::MinValue) {
            Set-ItemProperty -Path $appKey -Name 'LastDeferral' -Value $State.LastDeferral.ToString('o')
        }
        
        if ($State.TargetVersion) {
            Set-ItemProperty -Path $appKey -Name 'TargetVersion' -Value $State.TargetVersion
        }
        
        if ($State.DeadlineDate -ne [datetime]::MinValue) {
            Set-ItemProperty -Path $appKey -Name 'DeadlineDate' -Value $State.DeadlineDate.ToString('o')
        }
        
        Write-PatchLog "Saved deferral state for $($State.AppId)" -Type Info
    }
    catch {
        Write-PatchLog "Failed to save state for $($State.AppId): $_" -Type Error
        throw
    }
}

function Remove-StateFromRegistry {
    <#
    .SYNOPSIS
        Removes deferral state from registry
    .DESCRIPTION
        Clears persisted deferral state for an application
    .PARAMETER AppId
        The application ID to clear state for
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    
    $config = Get-ModuleConfiguration
    $appKey = Join-Path $config.StateRegistryKey $AppId
    
    try {
        if (Test-Path $appKey) {
            Remove-Item -Path $appKey -Recurse -Force
            Write-PatchLog "Cleared deferral state for $AppId" -Type Info
        }
    }
    catch {
        Write-PatchLog "Failed to clear state for $AppId : $_" -Type Warning
    }
}

function Initialize-DeferralState {
    <#
    .SYNOPSIS
        Initializes deferral state for a new update
    .DESCRIPTION
        Creates initial deferral state when an update is first detected
    .PARAMETER AppId
        The application ID
    .PARAMETER TargetVersion
        The version being updated to
    .PARAMETER Config
        Optional configuration for deferral settings
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId,
        
        [Parameter(Mandatory)]
        [string]$TargetVersion,
        
        [Parameter()]
        [PsPatchMyPCConfig]$Config
    )
    
    # Check for existing state
    $existingState = Get-StateFromRegistry -AppId $AppId
    
    # If state exists and version matches, return existing
    if ($existingState.TargetVersion -eq $TargetVersion) {
        return $existingState
    }
    
    # New version detected - create new state (reset deferrals per Nudge pattern)
    $state = [DeferralState]::new()
    $state.AppId = $AppId
    $state.TargetVersion = $TargetVersion
    $state.FirstNotification = [datetime]::UtcNow
    
    # Get deferral config
    if (-not $Config) {
        $Config = Get-PatchMyPCConfig
    }
    
    $state.MaxDeferrals = $Config.Deferrals.MaxCount
    $state.DeadlineDate = [datetime]::UtcNow.AddDays($Config.Deferrals.DeadlineDays)
    $state.Phase = [DeferralPhase]::Initial
    
    # Save initial state
    Set-StateToRegistry -State $state
    
    Write-PatchLog "Initialized deferral state for $AppId (target: $TargetVersion, deadline: $($state.DeadlineDate))" -Type Info
    
    return $state
}

