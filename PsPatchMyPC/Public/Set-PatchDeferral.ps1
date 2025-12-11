function Get-DeferralState {
    <#
    .SYNOPSIS
        Gets the deferral state for an application
    .DESCRIPTION
        Retrieves the current deferral state including count, deadline, and phase
    .PARAMETER AppId
        The application ID to get state for
    .EXAMPLE
        Get-DeferralState -AppId 'Google.Chrome'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    
    return Get-StateFromRegistry -AppId $AppId
}

function Set-PatchDeferral {
    <#
    .SYNOPSIS
        Records a deferral for an application update
    .DESCRIPTION
        Updates the deferral state when a user defers an update
    .PARAMETER AppId
        The application ID being deferred
    .PARAMETER DeferUntil
        When to next prompt for the update
    .PARAMETER Reason
        Optional reason for deferral
    .EXAMPLE
        Set-PatchDeferral -AppId 'Google.Chrome' -DeferUntil (Get-Date).AddHours(4)
    .EXAMPLE
        Set-PatchDeferral -AppId 'Mozilla.Firefox' -DeferUntil 'Tomorrow'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId,
        
        [Parameter(Mandatory)]
        [object]$DeferUntil,
        
        [Parameter()]
        [string]$Reason
    )
    
    try {
        # Get current state
        $state = Get-StateFromRegistry -AppId $AppId
        
        if ($state.TargetVersion -eq $null) {
            Write-PatchLog "No update pending for $AppId" -Type Warning
            return $false
        }
        
        # Check if deferral is allowed
        if (-not $state.CanDefer()) {
            Write-PatchLog "Deferral not allowed for $AppId (count: $($state.DeferralCount), phase: $($state.Phase))" -Type Warning
            return $false
        }
        
        # Parse DeferUntil
        $nextPrompt = switch ($DeferUntil) {
            '1 Hour' { [datetime]::UtcNow.AddHours(1) }
            '4 Hours' { [datetime]::UtcNow.AddHours(4) }
            'Tomorrow' { [datetime]::UtcNow.AddDays(1) }
            default {
                if ($DeferUntil -is [datetime]) { $DeferUntil }
                else { [datetime]::Parse($DeferUntil) }
            }
        }
        
        # Update state
        $state.DeferralCount++
        $state.LastDeferral = [datetime]::UtcNow
        
        # Save state
        Set-StateToRegistry -State $state
        
        # Log
        $message = "Deferred $AppId until $nextPrompt"
        if ($Reason) { $message += " (Reason: $Reason)" }
        Write-PatchLog $message -Type Info
        
        return $true
    }
    catch {
        Write-PatchLog "Failed to set deferral for $AppId : $_" -Type Error
        return $false
    }
}

function Reset-DeferralState {
    <#
    .SYNOPSIS
        Resets deferral state for an application
    .DESCRIPTION
        Clears the deferral count and state, typically after successful update
    .PARAMETER AppId
        The application ID to reset
    .EXAMPLE
        Reset-DeferralState -AppId 'Google.Chrome'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    
    Remove-StateFromRegistry -AppId $AppId
    Write-PatchLog "Reset deferral state for $AppId" -Type Info
}

function Test-DeferralAllowed {
    <#
    .SYNOPSIS
        Tests if an application can be deferred
    .DESCRIPTION
        Checks deferral count and phase to determine if deferral is allowed
    .PARAMETER AppId
        The application ID to check
    .EXAMPLE
        if (Test-DeferralAllowed -AppId 'Google.Chrome') { Show-DeferralDialog }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    
    $state = Get-StateFromRegistry -AppId $AppId
    return $state.CanDefer()
}

function Get-DeferralPhase {
    <#
    .SYNOPSIS
        Gets the current deferral phase for an application
    .DESCRIPTION
        Returns the phase (Initial, Approaching, Imminent, Elapsed) based on deadline
    .PARAMETER AppId
        The application ID to check
    .EXAMPLE
        Get-DeferralPhase -AppId 'Google.Chrome'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )
    
    $state = Get-StateFromRegistry -AppId $AppId
    
    if ($state.DeadlineDate -eq [datetime]::MinValue) {
        return [DeferralPhase]::Initial
    }
    
    $config = Get-PatchMyPCConfig
    return Get-DeferralPhaseInternal -Deadline $state.DeadlineDate -Config $config
}

function Get-DeferralRefreshInterval {
    <#
    .SYNOPSIS
        Gets the refresh interval based on deferral phase
    .DESCRIPTION
        Returns how often to re-prompt the user based on current phase
    .PARAMETER Phase
        The current deferral phase
    .EXAMPLE
        $interval = Get-DeferralRefreshInterval -Phase ([DeferralPhase]::Approaching)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [DeferralPhase]$Phase
    )
    
    $config = Get-PatchMyPCConfig
    
    $seconds = switch ($Phase) {
        'Initial' { $config.Deferrals.InitialRefreshSeconds }
        'Approaching' { $config.Deferrals.ApproachingRefreshSeconds }
        'Imminent' { $config.Deferrals.ImminentRefreshSeconds }
        'Elapsed' { $config.Deferrals.ElapsedRefreshSeconds }
        default { 18000 }  # 5 hours default
    }
    
    return [timespan]::FromSeconds($seconds)
}

