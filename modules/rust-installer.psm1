# Rust Installer Module for Clemp
# Handles silent installation of Rust toolchain and Tauri CLI

function Get-RustDownloadUrl {
    <#
    .SYNOPSIS
        Gets Rust download URL from config
    .OUTPUTS
        System.String
    #>
    $configPath = Join-Path $PSScriptRoot "..\config\versions.json"

    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    return $config.rust.download_url
}

function Get-RustVersion {
    <#
    .SYNOPSIS
        Gets Rust version from config
    .OUTPUTS
        System.String
    #>
    $configPath = Join-Path $PSScriptRoot "..\config\versions.json"

    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    return $config.rust.version
}

function Download-RustInstaller {
    <#
    .SYNOPSIS
        Downloads Rust rustup-init installer
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

    $url = Get-RustDownloadUrl
    $installerPath = Join-Path $OutputPath "rustup-init.exe"

    Write-Host "Downloading Rust rustup-init from: $url"
    Write-Host "Saving to: $installerPath"

    try {
        # Download using Invoke-WebRequest (more reliable than WebClient)
        Write-Host "Downloading Rust rustup-init..."
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $installerPath -UseBasicParsing -TimeoutSec 300
        $ProgressPreference = 'Continue'

        if (Test-Path $installerPath) {
            $fileSize = (Get-Item $installerPath).Length / 1MB
            Write-Host "Downloaded Rust installer ($([math]::Round($fileSize, 2)) MB)"
            return $installerPath
        } else {
            throw "Download failed - file not found"
        }
    }
    catch {
        throw "Failed to download Rust: $_"
    }
}

