function Initialize-Winget {
    <#
    .SYNOPSIS
        Initializes winget and Microsoft.WinGet.Client module
    .DESCRIPTION
        Ensures winget is available by installing the Microsoft.WinGet.Client PowerShell module
        and bootstrapping winget if necessary. Works in both user and SYSTEM context.
    .PARAMETER Force
        Force reinstall even if already installed
    .EXAMPLE
        Initialize-Winget
        Ensures winget is available for use
    .EXAMPLE
        Initialize-Winget -Force
        Reinstalls/repairs winget components
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force
    )
    
    Write-PatchLog "Initializing winget..." -Type Info
    
    try {
        # Check if Microsoft.WinGet.Client module is installed
        $module = Get-Module -Name 'Microsoft.WinGet.Client' -ListAvailable -ErrorAction SilentlyContinue
        
        if (-not $module -or $Force) {
            Write-PatchLog "Installing Microsoft.WinGet.Client module..." -Type Info
            
            # Ensure NuGet provider is available
            $nuget = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue
            if (-not $nuget -or $nuget.Version -lt [Version]'2.8.5.201') {
                Write-PatchLog "Installing NuGet provider..." -Type Info
                Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
            }
            
            # Set PSGallery as trusted if not already
            $repo = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
            if ($repo.InstallationPolicy -ne 'Trusted') {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            }
            
            # Install the module
            Install-Module -Name Microsoft.WinGet.Client -Force -Scope AllUsers -AllowClobber -ErrorAction Stop
            Write-PatchLog "Microsoft.WinGet.Client module installed successfully" -Type Info
        }
        else {
            Write-PatchLog "Microsoft.WinGet.Client module already installed (v$($module.Version))" -Type Info
        }
        
        # Import the module
        Import-Module Microsoft.WinGet.Client -Force -ErrorAction Stop
        
        # Bootstrap/repair winget package manager
        Write-PatchLog "Repairing WinGet package manager..." -Type Info
        Repair-WinGetPackageManager -AllUsers -Force -ErrorAction SilentlyContinue
        
        # Verify winget is working
        $testResult = Get-WinGetVersion -ErrorAction SilentlyContinue
        if ($testResult) {
            Write-PatchLog "Winget initialized successfully (v$testResult)" -Type Info
            return $true
        }
        else {
            throw "Winget verification failed"
        }
    }
    catch {
        Write-PatchLog "Failed to initialize winget: $_" -Type Error
        return $false
    }
}

function Test-WingetAvailable {
    <#
    .SYNOPSIS
        Tests if winget is available and functional
    .DESCRIPTION
        Checks if the Microsoft.WinGet.Client module is installed and winget is working
    .PARAMETER AutoInstall
        Automatically install winget if not available
    .EXAMPLE
        if (Test-WingetAvailable) { Get-WingetUpdates }
    .EXAMPLE
        Test-WingetAvailable -AutoInstall
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [switch]$AutoInstall
    )
    
    try {
        # Check for module
        $module = Get-Module -Name 'Microsoft.WinGet.Client' -ListAvailable -ErrorAction SilentlyContinue
        
        if (-not $module) {
            if ($AutoInstall) {
                return Initialize-Winget
            }
            return $false
        }
        
        # Import and test
        Import-Module Microsoft.WinGet.Client -Force -ErrorAction SilentlyContinue
        $version = Get-WinGetVersion -ErrorAction SilentlyContinue
        
        return ($null -ne $version)
    }
    catch {
        Write-Verbose "Winget check failed: $_"
        return $false
    }
}

