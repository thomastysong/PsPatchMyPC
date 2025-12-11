function Write-PatchLog {
    <#
    .SYNOPSIS
        Writes a log entry in CMTrace-compatible format
    .DESCRIPTION
        Logs messages to a file in a format compatible with CMTrace log viewer.
        Also optionally writes to Windows Event Log.
    .PARAMETER Message
        The message to log
    .PARAMETER Type
        Log level: Info, Warning, or Error
    .PARAMETER Component
        The component or function name generating the log
    .PARAMETER LogFile
        Optional specific log file path. Defaults to daily log in module log directory.
    .PARAMETER NoEventLog
        Skip writing to Windows Event Log
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
        [string]$LogFile,
        
        [Parameter()]
        [switch]$NoEventLog
    )
    
    try {
        $config = Get-ModuleConfiguration
        
        # Determine log file path
        if (-not $LogFile) {
            $LogFile = Join-Path $config.LogPath "PsPatchMyPC_$(Get-Date -Format 'yyyyMMdd').log"
        }
        
        # Ensure log directory exists
        $logDir = Split-Path $LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        
        # Map type to CMTrace type number
        $typeNum = switch ($Type) {
            'Info' { 1 }
            'Warning' { 2 }
            'Error' { 3 }
            default { 1 }
        }
        
        # Get caller info
        $caller = Get-PSCallStack | Select-Object -Skip 1 -First 1
        $callerComponent = if ($caller.Command) { $caller.Command } else { $Component }
        
        # Build CMTrace format log entry
        $time = Get-Date -Format 'HH:mm:ss.fff'
        $date = Get-Date -Format 'MM-dd-yyyy'
        $context = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        
        $logEntry = "<![LOG[$Message]LOG]!>" +
            "<time=`"$time`" " +
            "date=`"$date`" " +
            "component=`"$callerComponent`" " +
            "context=`"$context`" " +
            "type=`"$typeNum`" " +
            "thread=`"$PID`" " +
            "file=`"`">"
        
        # Write to file (thread-safe with mutex)
        $mutex = New-Object System.Threading.Mutex($false, 'Global\PsPatchMyPCLogMutex')
        try {
            $null = $mutex.WaitOne(5000)
            $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
        }
        finally {
            $mutex.ReleaseMutex()
            $mutex.Dispose()
        }
        
        # Write to Event Log if enabled
        if (-not $NoEventLog -and $env:PSPMPC_EVENT_LOG -ne 'false') {
            Write-EventLogEntry -Message $Message -Type $Type -Component $callerComponent
        }
        
        # Also write to verbose stream for debugging
        switch ($Type) {
            'Info' { Write-Verbose $Message }
            'Warning' { Write-Warning $Message }
            'Error' { Write-Error $Message -ErrorAction SilentlyContinue }
        }
    }
    catch {
        # Fail silently to not break calling code
        Write-Verbose "Logging failed: $_"
    }
}

