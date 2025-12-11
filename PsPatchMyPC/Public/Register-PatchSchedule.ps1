function Register-PatchSchedule {
    <#
    .SYNOPSIS
        Registers scheduled tasks for automated patching
    .DESCRIPTION
        Creates scheduled tasks for the update engine (SYSTEM context) and
        user notifications (user context at logon)
    .PARAMETER UpdateTime
        Time for daily update checks (default: 03:00)
    .PARAMETER NotificationTime
        Time for user notification checks (default: 09:00)
    .PARAMETER Force
        Overwrite existing tasks
    .EXAMPLE
        Register-PatchSchedule
        Creates default scheduled tasks
    .EXAMPLE
        Register-PatchSchedule -UpdateTime "02:00" -Force
        Creates tasks with custom update time
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$UpdateTime = "03:00",
        
        [Parameter()]
        [string]$NotificationTime = "09:00",
        
        [Parameter()]
        [switch]$Force
    )
    
    $config = Get-PatchMyPCConfig
    $taskPath = "\PsPatchMyPC\"
    
    Write-PatchLog "Registering PsPatchMyPC scheduled tasks..." -Type Info
    
    try {
        # Create SYSTEM task for update engine
        $systemTaskName = "PsPatchMyPC-UpdateEngine"
        $systemTaskExists = Get-ScheduledTask -TaskName $systemTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
        
        if ($systemTaskExists -and -not $Force) {
            Write-PatchLog "Update engine task already exists. Use -Force to overwrite." -Type Warning
        }
        else {
            $systemAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
                -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"Import-Module PsPatchMyPC; Start-PatchCycle -NoReboot`""
            
            $systemTrigger = New-ScheduledTaskTrigger -Daily -At $UpdateTime
            
            $systemPrincipal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" `
                -LogonType ServiceAccount -RunLevel Highest
            
            $systemSettings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -StartWhenAvailable `
                -ExecutionTimeLimit (New-TimeSpan -Hours 4) `
                -RestartCount 3 `
                -RestartInterval (New-TimeSpan -Minutes 10) `
                -MultipleInstances IgnoreNew
            
            if ($systemTaskExists) {
                Unregister-ScheduledTask -TaskName $systemTaskName -TaskPath $taskPath -Confirm:$false
            }
            
            Register-ScheduledTask -TaskName $systemTaskName -TaskPath $taskPath `
                -Action $systemAction -Trigger $systemTrigger `
                -Principal $systemPrincipal -Settings $systemSettings -Force | Out-Null
            
            Write-PatchLog "Created SYSTEM task: $systemTaskName (runs at $UpdateTime)" -Type Info
        }
        
        # Create User task for notifications at logon
        $userTaskName = "PsPatchMyPC-UserNotification"
        $userTaskExists = Get-ScheduledTask -TaskName $userTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
        
        if ($userTaskExists -and -not $Force) {
            Write-PatchLog "User notification task already exists. Use -Force to overwrite." -Type Warning
        }
        else {
            $userAction = New-ScheduledTaskAction -Execute "PowerShell.exe" `
                -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"Import-Module PsPatchMyPC; Show-PatchNotification -Type Toast`""
            
            $userTrigger = New-ScheduledTaskTrigger -AtLogon
            
            $userPrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Limited
            
            $userSettings = New-ScheduledTaskSettingsSet `
                -AllowStartIfOnBatteries `
                -DontStopIfGoingOnBatteries `
                -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
            
            if ($userTaskExists) {
                Unregister-ScheduledTask -TaskName $userTaskName -TaskPath $taskPath -Confirm:$false
            }
            
            Register-ScheduledTask -TaskName $userTaskName -TaskPath $taskPath `
                -Action $userAction -Trigger $userTrigger `
                -Principal $userPrincipal -Settings $userSettings -Force | Out-Null
            
            Write-PatchLog "Created User task: $userTaskName (runs at logon)" -Type Info
        }
        
        Write-PatchLog "PsPatchMyPC scheduled tasks registered successfully" -Type Info
        return $true
    }
    catch {
        Write-PatchLog "Failed to register scheduled tasks: $_" -Type Error
        return $false
    }
}

function Unregister-PatchSchedule {
    <#
    .SYNOPSIS
        Removes PsPatchMyPC scheduled tasks
    .DESCRIPTION
        Unregisters all PsPatchMyPC scheduled tasks
    .PARAMETER TaskName
        Specific task to remove, or All for all tasks
    .EXAMPLE
        Unregister-PatchSchedule
        Removes all PsPatchMyPC tasks
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('All', 'UpdateEngine', 'UserNotification')]
        [string]$TaskName = 'All'
    )
    
    $taskPath = "\PsPatchMyPC\"
    
    try {
        $tasks = @()
        
        switch ($TaskName) {
            'All' {
                $tasks = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue
            }
            'UpdateEngine' {
                $tasks = Get-ScheduledTask -TaskName "PsPatchMyPC-UpdateEngine" -TaskPath $taskPath -ErrorAction SilentlyContinue
            }
            'UserNotification' {
                $tasks = Get-ScheduledTask -TaskName "PsPatchMyPC-UserNotification" -TaskPath $taskPath -ErrorAction SilentlyContinue
            }
        }
        
        foreach ($task in $tasks) {
            Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $taskPath -Confirm:$false
            Write-PatchLog "Removed scheduled task: $($task.TaskName)" -Type Info
        }
        
        return $true
    }
    catch {
        Write-PatchLog "Failed to unregister scheduled tasks: $_" -Type Error
        return $false
    }
}

function Get-PatchSchedule {
    <#
    .SYNOPSIS
        Gets PsPatchMyPC scheduled task information
    .DESCRIPTION
        Returns status and configuration of PsPatchMyPC scheduled tasks
    .EXAMPLE
        Get-PatchSchedule
    #>
    [CmdletBinding()]
    param()
    
    $taskPath = "\PsPatchMyPC\"
    
    try {
        $tasks = Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue
        
        $results = foreach ($task in $tasks) {
            $taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
            
            [PSCustomObject]@{
                TaskName       = $task.TaskName
                State          = $task.State
                LastRunTime    = $taskInfo.LastRunTime
                LastResult     = $taskInfo.LastTaskResult
                NextRunTime    = $taskInfo.NextRunTime
                NumberOfMissedRuns = $taskInfo.NumberOfMissedRuns
            }
        }
        
        return $results
    }
    catch {
        Write-PatchLog "Failed to get scheduled task info: $_" -Type Error
        return @()
    }
}

function Start-PatchSchedule {
    <#
    .SYNOPSIS
        Manually triggers the update engine task
    .DESCRIPTION
        Runs the scheduled update task immediately
    .EXAMPLE
        Start-PatchSchedule
    #>
    [CmdletBinding()]
    param()
    
    try {
        Start-ScheduledTask -TaskName "PsPatchMyPC-UpdateEngine" -TaskPath "\PsPatchMyPC\"
        Write-PatchLog "Manually triggered update engine task" -Type Info
        return $true
    }
    catch {
        Write-PatchLog "Failed to start scheduled task: $_" -Type Error
        return $false
    }
}

