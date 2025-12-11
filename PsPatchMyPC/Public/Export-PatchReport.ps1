function Export-PatchReport {
    <#
    .SYNOPSIS
        Exports a patch status report
    .DESCRIPTION
        Generates a comprehensive report of patch status for compliance reporting
    .PARAMETER Path
        Output file path (supports .json, .csv, .html)
    .PARAMETER Format
        Output format: JSON, CSV, HTML, or Console
    .PARAMETER IncludeHistory
        Include installation history
    .EXAMPLE
        Export-PatchReport -Path "C:\Reports\patch_status.json"
    .EXAMPLE
        Export-PatchReport -Format Console
        Displays report to console
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Path,
        
        [Parameter()]
        [ValidateSet('JSON', 'CSV', 'HTML', 'Console')]
        [string]$Format = 'JSON',
        
        [Parameter()]
        [switch]$IncludeHistory
    )
    
    try {
        Write-PatchLog "Generating patch report..." -Type Info
        
        # Gather data
        $updates = Get-PatchStatus -ManagedOnly
        $compliance = Get-PatchCompliance
        $schedule = Get-PatchSchedule
        $deferralStates = Get-AllDeferralStates
        
        $report = [PSCustomObject]@{
            ReportTimestamp   = [datetime]::UtcNow.ToString('o')
            ComputerName      = $env:COMPUTERNAME
            OSVersion         = [Environment]::OSVersion.Version.ToString()
            WingetVersion     = $(try { Get-WinGetVersion -ErrorAction SilentlyContinue } catch { 'Not Installed' })
            Compliance        = @{
                IsCompliant      = $compliance.Compliant
                TotalPending     = $compliance.TotalPending
                CriticalPending  = $compliance.CriticalPending
                HighPending      = $compliance.HighPending
                PastDeadline     = $compliance.PastDeadline
            }
            PendingUpdates    = @($updates | ForEach-Object {
                @{
                    AppId            = $_.AppId
                    AppName          = $_.AppName
                    InstalledVersion = $_.InstalledVersion
                    AvailableVersion = $_.AvailableVersion
                    Priority         = $_.Priority.ToString()
                    ProcessesRunning = $_.ProcessesRunning
                }
            })
            DeferralStatus    = @($deferralStates | ForEach-Object {
                @{
                    AppId           = $_.AppId
                    DeferralCount   = $_.DeferralCount
                    MaxDeferrals    = $_.MaxDeferrals
                    Phase           = $_.Phase.ToString()
                    DeadlineDate    = $_.DeadlineDate.ToString('o')
                }
            })
            ScheduledTasks    = @($schedule | ForEach-Object {
                @{
                    TaskName    = $_.TaskName
                    State       = $_.State.ToString()
                    LastRunTime = $_.LastRunTime
                    NextRunTime = $_.NextRunTime
                }
            })
        }
        
        # Add history if requested
        if ($IncludeHistory) {
            $report | Add-Member -NotePropertyName 'History' -NotePropertyValue @(
                Get-PatchMyPCLogs -Days 30 -Type Info | 
                    Where-Object { $_.Component -like '*Install*' -or $_.Component -like '*Update*' } |
                    Select-Object -First 100 |
                    ForEach-Object {
                        @{
                            Timestamp = $_.Timestamp.ToString('o')
                            Type      = $_.Type
                            Message   = $_.Message
                        }
                    }
            )
        }
        
        # Output based on format
        switch ($Format) {
            'JSON' {
                $json = $report | ConvertTo-Json -Depth 10
                if ($Path) {
                    $json | Out-File -FilePath $Path -Encoding UTF8 -Force
                    Write-PatchLog "Exported JSON report to $Path" -Type Info
                }
                else {
                    return $json
                }
            }
            'CSV' {
                $csvData = $updates | Select-Object AppId, AppName, InstalledVersion, AvailableVersion, Priority
                if ($Path) {
                    $csvData | Export-Csv -Path $Path -NoTypeInformation -Force
                    Write-PatchLog "Exported CSV report to $Path" -Type Info
                }
                else {
                    return $csvData
                }
            }
            'HTML' {
                $html = ConvertTo-HtmlReport -Report $report
                if ($Path) {
                    $html | Out-File -FilePath $Path -Encoding UTF8 -Force
                    Write-PatchLog "Exported HTML report to $Path" -Type Info
                }
                else {
                    return $html
                }
            }
            'Console' {
                Write-Host "`n=== PsPatchMyPC Status Report ===" -ForegroundColor Cyan
                Write-Host "Generated: $($report.ReportTimestamp)"
                Write-Host "Computer: $($report.ComputerName)"
                Write-Host ""
                
                Write-Host "Compliance Status:" -ForegroundColor Yellow
                Write-Host "  Compliant: $(if($report.Compliance.IsCompliant){'Yes'}else{'No'})"
                Write-Host "  Pending Updates: $($report.Compliance.TotalPending)"
                Write-Host "  Critical: $($report.Compliance.CriticalPending)"
                Write-Host "  Past Deadline: $($report.Compliance.PastDeadline)"
                Write-Host ""
                
                if ($report.PendingUpdates.Count -gt 0) {
                    Write-Host "Pending Updates:" -ForegroundColor Yellow
                    foreach ($upd in $report.PendingUpdates) {
                        Write-Host "  - $($upd.AppName): $($upd.InstalledVersion) -> $($upd.AvailableVersion) [$($upd.Priority)]"
                    }
                }
                else {
                    Write-Host "No pending updates." -ForegroundColor Green
                }
                
                return $report
            }
        }
    }
    catch {
        Write-PatchLog "Failed to export report: $_" -Type Error
        throw
    }
}

