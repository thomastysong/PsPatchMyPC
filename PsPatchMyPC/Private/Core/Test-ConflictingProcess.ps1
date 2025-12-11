function Test-ConflictingProcess {
    <#
    .SYNOPSIS
        Tests if any conflicting processes are running
    .DESCRIPTION
        Checks if any of the specified process names are currently running
    .PARAMETER ProcessNames
        Array of process names to check (with or without .exe extension)
    .EXAMPLE
        Test-ConflictingProcess -ProcessNames @('chrome.exe', 'firefox')
        Returns $true if Chrome or Firefox is running
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ProcessNames
    )
    
    foreach ($procName in $ProcessNames) {
        # Remove .exe extension if present for Get-Process
        $procNameClean = $procName -replace '\.exe$', ''
        
        $running = Get-Process -Name $procNameClean -ErrorAction SilentlyContinue
        if ($running) {
            Write-Verbose "Found running process: $procNameClean"
            return $true
        }
    }
    
    return $false
}

function Get-ConflictingProcessDetails {
    <#
    .SYNOPSIS
        Gets details about running conflicting processes
    .DESCRIPTION
        Returns information about conflicting processes that are currently running
    .PARAMETER ProcessNames
        Array of process names to check
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ProcessNames
    )
    
    $runningProcesses = @()
    
    foreach ($procName in $ProcessNames) {
        $procNameClean = $procName -replace '\.exe$', ''
        
        $processes = Get-Process -Name $procNameClean -ErrorAction SilentlyContinue
        foreach ($proc in $processes) {
            $runningProcesses += [PSCustomObject]@{
                Name        = $proc.Name
                Id          = $proc.Id
                MainWindow  = $proc.MainWindowTitle
                StartTime   = $proc.StartTime
                CPU         = $proc.CPU
                Memory      = [math]::Round($proc.WorkingSet64 / 1MB, 2)
                Path        = $proc.Path
            }
        }
    }
    
    return $runningProcesses
}

function Stop-ConflictingProcess {
    <#
    .SYNOPSIS
        Stops conflicting processes
    .DESCRIPTION
        Attempts to gracefully close then forcibly stop conflicting processes
    .PARAMETER ProcessNames
        Array of process names to stop
    .PARAMETER Timeout
        Seconds to wait for graceful close before force killing
    .PARAMETER Force
        Skip graceful close attempt and force kill immediately
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string[]]$ProcessNames,
        
        [Parameter()]
        [int]$Timeout = 30,
        
        [Parameter()]
        [switch]$Force
    )
    
    $stopped = @()
    
    foreach ($procName in $ProcessNames) {
        $procNameClean = $procName -replace '\.exe$', ''
        
        $processes = Get-Process -Name $procNameClean -ErrorAction SilentlyContinue
        foreach ($proc in $processes) {
            if ($PSCmdlet.ShouldProcess($proc.Name, "Stop process")) {
                try {
                    if (-not $Force) {
                        # Try graceful close first
                        $proc.CloseMainWindow() | Out-Null
                        
                        # Wait for process to exit
                        $waitResult = $proc.WaitForExit($Timeout * 1000)
                        
                        if (-not $waitResult) {
                            # Force kill if still running
                            Write-PatchLog "Graceful close timed out for $($proc.Name), force killing" -Type Warning
                            $proc | Stop-Process -Force
                        }
                    }
                    else {
                        $proc | Stop-Process -Force
                    }
                    
                    $stopped += $proc.Name
                    Write-PatchLog "Stopped process: $($proc.Name) (PID: $($proc.Id))" -Type Info
                }
                catch {
                    Write-PatchLog "Failed to stop process $($proc.Name): $_" -Type Error
                }
            }
        }
    }
    
    return $stopped
}