function Get-WingetUpdates {
    <#
    .SYNOPSIS
        Gets available winget package updates
    .DESCRIPTION
        Returns a list of packages with available updates
    .PARAMETER IncludeUnknown
        Include packages with unknown versions (always show as update available)
    .EXAMPLE
        Get-WingetUpdates
        Lists all available updates
    .EXAMPLE
        Get-WingetUpdates -IncludeUnknown
        Lists all updates including those with unknown version info
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeUnknown
    )
    
    if (-not (Test-WingetAvailable -AutoInstall)) {
        Write-PatchLog "Winget not available" -Type Error
        return @()
    }
    
    try {
        Write-PatchLog "Checking for winget package updates..." -Type Info
        
        $packages = Get-WinGetPackage -ErrorAction Stop | 
            Where-Object { $_.IsUpdateAvailable -or ($IncludeUnknown -and $_.InstalledVersion -eq 'Unknown') }
        
        $updates = foreach ($pkg in $packages) {
            [PSCustomObject]@{
                Id               = $pkg.Id
                Name             = $pkg.Name
                InstalledVersion = $pkg.InstalledVersion
                AvailableVersion = $pkg.AvailableVersion
                Source           = $pkg.Source
            }
        }
        
        Write-PatchLog "Found $($updates.Count) packages with updates available" -Type Info
        return $updates
    }
    catch {
        Write-PatchLog "Failed to get winget updates: $_" -Type Error
        return @()
    }
}

function Install-WingetUpdate {
    <#
    .SYNOPSIS
        Installs a winget package update
    .DESCRIPTION
        Updates a specific package using winget
    .PARAMETER Id
        The winget package ID to update
    .PARAMETER Silent
        Install silently without user interaction
    .PARAMETER AcceptPackageAgreements
        Automatically accept package license agreements
    .EXAMPLE
        Install-WingetUpdate -Id 'Google.Chrome'
    .EXAMPLE
        Install-WingetUpdate -Id 'Mozilla.Firefox' -Silent
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Id,
        
        [Parameter()]
        [switch]$Silent,
        
        [Parameter()]
        [switch]$AcceptPackageAgreements
    )
    
    process {
        if (-not (Test-WingetAvailable)) {
            Write-PatchLog "Winget not available" -Type Error
            return [PSCustomObject]@{
                Id      = $Id
                Success = $false
                Message = 'Winget not available'
            }
        }
        
        try {
            Write-PatchLog "Updating package: $Id" -Type Info
            
            $updateParams = @{
                Id = $Id
            }
            
            if ($Silent) {
                $updateParams['Mode'] = 'Silent'
            }
            
            $result = Update-WinGetPackage @updateParams -ErrorAction Stop
            
            $success = $result.Status -eq 'Ok'
            $message = if ($success) { "Successfully updated $Id" } else { "Update failed: $($result.Status)" }
            
            Write-PatchLog $message -Type $(if ($success) { 'Info' } else { 'Error' })
            
            return [PSCustomObject]@{
                Id             = $Id
                Success        = $success
                Message        = $message
                RebootRequired = $result.RebootRequired
            }
        }
        catch {
            Write-PatchLog "Failed to update $Id : $_" -Type Error
            return [PSCustomObject]@{
                Id      = $Id
                Success = $false
                Message = $_.Exception.Message
            }
        }
    }
}

function Add-WingetSource {
    <#
    .SYNOPSIS
        Adds a custom winget source
    .DESCRIPTION
        Adds a private or custom winget repository source
    .PARAMETER Name
        Name for the source
    .PARAMETER Url
        URL of the source
    .PARAMETER Type
        Source type (default: Microsoft.Rest)
    .EXAMPLE
        Add-WingetSource -Name 'PrivateRepo' -Url 'https://winget.contoso.com/api'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter()]
        [string]$Type = 'Microsoft.Rest'
    )
    
    try {
        # Check environment variable override
        if ($env:PSPMPC_WINGET_SOURCE) {
            $Url = $env:PSPMPC_WINGET_SOURCE
            Write-PatchLog "Using winget source from environment: $Url" -Type Info
        }
        
        Write-PatchLog "Adding winget source: $Name ($Url)" -Type Info
        
        # Use winget CLI for source management (not available in PowerShell module)
        $result = & winget source add --name $Name --arg $Url --type $Type --accept-source-agreements 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-PatchLog "Successfully added winget source: $Name" -Type Info
            return $true
        }
        else {
            Write-PatchLog "Failed to add winget source: $result" -Type Warning
            return $false
        }
    }
    catch {
        Write-PatchLog "Failed to add winget source: $_" -Type Error
        return $false
    }
}