function ConvertTo-HtmlReport {
    <#
    .SYNOPSIS
        Converts report object to HTML
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Report
    )
    
    $complianceColor = if ($Report.Compliance.IsCompliant) { '#28a745' } else { '#dc3545' }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>PsPatchMyPC Status Report</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 900px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 2px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #333; margin-top: 30px; }
        .compliance-badge { display: inline-block; padding: 8px 16px; border-radius: 4px; color: white; font-weight: bold; background: $complianceColor; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #0078d4; color: white; }
        tr:hover { background: #f5f5f5; }
        .stats { display: flex; gap: 20px; margin: 20px 0; }
        .stat-box { flex: 1; padding: 20px; background: #f8f9fa; border-radius: 4px; text-align: center; }
        .stat-value { font-size: 32px; font-weight: bold; color: #0078d4; }
        .stat-label { color: #666; }
        .meta { color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>PsPatchMyPC Status Report</h1>
        <p class="meta">Generated: $($Report.ReportTimestamp) | Computer: $($Report.ComputerName) | OS: $($Report.OSVersion)</p>
        
        <h2>Compliance Status</h2>
        <span class="compliance-badge">$(if($Report.Compliance.IsCompliant){'COMPLIANT'}else{'NON-COMPLIANT'})</span>
        
        <div class="stats">
            <div class="stat-box">
                <div class="stat-value">$($Report.Compliance.TotalPending)</div>
                <div class="stat-label">Pending Updates</div>
            </div>
            <div class="stat-box">
                <div class="stat-value">$($Report.Compliance.CriticalPending)</div>
                <div class="stat-label">Critical</div>
            </div>
            <div class="stat-box">
                <div class="stat-value">$($Report.Compliance.PastDeadline)</div>
                <div class="stat-label">Past Deadline</div>
            </div>
        </div>
        
        <h2>Pending Updates</h2>
        <table>
            <tr><th>Application</th><th>Installed</th><th>Available</th><th>Priority</th></tr>
            $(foreach ($upd in $Report.PendingUpdates) {
                "<tr><td>$($upd.AppName)</td><td>$($upd.InstalledVersion)</td><td>$($upd.AvailableVersion)</td><td>$($upd.Priority)</td></tr>"
            })
            $(if ($Report.PendingUpdates.Count -eq 0) { "<tr><td colspan='4'>No pending updates</td></tr>" })
        </table>
        
        <h2>Scheduled Tasks</h2>
        <table>
            <tr><th>Task</th><th>State</th><th>Last Run</th><th>Next Run</th></tr>
            $(foreach ($task in $Report.ScheduledTasks) {
                "<tr><td>$($task.TaskName)</td><td>$($task.State)</td><td>$($task.LastRunTime)</td><td>$($task.NextRunTime)</td></tr>"
            })
        </table>
    </div>
</body>
</html>
"@
    
    return $html
}

function Get-ManagedApplications {
    <#
    .SYNOPSIS
        Gets the list of managed applications
    .DESCRIPTION
        Returns applications defined in the management catalog
    .PARAMETER EnabledOnly
        Only return enabled applications
    .EXAMPLE
        Get-ManagedApplications
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$EnabledOnly
    )
    
    $apps = Get-ManagedApplicationsInternal
    
    if ($EnabledOnly) {
        $apps = $apps | Where-Object { $_.Enabled }
    }
    
    return $apps
}

function Add-ManagedApplication {
    <#
    .SYNOPSIS
        Adds an application to the managed catalog
    .DESCRIPTION
        Adds a new application with its winget ID and configuration
    .PARAMETER Id
        Winget package ID
    .PARAMETER Name
        Display name
    .PARAMETER Priority
        Update priority
    .PARAMETER ConflictingProcesses
        Processes that must be closed before update
    .EXAMPLE
        Add-ManagedApplication -Id 'Google.Chrome' -Name 'Google Chrome' -ConflictingProcesses @('chrome.exe')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [ValidateSet('Critical', 'High', 'Normal', 'Low')]
        [string]$Priority = 'Normal',
        
        [Parameter()]
        [string[]]$ConflictingProcesses = @()
    )
    
    try {
        $config = Get-ModuleConfiguration
        $catalogPath = Join-Path $config.ConfigPath 'applications.json'
        
        # Load existing catalog
        $catalog = @{ applications = @() }
        if (Test-Path $catalogPath) {
            $catalog = Get-Content -Path $catalogPath -Raw | ConvertFrom-Json
        }
        
        # Check if already exists
        $existing = $catalog.applications | Where-Object { $_.id -eq $Id }
        if ($existing) {
            Write-PatchLog "Application $Id already exists in catalog" -Type Warning
            return $false
        }
        
        # Add new application
        $newApp = @{
            id = $Id
            name = $Name
            enabled = $true
            priority = $Priority
            conflictingProcesses = $ConflictingProcesses
            preScript = $null
            postScript = $null
            installArguments = $null
            requiresReboot = $false
            deferralOverride = $null
        }
        
        $catalog.applications += $newApp
        
        # Save catalog
        $catalog | ConvertTo-Json -Depth 10 | Out-File -FilePath $catalogPath -Encoding UTF8 -Force
        
        Write-PatchLog "Added $Name ($Id) to managed applications" -Type Info
        return $true
    }
    catch {
        Write-PatchLog "Failed to add application: $_" -Type Error
        return $false
    }
}

function Remove-ManagedApplication {
    <#
    .SYNOPSIS
        Removes an application from the managed catalog
    .PARAMETER Id
        Winget package ID to remove
    .EXAMPLE
        Remove-ManagedApplication -Id 'Google.Chrome'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )
    
    try {
        $config = Get-ModuleConfiguration
        $catalogPath = Join-Path $config.ConfigPath 'applications.json'
        
        if (-not (Test-Path $catalogPath)) {
            Write-PatchLog "Application catalog not found" -Type Warning
            return $false
        }
        
        $catalog = Get-Content -Path $catalogPath -Raw | ConvertFrom-Json
        $catalog.applications = @($catalog.applications | Where-Object { $_.id -ne $Id })
        
        $catalog | ConvertTo-Json -Depth 10 | Out-File -FilePath $catalogPath -Encoding UTF8 -Force
        
        Write-PatchLog "Removed $Id from managed applications" -Type Info
        return $true
    }
    catch {
        Write-PatchLog "Failed to remove application: $_" -Type Error
        return $false
    }
}

