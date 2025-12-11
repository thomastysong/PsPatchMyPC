function Get-StateFromRegistry {
    <#
    .SYNOPSIS
        Gets deferral state from registry
    .DESCRIPTION
        Retrieves persisted deferral state for an application from the registry
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
    
    if (-not (Test-Path $appKey)) {
        return $state
    }
    
    try {
        $regValues = Get-ItemProperty -Path $appKey -ErrorAction SilentlyContinue
        
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
        
        if ($regValues.DeadlineDate) {
            $state.DeadlineDate = [datetime]::Parse($regValues.DeadlineDate)
        }
        
        if ($regValues.Phase) {
            $state.Phase = [DeferralPhase]$regValues.Phase
        }
        
        if ($regValues.MaxDeferrals) {
            $state.MaxDeferrals = [int]$regValues.MaxDeferrals
        }
    }
    catch {
        Write-PatchLog "Failed to read state for $AppId : $_" -Type Warning
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

