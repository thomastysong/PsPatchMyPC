function Invoke-AsCurrentUser {
    <#
    .SYNOPSIS
        Runs a script block as the currently logged-in user
    .DESCRIPTION
        Enables running UI code from SYSTEM context by executing in user session.
        Uses scheduled task technique for reliability.
    .PARAMETER ScriptBlock
        The script block to execute
    .PARAMETER Arguments
        Arguments to pass to the script block
    .PARAMETER Wait
        Wait for execution to complete
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ScriptBlock]$ScriptBlock,
        
        [Parameter()]
        [object[]]$Arguments,
        
        [Parameter()]
        [switch]$Wait
    )
    
    try {
        # Check if running as SYSTEM
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $isSystem = $currentUser.User.Value -eq 'S-1-5-18'
        
        if (-not $isSystem) {
            # Not SYSTEM - just run directly
            if ($Arguments) {
                return & $ScriptBlock @Arguments
            }
            else {
                return & $ScriptBlock
            }
        }
        
        # Running as SYSTEM - need to run in user context
        Write-PatchLog "Running script as current user from SYSTEM context" -Type Info
        
        # Get the currently logged-in user
        $loggedOnUser = Get-LoggedOnUser
        if (-not $loggedOnUser) {
            Write-PatchLog "No user logged in - cannot run in user context" -Type Warning
            return $null
        }
        
        # Create temp script file
        $tempScript = Join-Path $env:TEMP "PsPatchMyPC_UserScript_$(Get-Random).ps1"
        $ScriptBlock.ToString() | Out-File -FilePath $tempScript -Encoding UTF8 -Force
        
        try {
            # Create scheduled task to run as user
            $taskName = "PsPatchMyPC_UserTask_$(Get-Random)"
            $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
                -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempScript`""
            
            $principal = New-ScheduledTaskPrincipal -UserId $loggedOnUser -LogonType Interactive -RunLevel Limited
            
            $task = Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Force
            
            # Start the task
            Start-ScheduledTask -TaskName $taskName
            
            if ($Wait) {
                # Wait for task to complete
                $timeout = 300  # 5 minutes
                $elapsed = 0
                do {
                    Start-Sleep -Seconds 1
                    $elapsed++
                    $taskInfo = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
                } while ($taskInfo.State -eq 'Running' -and $elapsed -lt $timeout)
            }
            
            # Clean up task
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }
        finally {
            # Clean up temp script
            Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        Write-PatchLog "Failed to run as current user: $_" -Type Error
        return $null
    }
}

function Get-LoggedOnUser {
    <#
    .SYNOPSIS
        Gets the currently logged-on interactive user
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Get explorer.exe owner (reliable method to find logged-in user)
        $explorer = Get-WmiObject -Class Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue |
            Select-Object -First 1
        
        if ($explorer) {
            $owner = $explorer.GetOwner()
            if ($owner.Domain -and $owner.User) {
                return "$($owner.Domain)\$($owner.User)"
            }
            return $owner.User
        }
        
        # Fallback: query user session
        $sessions = query user 2>$null
        if ($sessions) {
            $activeSession = $sessions | Where-Object { $_ -match 'Active' } | Select-Object -First 1
            if ($activeSession -match '^\s*(\S+)') {
                return $Matches[1]
            }
        }
        
        return $null
    }
    catch {
        Write-Verbose "Failed to get logged on user: $_"
        return $null
    }
}

function Test-UserSessionActive {
    <#
    .SYNOPSIS
        Tests if there's an active user session
    #>
    [CmdletBinding()]
    param()
    
    $user = Get-LoggedOnUser
    return ($null -ne $user)
}

