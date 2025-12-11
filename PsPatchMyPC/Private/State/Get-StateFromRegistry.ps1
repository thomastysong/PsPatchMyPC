function Get-StateFromRegistry {
    <#
    .SYNOPSIS
        Gets deferral state from registry or file fallback
    .DESCRIPTION
        Retrieves persisted deferral state for an application from the registry,
        falling back to file-based state if registry not accessible
    .PARAMETER AppId
        The application ID to get state for
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    
    $config = Get-ModuleConfiguration
    $appKey = Join-Path $config.StateRegistryKey $AppId
    
    $state = [DeferralState]::new()
    $state.AppId = $AppId
    
    # Try registry first
    try {
        if (Test-Path $appKey) {
            $regValues = Get-ItemProperty -Path $appKey -ErrorAction Stop
            
            if ($regValues.DeferralCount) {
                $state.DeferralCount = [int]$regValues.DeferralCount
            }
            
            if ($regValues.FirstNotification) {
                $state.FirstNotification = [datetime]::Parse($regValues.FirstNotification)
            }
            
            if ($regValues.LastDeferral) {
                $state.LastDeferral = [datetime]::Parse($regValues.LastDeferral)
            }
            
            if ($regValues.TargetVersion) {
                $state.TargetVersion = $regValues.TargetVersion
            }
            # Ensure TargetVersion is never empty
            if ([string]::IsNullOrWhiteSpace($state.TargetVersion)) {
                $state.TargetVersion = 'Latest'
            }
            
            if ($regValues.DeadlineDate) {
                $state.DeadlineDate = [datetime]::Parse($regValues.DeadlineDate)
            }
            
            if ($regValues.Phase) {
                $state.Phase = [DeferralPhase]$regValues.Phase
            }
            
            if ($regValues.MaxDeferrals) {
                $state.MaxDeferrals = [int]$regValues.MaxDeferrals
            }
            
            return $state
        }
    }
    catch {
        # Registry not accessible - try file fallback
    }
    
    # Try file-based state as fallback
    $state = Get-StateFromFile -AppId $AppId
    return $state
}

function Get-StateFromFile {
    <#
    .SYNOPSIS
        Gets deferral state from file (fallback)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    
    $state = [DeferralState]::new()
    $state.AppId = $AppId
    
    # Check multiple locations
    $stateLocations = @(
        (Join-Path (Get-ModuleConfiguration).StatePath "$($AppId -replace '[^a-zA-Z0-9]', '_').json")
        (Join-Path "$env:TEMP\PsPatchMyPC\State" "$($AppId -replace '[^a-zA-Z0-9]', '_').json")
    )
    
    foreach ($stateFile in $stateLocations) {
        if (Test-Path $stateFile) {
            try {
                $stateData = Get-Content -Path $stateFile -Raw | ConvertFrom-Json
                
                $state.DeferralCount = $stateData.DeferralCount
                $state.TargetVersion = $stateData.TargetVersion
                $state.MaxDeferrals = $stateData.MaxDeferrals
                
                # Ensure TargetVersion is never empty
                if ([string]::IsNullOrWhiteSpace($state.TargetVersion)) {
                    $state.TargetVersion = 'Latest'
                }
                
                if ($stateData.FirstNotification) {
                    $state.FirstNotification = [datetime]::Parse($stateData.FirstNotification)
                }
                if ($stateData.LastDeferral) {
                    $state.LastDeferral = [datetime]::Parse($stateData.LastDeferral)
                }
                if ($stateData.DeadlineDate) {
                    $state.DeadlineDate = [datetime]::Parse($stateData.DeadlineDate)
                }
                if ($stateData.Phase) {
                    $state.Phase = [DeferralPhase]$stateData.Phase
                }
                
                return $state
            }
            catch {
                # Continue to next location
            }
        }
    }
    
    return $state
}

function Get-AllDeferralStates {
    <#
    .SYNOPSIS
        Gets all persisted deferral states
    .DESCRIPTION
        Retrieves deferral state for all applications with stored state
    #>
    [CmdletBinding()]
    param()
    
    $config = Get-ModuleConfiguration
    $states = @()
    
    if (-not (Test-Path $config.StateRegistryKey)) {
        return $states
    }
    
    try {
        $appKeys = Get-ChildItem -Path $config.StateRegistryKey -ErrorAction SilentlyContinue
        
        foreach ($appKey in $appKeys) {
            $appId = $appKey.PSChildName
            $state = Get-StateFromRegistry -AppId $appId
            $states += $state
        }
    }
    catch {
        Write-PatchLog "Failed to enumerate deferral states: $_" -Type Warning
    }
    
    return $states
}

