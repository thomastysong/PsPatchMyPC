function Get-PatchStatus {
    <#
    .SYNOPSIS
        Gets the current patch status for managed applications
    .DESCRIPTION
        Checks all managed applications for available updates and returns their status
        including deferral state, conflicting processes, and priority
    .PARAMETER AppId
        Optional specific application ID to check
    .PARAMETER ManagedOnly
        Only check applications defined in the managed catalog
    .PARAMETER IncludeDeferralState
        Include deferral state information in results
    .EXAMPLE
        Get-PatchStatus
        Gets status for all managed applications
    .EXAMPLE
        Get-PatchStatus -AppId 'Google.Chrome'
        Gets status for a specific application
    .EXAMPLE
        gps -ManagedOnly
        Uses alias to get status for managed applications only
    #>
    [CmdletBinding()]
    [Alias('gpst')]
    param(
        [Parameter()]
        [string]$AppId,
        
        [Parameter()]
        [switch]$ManagedOnly,
        
        [Parameter()]
        [switch]$IncludeDeferralState
    )
    
    Write-PatchLog "Checking patch status..." -Type Info
    
    try {
        # Ensure winget is available
        if (-not (Test-WingetAvailable -AutoInstall)) {
            Write-PatchLog "Winget not available - cannot check patch status" -Type Error
            return @()
        }
        
        # Get available updates
        $updates = Get-AvailableUpdate -AppId $AppId -ManagedOnly:$ManagedOnly
        
        # Get managed app configurations
        $managedApps = Get-ManagedApplicationsInternal
        
        $results = foreach ($update in $updates) {
            # Find managed app config
            $appConfig = $managedApps | Where-Object { $_.Id -eq $update.AppId } | Select-Object -First 1
            
            # Add deferral state if requested
            if ($IncludeDeferralState) {
                $deferralState = Get-StateFromRegistry -AppId $update.AppId
                $update | Add-Member -NotePropertyName 'DeferralState' -NotePropertyValue $deferralState -PassThru
            }
            else {
                $update
            }
        }
        
        Write-PatchLog "Patch status check complete. Found $($results.Count) updates." -Type Info
        return $results
    }
    catch {
        Write-PatchLog "Failed to check patch status: $_" -Type Error
        return @()
    }
}

function Get-PatchCompliance {
    <#
    .SYNOPSIS
        Gets compliance status for the device
    .DESCRIPTION
        Returns a compliance summary suitable for reporting to MDM systems
    .PARAMETER OutputFormat
        Output format: Object, JSON, or Hashtable
    .EXAMPLE
        Get-PatchCompliance
        Returns compliance object
    .EXAMPLE
        Get-PatchCompliance -OutputFormat JSON
        Returns JSON string for API submission
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Object', 'JSON', 'Hashtable')]
        [string]$OutputFormat = 'Object'
    )
    
    try {
        $updates = Get-PatchStatus -ManagedOnly
        $deferralStates = Get-AllDeferralStates
        
        $critical = ($updates | Where-Object { $_.Priority -eq [UpdatePriority]::Critical }).Count
        $high = ($updates | Where-Object { $_.Priority -eq [UpdatePriority]::High }).Count
        $pastDeadline = ($deferralStates | Where-Object { $_.Phase -eq [DeferralPhase]::Elapsed }).Count
        
        $compliance = [PSCustomObject]@{
            Timestamp         = [datetime]::UtcNow.ToString('o')
            ComputerName      = $env:COMPUTERNAME
            Compliant         = ($updates.Count -eq 0)
            TotalPending      = $updates.Count
            CriticalPending   = $critical
            HighPending       = $high
            PastDeadline      = $pastDeadline
            WingetAvailable   = (Test-WingetAvailable)
            LastCheckTime     = [datetime]::UtcNow.ToString('o')
            PendingUpdates    = @($updates | ForEach-Object {
                @{
                    Id               = $_.AppId
                    Name             = $_.AppName
                    InstalledVersion = $_.InstalledVersion
                    AvailableVersion = $_.AvailableVersion
                    Priority         = $_.Priority.ToString()
                }
            })
        }
        
        switch ($OutputFormat) {
            'JSON' { 
                return $compliance | ConvertTo-Json -Depth 10 -Compress 
            }
            'Hashtable' {
                return @{
                    Timestamp       = $compliance.Timestamp
                    ComputerName    = $compliance.ComputerName
                    Compliant       = $compliance.Compliant
                    TotalPending    = $compliance.TotalPending
                    CriticalPending = $compliance.CriticalPending
                    PastDeadline    = $compliance.PastDeadline
                }
            }
            default { 
                return $compliance 
            }
        }
    }
    catch {
        Write-PatchLog "Failed to get compliance status: $_" -Type Error
        throw
    }
}

