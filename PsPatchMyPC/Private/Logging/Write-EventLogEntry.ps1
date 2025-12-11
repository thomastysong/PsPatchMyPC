function Write-EventLogEntry {
    <#
    .SYNOPSIS
        Writes an entry to the Windows Event Log
    .DESCRIPTION
        Writes a log entry to the PsPatchMyPC event log for enterprise monitoring
    .PARAMETER Message
        The message to log
    .PARAMETER Type
        Event type: Info, Warning, or Error
    .PARAMETER Component
        The component generating the event
    .PARAMETER EventId
        Optional specific event ID (defaults based on type)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Type = 'Info',
        
        [Parameter()]
        [string]$Component = 'PsPatchMyPC',
        
        [Parameter()]
        [int]$EventId
    )
    
    try {
        $config = Get-ModuleConfiguration
        
        # Skip if Event Log is disabled
        if ($env:PSPMPC_EVENT_LOG -eq 'false') {
            return
        }
        
        # Map type to EventLogEntryType
        $entryType = switch ($Type) {
            'Info' { [System.Diagnostics.EventLogEntryType]::Information }
            'Warning' { [System.Diagnostics.EventLogEntryType]::Warning }
            'Error' { [System.Diagnostics.EventLogEntryType]::Error }
            default { [System.Diagnostics.EventLogEntryType]::Information }
        }
        
        # Default event IDs by type
        if (-not $EventId) {
            $EventId = switch ($Type) {
                'Info' { 1000 }
                'Warning' { 2000 }
                'Error' { 3000 }
                default { 1000 }
            }
        }
        
        # Format message with component
        $fullMessage = "[$Component] $Message"
        
        # Check if source exists, create if needed (requires admin)
        if (-not [System.Diagnostics.EventLog]::SourceExists($config.EventLogSource)) {
            try {
                [System.Diagnostics.EventLog]::CreateEventSource(
                    $config.EventLogSource,
                    $config.EventLogName
                )
            }
            catch {
                # May fail without admin - that's OK, just skip
                return
            }
        }
        
        # Write the event
        [System.Diagnostics.EventLog]::WriteEntry(
            $config.EventLogSource,
            $fullMessage,
            $entryType,
            $EventId
        )
    }
    catch {
        # Fail silently to not break calling code
        Write-Verbose "Event Log write failed: $_"
    }
}

