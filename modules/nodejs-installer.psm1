# Node.js Installer Module for Clemp
# Handles silent installation of Node.js using MSI

function Get-NodeJsDownloadUrl {
    <#
    .SYNOPSIS
        Gets Node.js download URL from config
    .OUTPUTS
        System.String
    #>
    $configPath = Join-Path $PSScriptRoot "..\config\versions.json"

    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    return $config.nodejs.download_url
}

function Get-NodeJsVersion {
    <#
    .SYNOPSIS
        Gets Node.js version from config
    .OUTPUTS
        System.String
    #>
    $configPath = Join-Path $PSScriptRoot "..\config\versions.json"

    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    return $config.nodejs.version
}

function Download-NodeJsInstaller {
    <#
    .SYNOPSIS
        Downloads Node.js MSI installer
    .PARAMETER OutputPath
        Directory to save installer
    .OUTPUTS
        System.String
    #>
    param(
        [string]$OutputPath = "$env:TEMP\clemp_install"
    )

    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $url = Get-NodeJsDownloadUrl
    $config = Get-NodeJsVersion
    $msiFileName = "node-v${config}-x64.msi"
    $installerPath = Join-Path $OutputPath $msiFileName

    Write-Host "Downloading Node.js v$config from: $url"
    Write-Host "Saving to: $installerPath"

    try {
        # Download using Invoke-WebRequest (more reliable than WebClient)
        Write-Host "Downloading Node.js v$config..."
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $installerPath -UseBasicParsing -TimeoutSec 300
        $ProgressPreference = 'Continue'

        if (Test-Path $installerPath) {
            $fileSize = (Get-Item $installerPath).Length / 1MB
            Write-Host "Downloaded Node.js installer ($([math]::Round($fileSize, 2)) MB)"
            return $installerPath
        } else {
            throw "Download failed - file not found"
        }
    }
    catch {
        throw "Failed to download Node.js: $_"
    }
}

function Install-NodeJs {
    <#
    .SYNOPSIS
        Installs Node.js silently using MSI
    .PARAMETER InstallerPath
        Path to Node.js MSI installer
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$InstallerPath
    )

    if (-not (Test-Path $InstallerPath)) {
        throw "Node.js installer not found: $InstallerPath"
    }

    Write-Host "Installing Node.js silently..."

    try {
        # Silent installation using msiexec
        $process = Start-Process -FilePath "msiexec.exe" `
            -ArgumentList "/qn", "/i", $InstallerPath `
            -Wait `
            -PassThru

        $exitCode = $process.ExitCode

        if ($exitCode -eq 0 -or $exitCode -eq 3010) {
            # 3010 means already installed, which is fine
            Write-Host "Node.js installed successfully"
            return $true
        } else {
            Write-Error "Installation failed with exit code: $exitCode"
            return $false
        }
    }
    catch {
        Write-Error "Failed to install Node.js: $_"
        return $false
    }
}

function Add-NodeJsToPath {
    <#
    .SYNOPSIS
        Adds Node.js to system PATH permanently
    .OUTPUTS
        System.Boolean
    #>
    try {
        # Default Node.js installation path
        $nodePath = "$env:ProgramFiles\nodejs"

        # Get current PATH
        $pathEnv = [Environment]::GetEnvironmentVariable("Path", "Machine") -split ';'

        # Check if Node.js already in PATH
        if ($nodePath -in $pathEnv) {
            Write-Host "Node.js already in PATH"
            return $true
        }

        # Add Node.js to PATH
        $newPath = $pathEnv + $nodePath
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")

        # Notify running applications
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "Process")

        Write-Host "Node.js added to PATH (requires restart)"

        return $true
    }
    catch {
        Write-Error "Failed to update PATH: $_"
        return $false
    }
}

function Refresh-PathEnvironment {
    <#
    .SYNOPSIS
        Refreshes PATH environment for current session
    #>
    try {
        # Add Node.js path to current session explicitly
        $nodePath = "$env:ProgramFiles\nodejs"

        # Get current process PATH
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Process")

        # Check if Node.js is already in PATH
        if ($currentPath -notlike "*$nodePath*") {
            # Add Node.js to beginning of PATH
            $env:Path = "$nodePath;$currentPath"
            Write-Host "Added Node.js to current session PATH: $nodePath"
        } else {
            Write-Host "Node.js already in current session PATH"
        }

        return $true
    }
    catch {
        Write-Error "Failed to refresh PATH: $_"
        return $false
    }
}

function Remove-NodeJsInstaller {
    <#
    .SYNOPSIS
        Removes Node.js installer after installation
    .PARAMETER InstallerPath
        Path to installer to remove
    #>
    param(
        [string]$InstallerPath
    )

    if (Test-Path $InstallerPath) {
        Remove-Item -Path $InstallerPath -Force
        Write-Host "Cleaned up Node.js installer"
    }
}

function Install-NodeJsComplete {
    <#
    .SYNOPSIS
        Complete Node.js installation workflow: download, install, PATH
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$TempDir = "$env:TEMP\clemp_install"
    )

    try {
        # Step 1: Download
        $installerPath = Download-NodeJsInstaller -OutputPath $TempDir

        # Step 2: Install
        $installed = Install-NodeJs -InstallerPath $installerPath
        if (-not $installed) {
            return $false
        }

        # Step 3: Add to PATH
        $pathUpdated = Add-NodeJsToPath
        if (-not $pathUpdated) {
            return $false
        }

        # Step 4: Refresh current session
        $refreshed = Refresh-PathEnvironment
        if (-not $refreshed) {
            return $false
        }

        # Step 5: Cleanup
        Remove-NodeJsInstaller -InstallerPath $installerPath

        Write-Host "Node.js installation completed successfully!"
        return $true
    }
    catch {
        Write-Error "Node.js installation failed: $_"
        return $false
    }
}

function Get-NodeJsInfo {
    <#
    .SYNOPSIS
        Gets Node.js installation information
    .OUTPUTS
        System.Hashtable
    #>
    try {
        $version = node --version
        $npmVersion = npm --version

        $info = @{
            Installed = $true
            Version = $version
            NpmVersion = $npmVersion
            Path = (Get-Command "node" -ErrorAction SilentlyContinue).Source
        }
        return $info
    }
    catch {
        return @{
            Installed = $false
            Version = "Not Installed"
            NpmVersion = "Not Installed"
            Path = $null
        }
    }
}

Export-ModuleMember -Function `
    Get-NodeJsDownloadUrl,
    Get-NodeJsVersion,
    Download-NodeJsInstaller,
    Install-NodeJs,
    Add-NodeJsToPath,
    Refresh-PathEnvironment,
    Remove-NodeJsInstaller,
    Install-NodeJsComplete,
    Get-NodeJsInfo