function Install-Rust {
    <#
    .SYNOPSIS
        Installs Rust silently using rustup-init
    .PARAMETER InstallerPath
        Path to rustup-init.exe
    .PARAMETER DefaultToolchain
        Default toolchain to install (default: stable)
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$InstallerPath,
        [string]$DefaultToolchain = "stable"
    )

    if (-not (Test-Path $InstallerPath)) {
        throw "Rust installer not found: $InstallerPath"
    }

    Write-Host "Installing Rust toolchain silently..."

    try {
        # Silent installation using rustup-init
        $process = Start-Process -FilePath $InstallerPath `
            -ArgumentList "-y", "--default-toolchain", $DefaultToolchain, "--profile", "default" `
            -Wait `
            -PassThru

        $exitCode = $process.ExitCode

        if ($exitCode -eq 0) {
            Write-Host "Rust installed successfully"

            # Refresh environment variables for current session
            Refresh-RustEnvironment

            return $true
        } else {
            Write-Error "Installation failed with exit code: $exitCode"
            return $false
        }
    }
    catch {
        Write-Error "Failed to install Rust: $_"
        return $false
    }
}

function Refresh-RustEnvironment {
    <#
    .SYNOPSIS
        Refreshes Rust environment variables for current session
    .OUTPUTS
        System.Boolean
    #>
    try {
        # Add cargo bin to PATH for current session
        $cargoPath = "$env:USERPROFILE\.cargo\bin"

        if ($env:Path -notlike "*$cargoPath*") {
            $env:Path = "$cargoPath;$env:Path"
        }

        # Test if rustc is available
        $null = rustc --version 2>&1

        Write-Host "Rust environment refreshed"
        return $true
    }
    catch {
        Write-Warning "Could not verify Rust installation: $_"
        return $false
    }
}

function Wait-RustInstallation {
    <#
    .SYNOPSIS
        Waits for Rust installation to complete and verify
    .PARAMETER TimeoutSeconds
        Maximum wait time in seconds
    .OUTPUTS
        System.Boolean
    #>
    param(
        [int]$TimeoutSeconds = 60
    )

    Write-Host "Verifying Rust installation..."

    $startTime = Get-Date
    $timeout = (New-TimeSpan -Seconds $TimeoutSeconds)

    do {
        Start-Sleep -Seconds 2

        try {
            $version = rustc --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Rust verified: $version"
                return $true
            }
        }
        catch {
            # Continue waiting
        }

        $elapsed = (Get-Date) - $startTime
        if ($elapsed -gt $timeout) {
            Write-Error "Timeout waiting for Rust installation"
            return $false
        }

        Write-Progress -Activity "Waiting for Rust" -Status "Installing" -PercentComplete (($elapsed.TotalSeconds / $TimeoutSeconds) * 100)
    } while ($true)
}

function Install-TauriCli {
    <#
    .SYNOPSIS
        Installs Tauri CLI via cargo
    .PARAMETER TimeoutSeconds
        Maximum wait time in seconds (default: 600 = 10 minutes)
    .OUTPUTS
        System.Boolean
    #>
    param(
        [int]$TimeoutSeconds = 600
    )

    Write-Host "Installing Tauri CLI (this may take 5-10 minutes)..."

    try {
        # Install Tauri CLI using cargo
        $process = Start-Process -FilePath "cargo" `
            -ArgumentList "install", "tauri-cli" `
            -Wait `
            -PassThru `
            -NoNewWindow

        $exitCode = $process.ExitCode

        if ($exitCode -eq 0) {
            Write-Host "Tauri CLI installed successfully"

            # Verify installation
            try {
                $version = cargo tauri --version 2>&1
                Write-Host "Tauri CLI version: $version"
                return $true
            }
            catch {
                Write-Warning "Tauri CLI installed but version check failed"
                return $true
            }
        } else {
            Write-Error "Tauri CLI installation failed with exit code: $exitCode"
            return $false
        }
    }
    catch {
        Write-Error "Failed to install Tauri CLI: $_"
        return $false
    }
}

function Remove-RustInstaller {
    <#
    .SYNOPSIS
        Removes Rust installer after installation
    .PARAMETER InstallerPath
        Path to installer to remove
    #>
    param(
        [string]$InstallerPath
    )

    if (Test-Path $InstallerPath) {
        Remove-Item -Path $InstallerPath -Force
        Write-Host "Cleaned up Rust installer"
    }
}

function Install-RustComplete {
    <#
    .SYNOPSIS
        Complete Rust installation workflow: download, install, Tauri CLI
    .PARAMETER TempDir
        Temporary directory for downloads
    .PARAMETER InstallTauriCli
        Whether to install Tauri CLI (default: true)
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$TempDir = "$env:TEMP\clemp_install",
        [bool]$InstallTauriCli = $true
    )

    try {
        # Step 1: Download
        $installerPath = Download-RustInstaller -OutputPath $TempDir

        # Step 2: Install Rust
        $installed = Install-Rust -InstallerPath $installerPath
        if (-not $installed) {
            return $false
        }

        # Step 3: Verify installation
        $verified = Wait-RustInstallation -TimeoutSeconds 60
        if (-not $verified) {
            return $false
        }

        # Step 4: Install Tauri CLI (optional)
        if ($InstallTauriCli) {
            $tauriInstalled = Install-TauriCli -TimeoutSeconds 600
            if (-not $tauriInstalled) {
                Write-Warning "Tauri CLI installation failed, but Rust is installed"
                # Don't return false, as Rust itself is installed
            }
        }

        # Step 5: Cleanup
        Remove-RustInstaller -InstallerPath $installerPath

        Write-Host "Rust installation completed successfully!"
        return $true
    }
    catch {
        Write-Error "Rust installation failed: $_"
        return $false
    }
}

function Get-RustInfo {
    <#
    .SYNOPSIS
        Gets Rust installation information
    .OUTPUTS
        System.Hashtable
    #>
    try {
        $rustcVersion = rustc --version
        $cargoVersion = cargo --version

        # Check if Tauri CLI is installed
        $tauriInstalled = $false
        $tauriVersion = "Not Installed"

        try {
            $tauriVersion = cargo tauri --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                $tauriInstalled = $true
            }
        }
        catch {
            # Tauri CLI not installed
        }

        $info = @{
            Installed = $true
            RustcVersion = $rustcVersion
            CargoVersion = $cargoVersion
            TauriCliInstalled = $tauriInstalled
            TauriVersion = $tauriVersion
            Path = Get-Command "rustc" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        }
        return $info
    }
    catch {
        return @{
            Installed = $false
            RustcVersion = "Not Installed"
            CargoVersion = "Not Installed"
            TauriCliInstalled = $false
            TauriVersion = "Not Installed"
            Path = $null
        }
    }
}

Export-ModuleMember -Function `
    Get-RustDownloadUrl,
    Get-RustVersion,
    Download-RustInstaller,
    Install-Rust,
    Refresh-RustEnvironment,
    Wait-RustInstallation,
    Install-TauriCli,
    Remove-RustInstaller,
    Install-RustComplete,
    Get-RustInfo
