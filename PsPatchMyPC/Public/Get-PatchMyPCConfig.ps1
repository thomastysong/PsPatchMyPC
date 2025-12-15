function Get-PatchMyPCConfig {
    <#
    .SYNOPSIS
        Gets the current PsPatchMyPC module configuration
    .DESCRIPTION
        Returns the merged configuration from defaults, config file, and environment overrides
    .PARAMETER Path
        Optional path to a custom configuration file
    .EXAMPLE
        Get-PatchMyPCConfig
        Returns the current configuration
    .EXAMPLE
        Get-PatchMyPCConfig -Path "C:\Config\custom.psd1"
        Loads configuration from a custom file
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path
    )
    
    try {
        $config = [PsPatchMyPCConfig]::new()
        $moduleConfig = Get-ModuleConfiguration
        
        # Set base paths from module config
        $config.LogPath = $moduleConfig.LogPath
        $config.StatePath = $moduleConfig.StatePath
        $config.ConfigPath = $moduleConfig.ConfigPath
        $config.EventLogName = $moduleConfig.EventLogName
        $config.EventLogSource = $moduleConfig.EventLogSource
        $config.StateRegistryKey = $moduleConfig.StateRegistryKey
        
        # Load config file
        $configFile = $Path
        if (-not $configFile) {
            $configFile = Join-Path $Script:ConfigPath 'config.psd1'
        }
        
        if (Test-Path $configFile) {
            $fileConfig = Import-PowerShellDataFile -Path $configFile
            
            # Merge deferrals
            if ($fileConfig.Deferrals) {
                foreach ($key in $fileConfig.Deferrals.Keys) {
                    $config.Deferrals[$key] = $fileConfig.Deferrals[$key]
                }
            }
            
            # Merge notifications
            if ($fileConfig.Notifications) {
                foreach ($key in $fileConfig.Notifications.Keys) {
                    $config.Notifications[$key] = $fileConfig.Notifications[$key]
                }
            }
            
            # Merge updates
            if ($fileConfig.Updates) {
                foreach ($key in $fileConfig.Updates.Keys) {
                    $config.Updates[$key] = $fileConfig.Updates[$key]
                }
            }

            # Merge DriverManagement integration
            if ($fileConfig.DriverManagement) {
                foreach ($key in $fileConfig.DriverManagement.Keys) {
                    $config.DriverManagement[$key] = $fileConfig.DriverManagement[$key]
                }
            }
            
            # Override paths if specified
            if ($fileConfig.Paths) {
                if ($fileConfig.Paths.LogDirectory) { $config.LogPath = $fileConfig.Paths.LogDirectory }
                if ($fileConfig.Paths.StateDirectory) { $config.StatePath = $fileConfig.Paths.StateDirectory }
            }
        }
        
        # Apply environment variable overrides
        if ($env:PSPMPC_LOG_PATH) {
            $config.LogPath = $env:PSPMPC_LOG_PATH
        }
        if ($env:PSPMPC_CONFIG_PATH) {
            $config.ConfigPath = $env:PSPMPC_CONFIG_PATH
        }
        
        # Load applications from catalog
        $config.Applications = Get-ManagedApplicationsInternal
        
        return $config
    }
    catch {
        Write-PatchLog "Failed to load configuration: $_" -Type Error
        throw
    }
}

