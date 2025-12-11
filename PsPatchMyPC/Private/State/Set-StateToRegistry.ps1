function Set-StateToRegistry {
    <#
    .SYNOPSIS
        Saves deferral state to registry or file fallback
    .DESCRIPTION
        Persists deferral state for an application to the registry,
        falling back to file if registry not accessible
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
            New-Item -Path $config.StateRegistryKey -Force -ErrorAction Stop | Out-Null
        }
        
        # Ensure app key exists
        if (-not (Test-Path $appKey)) {
            New-Item -Path $appKey -Force -ErrorAction Stop | Out-Null
        }
        
        # Save state values
        Set-ItemProperty -Path $appKey -Name 'DeferralCount' -Value $State.DeferralCount -ErrorAction Stop
        Set-ItemProperty -Path $appKey -Name 'Phase' -Value $State.Phase.ToString() -ErrorAction Stop
        Set-ItemProperty -Path $appKey -Name 'MaxDeferrals' -Value $State.MaxDeferrals -ErrorAction Stop
        
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
        
        Write-PatchLog "Saved deferral state for $($State.AppId) to registry" -Type Info
    }
    catch {
        # Registry not accessible - use file fallback
        Write-PatchLog "Registry not accessible, using file fallback for $($State.AppId)" -Type Warning -NoEventLog
        Set-StateToFile -State $State
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
        
        [Parameter()]
        [string]$TargetVersion,
        
        [Parameter()]
        [PsPatchMyPCConfig]$Config
    )

    # Normalize TargetVersion (some winget packages report empty available versions)
    if ([string]::IsNullOrWhiteSpace($TargetVersion)) {
        $TargetVersion = 'Latest'
    }
    
    # Check for existing state
    $existingState = Get-StateFromRegistry -AppId $AppId
    
    # If state exists and version matches, return existing
    if ($existingState.TargetVersion -eq $TargetVersion) {
        return $existingState
    }
    
    # New version detected - create new state (reset deferrals per Nudge pattern)
    $state = [DeferralState]::new()
    $state.AppId = $AppId
    # Ensure TargetVersion is never empty
    if ([string]::IsNullOrWhiteSpace($TargetVersion)) {
        $TargetVersion = 'Latest'
    }
    $state.TargetVersion = $TargetVersion
    $state.FirstNotification = [datetime]::UtcNow
    
    # Get deferral config
    if (-not $Config) {
        $Config = Get-PatchMyPCConfig
    }
    
    $state.MaxDeferrals = $Config.Deferrals.MaxCount
    $state.DeadlineDate = [datetime]::UtcNow.AddDays($Config.Deferrals.DeadlineDays)
    $state.Phase = [DeferralPhase]::Initial
    
    # Save initial state (Set-StateToRegistry handles fallback internally)
    Set-StateToRegistry -State $state
    
    Write-PatchLog "Initialized deferral state for $AppId (target: $TargetVersion, deadline: $($state.DeadlineDate))" -Type Info
    
    return $state
}

function Set-StateToFile {
    <#
    .SYNOPSIS
        Saves deferral state to file (fallback when registry not accessible)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [DeferralState]$State
    )
    
    try {
        $config = Get-ModuleConfiguration
        $stateDir = $config.StatePath
        if (-not (Test-Path $stateDir)) {
            # Try user temp if ProgramData not writable
            $stateDir = Join-Path $env:TEMP 'PsPatchMyPC\State'
            New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
        }
        
        $stateFile = Join-Path $stateDir "$($State.AppId -replace '[^a-zA-Z0-9]', '_').json"
        
        $stateData = @{
            AppId = $State.AppId
            DeferralCount = $State.DeferralCount
            FirstNotification = $State.FirstNotification.ToString('o')
            LastDeferral = $State.LastDeferral.ToString('o')
            TargetVersion = $State.TargetVersion
            DeadlineDate = $State.DeadlineDate.ToString('o')
            Phase = $State.Phase.ToString()
            MaxDeferrals = $State.MaxDeferrals
        }
        
        $stateData | ConvertTo-Json | Out-File -FilePath $stateFile -Encoding UTF8 -Force
    }
    catch {
        Write-Verbose "Failed to save state to file: $_"
    }
}

