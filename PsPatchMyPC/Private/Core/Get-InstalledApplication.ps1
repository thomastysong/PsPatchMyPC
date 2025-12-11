function Get-InstalledApplication {
    <#
    .SYNOPSIS
        Gets installed applications from registry and winget
    .DESCRIPTION
        Retrieves installed application information using both registry detection
        and winget for comprehensive coverage
    .PARAMETER AppId
        Optional winget app ID to filter results
    .PARAMETER Name
        Optional application name pattern to filter results
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$AppId,
        
        [Parameter()]
        [string]$Name
    )
    
    $results = @()
    
    # Try winget first if available
    if (Test-WingetAvailableInternal) {
        try {
            $wingetParams = @{}
            if ($AppId) {
                $wingetParams['Id'] = $AppId
            }
            
            $packages = Get-WinGetPackage @wingetParams -ErrorAction SilentlyContinue
            
            foreach ($pkg in $packages) {
                if ($Name -and $pkg.Name -notlike "*$Name*") { continue }
                
                $availVer = if ($pkg.AvailableVersions -and $pkg.AvailableVersions.Count -gt 0) { 
                    $pkg.AvailableVersions[0] 
                } else { 
                    $null 
                }
                $results += [PSCustomObject]@{
                    Source           = 'Winget'
                    AppId            = $pkg.Id
                    Name             = $pkg.Name
                    Version          = $pkg.InstalledVersion
                    AvailableVersion = $availVer
                    UpdateAvailable  = $pkg.IsUpdateAvailable
                    Publisher        = $pkg.Source
                }
            }
        }
        catch {
            Write-PatchLog "Winget query failed: $_" -Type Warning
        }
    }
    
    # Also check registry for apps not in winget
    $registryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    
    foreach ($regPath in $registryPaths) {
        try {
            $regApps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -and $_.DisplayVersion }
            
            foreach ($app in $regApps) {
                if ($Name -and $app.DisplayName -notlike "*$Name*") { continue }
                
                # Skip if already found via winget
                $existingWinget = $results | Where-Object { 
                    $_.Name -eq $app.DisplayName -or 
                    ($_.AppId -and $app.PSChildName -like "*$($_.AppId)*")
                }
                if ($existingWinget) { continue }
                
                $results += [PSCustomObject]@{
                    Source           = 'Registry'
                    AppId            = $app.PSChildName
                    Name             = $app.DisplayName
                    Version          = $app.DisplayVersion
                    AvailableVersion = $null
                    UpdateAvailable  = $false
                    Publisher        = $app.Publisher
                }
            }
        }
        catch {
            # Continue with other paths
        }
    }
    
    return $results
}

function Test-WingetAvailableInternal {
    <#
    .SYNOPSIS
        Internal check for winget availability
    #>
    [CmdletBinding()]
    param()
    
    try {
        $module = Get-Module -Name 'Microsoft.WinGet.Client' -ListAvailable -ErrorAction SilentlyContinue
        return ($null -ne $module)
    }
    catch {
        return $false
    }
}