function Get-ManagedApplicationsInternal {
    <#
    .SYNOPSIS
        Internal function to load managed applications from catalog
    #>
    [CmdletBinding()]
    param()
    
    $apps = @()
    $moduleConfig = Get-ModuleConfiguration
    $catalogPath = Join-Path $moduleConfig.ConfigPath 'applications.json'
    
    # Fallback to module's config folder if not in ProgramData
    if (-not (Test-Path $catalogPath)) {
        $catalogPath = Join-Path $Script:ConfigPath 'applications.json'
    }
    
    if (Test-Path $catalogPath) {
        try {
            $catalog = Get-Content -Path $catalogPath -Raw | ConvertFrom-Json
            foreach ($appData in $catalog.applications) {
                # Convert deferralOverride PSCustomObject to hashtable if present
                $deferralOverride = $null
                if ($appData.deferralOverride) {
                    $deferralOverride = @{}
                    $appData.deferralOverride.PSObject.Properties | ForEach-Object {
                        $deferralOverride[$_.Name] = $_.Value
                    }
                }
                
                $ht = @{
                    Id = $appData.id
                    Name = $appData.name
                    Enabled = $appData.enabled
                    Priority = $appData.priority
                    ConflictingProcesses = @($appData.conflictingProcesses)
                    PreScript = $appData.preScript
                    PostScript = $appData.postScript
                    InstallArguments = $appData.installArguments
                    RequiresReboot = $appData.requiresReboot
                    DeferralOverride = $deferralOverride
                    # New fields for install missing and version pinning
                    InstallIfMissing = if ($null -ne $appData.installIfMissing) { $appData.installIfMissing } else { $false }
                    DeferInitialInstall = if ($null -ne $appData.deferInitialInstall) { $appData.deferInitialInstall } else { $false }
                    VersionPinMode = if ($appData.versionPin) { $appData.versionPin.mode } else { $null }
                    PinnedVersion = if ($appData.versionPin) { $appData.versionPin.version } else { $null }
                }
                $apps += [ManagedApplication]::FromHashtable($ht)
            }
        }
        catch {
            Write-PatchLog "Failed to load applications catalog: $_" -Type Warning
        }
    }
    
    return $apps
}

function Get-PatchMyPCLogs {
    <#
    .SYNOPSIS
        Gets PsPatchMyPC log entries
    .DESCRIPTION
        Retrieves and parses log entries from the PsPatchMyPC log files
    .PARAMETER Days
        Number of days of logs to retrieve (default: 7)
    .PARAMETER Type
        Filter by log type: Info, Warning, Error, or All (default: All)
    .PARAMETER Tail
        Return only the last N entries
    .EXAMPLE
        Get-PatchMyPCLogs -Days 1 -Type Error
        Gets all error entries from the last day
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Days = 7,
        
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'All')]
        [string]$Type = 'All',
        
        [Parameter()]
        [int]$Tail
    )
    
    $config = Get-ModuleConfiguration
    $logPath = $config.LogPath
    
    if (-not (Test-Path $logPath)) {
        Write-Warning "Log directory not found: $logPath"
        return @()
    }
    
    # Get log files from the specified date range
    $startDate = (Get-Date).AddDays(-$Days)
    $logFiles = Get-ChildItem -Path $logPath -Filter "PsPatchMyPC_*.log" | 
        Where-Object { $_.LastWriteTime -ge $startDate } |
        Sort-Object LastWriteTime -Descending
    
    $entries = @()
    
    foreach ($file in $logFiles) {
        $content = Get-Content -Path $file.FullName -Raw
        
        # Parse CMTrace format entries
        $pattern = '<!\[LOG\[(.*?)\]LOG\]!><time="(.*?)" date="(.*?)" component="(.*?)" context="(.*?)" type="(\d)" thread="(\d+)" file="(.*?)">'
        $matches = [regex]::Matches($content, $pattern)
        
        foreach ($match in $matches) {
            $typeNum = [int]$match.Groups[6].Value
            $typeStr = switch ($typeNum) {
                1 { 'Info' }
                2 { 'Warning' }
                3 { 'Error' }
                default { 'Info' }
            }
            
            if ($Type -ne 'All' -and $typeStr -ne $Type) { continue }
            
            $entries += [PSCustomObject]@{
                Timestamp = [datetime]::ParseExact(
                    "$($match.Groups[3].Value) $($match.Groups[2].Value.Substring(0, 12))",
                    'MM-dd-yyyy HH:mm:ss.fff',
                    $null
                )
                Type      = $typeStr
                Message   = $match.Groups[1].Value
                Component = $match.Groups[4].Value
                Context   = $match.Groups[5].Value
                Thread    = $match.Groups[7].Value
            }
        }
    }
    
    # Sort by timestamp descending
    $entries = $entries | Sort-Object Timestamp -Descending
    
    # Apply tail if specified
    if ($Tail -gt 0) {
        $entries = $entries | Select-Object -First $Tail
    }
    
    return $entries
}

