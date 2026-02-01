function Register-ToastProtocolHandler {
    <#
    .SYNOPSIS
        Registers a custom protocol handler for toast notification actions
    .DESCRIPTION
        Creates registry entries for a custom URI protocol (e.g., pspatchmypc:)
        that handles toast button clicks and redirects them to PsPatchMyPC.
        This enables responding to user actions even after the PowerShell session ends.
    .PARAMETER ProtocolScheme
        The protocol scheme to register (default: pspatchmypc)
    .PARAMETER Force
        Overwrite existing registration
    .EXAMPLE
        Register-ToastProtocolHandler
    .EXAMPLE
        Register-ToastProtocolHandler -ProtocolScheme 'mycompany-updates'
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProtocolScheme = 'pspatchmypc',

        [Parameter()]
        [switch]$Force
    )

    $config = Get-PatchMyPCConfig
    if ($ProtocolScheme -eq 'pspatchmypc' -and $config.Notifications.Enterprise.ProtocolScheme) {
        $ProtocolScheme = $config.Notifications.Enterprise.ProtocolScheme
    }

    $registryPath = "HKCU:\Software\Classes\$ProtocolScheme"

    # Check if already registered
    if ((Test-Path $registryPath) -and -not $Force) {
        Write-PatchLog "Protocol handler '$ProtocolScheme' already registered" -Type Info
        return $true
    }

    try {
        # Create protocol handler registry entries
        $null = New-Item -Path $registryPath -Force
        $null = New-ItemProperty -Path $registryPath -Name "(Default)" -Value "URL:PsPatchMyPC Protocol" -Force
        $null = New-ItemProperty -Path $registryPath -Name "URL Protocol" -Value "" -Force

        # Create DefaultIcon key
        $iconPath = "$registryPath\DefaultIcon"
        $null = New-Item -Path $iconPath -Force
        $null = New-ItemProperty -Path $iconPath -Name "(Default)" -Value "powershell.exe,0" -Force

        # Create shell\open\command key
        $commandPath = "$registryPath\shell\open\command"
        $null = New-Item -Path $commandPath -Force

        # Build command that handles the protocol activation
        $handlerScript = Join-Path $PSScriptRoot "Invoke-ToastAction.ps1"
        if (-not (Test-Path $handlerScript)) {
            # Create the handler script
            Initialize-ToastActionHandler
        }

        $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$handlerScript`" -Arguments `"%1`""
        $null = New-ItemProperty -Path $commandPath -Name "(Default)" -Value $command -Force

        Write-PatchLog "Registered protocol handler: $ProtocolScheme" -Type Info
        return $true
    }
    catch {
        Write-PatchLog "Failed to register protocol handler: $_" -Type Error
        return $false
    }
}

function Unregister-ToastProtocolHandler {
    <#
    .SYNOPSIS
        Removes the custom protocol handler registration
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ProtocolScheme = 'pspatchmypc'
    )

    $config = Get-PatchMyPCConfig
    if ($ProtocolScheme -eq 'pspatchmypc' -and $config.Notifications.Enterprise.ProtocolScheme) {
        $ProtocolScheme = $config.Notifications.Enterprise.ProtocolScheme
    }

    $registryPath = "HKCU:\Software\Classes\$ProtocolScheme"

    if (Test-Path $registryPath) {
        try {
            Remove-Item -Path $registryPath -Recurse -Force
            Write-PatchLog "Unregistered protocol handler: $ProtocolScheme" -Type Info
            return $true
        }
        catch {
            Write-PatchLog "Failed to unregister protocol handler: $_" -Type Error
            return $false
        }
    }

    return $true
}

function Initialize-ToastActionHandler {
    <#
    .SYNOPSIS
        Creates the toast action handler script
    .DESCRIPTION
        Creates a PowerShell script that handles protocol activations from toast buttons.
        Writes the action to a file that the main PsPatchMyPC process can monitor.
    #>
    [CmdletBinding()]
    param()

    $handlerScript = Join-Path $PSScriptRoot "Invoke-ToastAction.ps1"

    $scriptContent = @'
# Toast Action Handler for PsPatchMyPC
# This script is invoked when user clicks a toast notification button
param(
    [string]$Arguments
)

# Parse the protocol URI
# Format: pspatchmypc:action=update&appid=Google.Chrome
$actionData = @{}
if ($Arguments -match ':(.+)$') {
    $queryString = $Matches[1]
    $queryString -split '&' | ForEach-Object {
        if ($_ -match '(.+)=(.+)') {
            $actionData[$Matches[1]] = $Matches[2]
        }
    }
}

# Write action to response file for main process to pick up
$responseDir = Join-Path $env:ProgramData 'PsPatchMyPC\ToastResponses'
if (-not (Test-Path $responseDir)) {
    New-Item -Path $responseDir -ItemType Directory -Force | Out-Null
}

$responseFile = Join-Path $responseDir ("response_{0}.json" -f [guid]::NewGuid().ToString('n'))
$response = @{
    Timestamp = (Get-Date).ToString('o')
    Action = $actionData['action']
    AppId = $actionData['appid']
    SessionId = $actionData['session']
}

$response | ConvertTo-Json | Set-Content -Path $responseFile -Encoding UTF8

# If action is 'update', try to trigger immediate update
if ($actionData['action'] -eq 'update') {
    try {
        # Import module and trigger update for specific app
        Import-Module PsPatchMyPC -Force -ErrorAction SilentlyContinue
        if ($actionData['appid']) {
            Start-PatchCycle -AppId $actionData['appid'] -Force -ErrorAction SilentlyContinue
        }
        else {
            Start-PatchCycle -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        # Log error but don't fail
        $errorFile = Join-Path $responseDir "error_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $_.Exception.Message | Out-File -FilePath $errorFile -Encoding UTF8
    }
}
'@

    try {
        $scriptContent | Set-Content -Path $handlerScript -Encoding UTF8 -Force
        Write-PatchLog "Created toast action handler: $handlerScript" -Type Info
        return $true
    }
    catch {
        Write-PatchLog "Failed to create toast action handler: $_" -Type Error
        return $false
    }
}

function Get-ToastActionResponse {
    <#
    .SYNOPSIS
        Retrieves and processes toast action responses
    .DESCRIPTION
        Checks for response files created by toast button clicks
        and returns the action data
    .PARAMETER MaxAge
        Maximum age of response files to process (in seconds)
    .PARAMETER Delete
        Delete response files after reading
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$MaxAge = 300,

        [Parameter()]
        [switch]$Delete
    )

    $responseDir = Join-Path $env:ProgramData 'PsPatchMyPC\ToastResponses'
    if (-not (Test-Path $responseDir)) {
        return @()
    }

    $responses = @()
    $cutoff = (Get-Date).AddSeconds(-$MaxAge)

    Get-ChildItem -Path $responseDir -Filter "response_*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.LastWriteTime -gt $cutoff) {
            try {
                $content = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
                $responses += $content

                if ($Delete) {
                    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                Write-PatchLog "Failed to parse toast response: $_" -Type Warning
            }
        }
        elseif ($Delete) {
            # Clean up old files
            Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }

    return $responses
}

function Clear-ToastActionResponses {
    <#
    .SYNOPSIS
        Clears all toast action response files
    #>
    [CmdletBinding()]
    param()

    $responseDir = Join-Path $env:ProgramData 'PsPatchMyPC\ToastResponses'
    if (Test-Path $responseDir) {
        Get-ChildItem -Path $responseDir -Filter "*.json" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue

        Get-ChildItem -Path $responseDir -Filter "*.log" -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}
