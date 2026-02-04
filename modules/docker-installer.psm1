# Docker Desktop Installer Module for Clemp
# Handles silent installation and verification of Docker Desktop

function Get-DockerDownloadUrl {
    <#
    .SYNOPSIS
        Gets Docker Desktop download URL from config
    .OUTPUTS
        System.String
    #>
    $configPath = Join-Path $PSScriptRoot "..\config\versions.json"

    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    return $config.docker.download_url
}

function Download-DockerInstaller {
    <#
    .SYNOPSIS
        Downloads Docker Desktop installer
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

    $url = Get-DockerDownloadUrl
    $installerPath = Join-Path $OutputPath "DockerDesktopInstaller.exe"

    Write-Host "Downloading Docker Desktop from: $url"
    Write-Host "Saving to: $installerPath"

    try {
        # Download using Invoke-WebRequest (more reliable than WebClient)
        Write-Host "Downloading Docker Desktop..."
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $installerPath -UseBasicParsing -TimeoutSec 600
        $ProgressPreference = 'Continue'

        if (Test-Path $installerPath) {
            $fileSize = (Get-Item $installerPath).Length / 1MB
            Write-Host "Downloaded Docker Desktop installer ($([math]::Round($fileSize, 2)) MB)"
            return $installerPath
        } else {
            throw "Download failed - file not found"
        }
    }
    catch {
        throw "Failed to download Docker Desktop: $_"
    }
}

function Install-DockerDesktop {
    <#
    .SYNOPSIS
        Installs Docker Desktop silently
    .PARAMETER InstallerPath
        Path to Docker Desktop installer
    .OUTPUTS
    System.Boolean
    #>
    param(
        [string]$InstallerPath
    )

    if (-not (Test-Path $InstallerPath)) {
        throw "Docker installer not found: $InstallerPath"
    }

    Write-Host "Installing Docker Desktop silently..."

    try {
        # Silent installation command
        $process = Start-Process -FilePath $InstallerPath `
            -ArgumentList "install", "--quiet" `
            -Wait `
            -PassThru

        $exitCode = $process.ExitCode

        if ($exitCode -eq 0) {
            Write-Host "Docker Desktop installed successfully"
            return $true
        } else {
            Write-Error "Installation failed with exit code: $exitCode"
            return $false
        }
    }
    catch {
        Write-Error "Failed to install Docker Desktop: $_"
        return $false
    }
}

function Start-DockerDesktop {
    <#
    .SYNOPSIS
        Starts Docker Desktop application
    .OUTPUTS
    System.Boolean
    #>
    try {
        $dockerDesktopPath = "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"

        if (-not (Test-Path $dockerDesktopPath)) {
            Write-Error "Docker Desktop not found at: $dockerDesktopPath"
            return $false
        }

        Write-Host "Starting Docker Desktop..."
        Start-Process -FilePath $dockerDesktopPath

        # Wait a moment for it to start
        Start-Sleep -Seconds 5

        return $true
    }
    catch {
        Write-Error "Failed to start Docker Desktop: $_"
        return $false
    }
}

function Wait-DockerDaemon {
    <#
    .SYNOPSIS
        Waits for Docker daemon to become ready
    .PARAMETER TimeoutSeconds
        Maximum wait time in seconds
    .OUTPUTS
    System.Boolean
    #>
    param(
        [int]$TimeoutSeconds = 300
    )

    Write-Host "Waiting for Docker daemon to be ready (timeout: ${TimeoutSeconds}s)..."

    $startTime = Get-Date
    $timeout = (New-TimeSpan -Seconds $TimeoutSeconds)

    do {
        Start-Sleep -Seconds 5

        try {
            $result = docker ps 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Docker daemon is ready!"
                return $true
            }
        }
        catch {
            # Docker CLI not available yet, continue waiting
        }

        $elapsed = (Get-Date) - $startTime
        if ($elapsed -gt $timeout) {
            Write-Error "Timeout waiting for Docker daemon"
            return $false
        }

        Write-Progress -Activity "Waiting for Docker" -Status "Waiting" -PercentComplete (($elapsed.TotalSeconds / $TimeoutSeconds) * 100)
    } while ($true)
}

function Test-DockerInstallation {
    <#
    .SYNOPSIS
        Tests if Docker is properly installed and running
    .OUTPUTS
        System.Boolean
    #>
    try {
        # Test docker command
        $null = docker ps 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        # Test docker run
        $null = docker run --rm hello-world 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }

        return $true
    }
    catch {
        return $false
    }
}

function Remove-DockerInstaller {
    <#
    .SYNOPSIS
        Removes Docker Desktop installer after installation
    .PARAMETER InstallerPath
        Path to installer to remove
    #>
    param(
        [string]$InstallerPath
    )

    if (Test-Path $InstallerPath) {
        Remove-Item -Path $InstallerPath -Force
        Write-Host "Cleaned up Docker installer"
    }
}

function Install-DockerComplete {
    <#
    .SYNOPSIS
        Complete Docker installation workflow: download, install, verify
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$TempDir = "$env:TEMP\clemp_install"
    )

    try {
        # Step 1: Download
        $installerPath = Download-DockerInstaller -OutputPath $TempDir

        # Step 2: Install
        $installed = Install-DockerDesktop -InstallerPath $installerPath
        if (-not $installed) {
            return $false
        }

        # Step 3: Start Docker Desktop
        $started = Start-DockerDesktop
        if (-not $started) {
            return $false
        }

        # Step 4: Wait for daemon
        $ready = Wait-DockerDaemon -TimeoutSeconds 300
        if (-not $ready) {
            return $false
        }

        # Step 5: Verify
        $verified = Test-DockerInstallation
        if (-not $verified) {
            return $false
        }

        # Step 6: Cleanup
        Remove-DockerInstaller -InstallerPath $installerPath

        Write-Host "Docker Desktop installation completed successfully!"
        return $true
    }
    catch {
        Write-Error "Docker installation failed: $_"
        return $false
    }
}

function Get-DockerInfo {
    <#
    .SYNOPSIS
        Gets Docker installation information
    .OUTPUTS
        System.Hashtable
    #>
    try {
        $version = docker version --format "{{.Server.Version}}"
        $info = @{
            Installed = $true
            Version = $version
            DaemonRunning = Test-DockerDaemonRunning
        }
        return $info
    }
    catch {
        return @{
            Installed = $false
            Version = "Not Installed"
            DaemonRunning = $false
        }
    }
}

Export-ModuleMember -Function `
    Get-DockerDownloadUrl,
    Download-DockerInstaller,
    Install-DockerDesktop,
    Start-DockerDesktop,
    Wait-DockerDaemon,
    Test-DockerInstallation,
    Remove-DockerInstaller,
    Install-DockerComplete,
    Get-DockerInfo
