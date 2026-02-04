# Clemp Automatic Installation Script
# Orchestrates complete installation of dependencies and services

param(
    [switch]$SkipDocker = $false,
    [switch]$SkipNodeJs = $false,
    [switch]$SkipRust = $false,
    [switch]$SkipServices = $false,
    [switch]$SkipTauriCli = $false,
    [string]$TempDir = "$env:TEMP\clemp_install"
)

# Script configuration
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesDir = Join-Path $ScriptDir "modules"

# Import all modules
Import-Module (Join-Path $ModulesDir "prerequisites.psm1") -Force
Import-Module (Join-Path $ModulesDir "docker-installer.psm1") -Force
Import-Module (Join-Path $ModulesDir "nodejs-installer.psm1") -Force
Import-Module (Join-Path $ModulesDir "rust-installer.psm1") -Force
Import-Module (Join-Path $ModulesDir "services-manager.psm1") -Force
Import-Module (Join-Path $ModulesDir "health-checker.psm1") -Force

# Total steps calculation
$TotalSteps = 7
if ($SkipDocker) { $TotalSteps-- }
if ($SkipNodeJs) { $TotalSteps-- }
if ($SkipRust) { $TotalSteps-- }

# Progress tracking
$CurrentStep = 0

function Write-ProgressJson {
    <#
    .SYNOPSIS
        Emits progress in JSON format for Rust backend to capture
    #>
    param(
        [string]$Step,
        [uint32]$StepNumber,
        [uint32]$Total,
        [uint32]$PercentComplete,
        [string]$Status,
        [string]$Details,
        [string]$Error = $null
    )

    $progressObj = @{
        step = $Step
        step_number = $StepNumber
        total_steps = $Total
        percent_complete = $PercentComplete
        status = $Status
        details = $Details
        error = $Error
        timestamp = (Get-Date).ToString("o")
    }

    Write-Output "PROGRESS: $($progressObj | ConvertTo-Json -Compress)"
}

function Write-StepProgress {
    <#
    .SYNOPSIS
        Helper to write step progress with automatic step number tracking
    #>
    param(
        [string]$StepName,
        [string]$Status,
        [string]$Details,
        [string]$Error = $null
    )

    $script:CurrentStep++
    $percent = [math]::Round(($CurrentStep / $TotalSteps) * 100, 2)

    Write-ProgressJson -Step $StepName -StepNumber $CurrentStep -Total $TotalSteps -PercentComplete $percent -Status $Status -Details $Details -Error $Error
}

# ============================================================================
# INSTALLATION WORKFLOW
# ============================================================================

Write-Output "CLEMP_INSTALLATION_START"

try {
    # --------------------------------------------------------------------
    # Step 1: Check Prerequisites
    # --------------------------------------------------------------------
    Write-StepProgress -StepName "Checking Prerequisites" -Status "Running" -Details "Verifying system requirements..."

    $prereqs = Get-SystemInfo

    Write-StepProgress -StepName "Checking Prerequisites" -Status "Complete" -Details "Prerequisites checked"

    # --------------------------------------------------------------------
    # Step 2: Install Docker Desktop (if needed)
    # --------------------------------------------------------------------
    if (-not $SkipDocker) {
        if (-not $prereqs.DockerInstalled) {
            Write-StepProgress -StepName "Installing Docker Desktop" -Status "Running" -Details "Downloading and installing Docker Desktop..."

            $dockerInstalled = Install-DockerComplete -TempDir $TempDir

            if ($dockerInstalled) {
                Write-StepProgress -StepName "Installing Docker Desktop" -Status "Complete" -Details "Docker Desktop installed successfully"
            } else {
                Write-StepProgress -StepName "Installing Docker Desktop" -Status "Failed" -Details "Docker Desktop installation failed" -Error "Failed to install Docker Desktop"
                throw "Docker installation failed"
            }
        } else {
            Write-StepProgress -StepName "Installing Docker Desktop" -Status "Skipped" -Details "Docker Desktop already installed"
        }
    }

    # --------------------------------------------------------------------
    # Step 3: Install Node.js (if needed)
    # --------------------------------------------------------------------
    if (-not $SkipNodeJs) {
        if (-not $prereqs.NodeJsInstalled) {
            Write-StepProgress -StepName "Installing Node.js" -Status "Running" -Details "Downloading and installing Node.js..."

            $nodeJsInstalled = Install-NodeJsComplete -TempDir $TempDir

            if ($nodeJsInstalled) {
                Write-StepProgress -StepName "Installing Node.js" -Status "Complete" -Details "Node.js installed successfully"
            } else {
                Write-StepProgress -StepName "Installing Node.js" -Status "Failed" -Details "Node.js installation failed" -Error "Failed to install Node.js"
                throw "Node.js installation failed"
            }
        } else {
            Write-StepProgress -StepName "Installing Node.js" -Status "Skipped" -Details "Node.js already installed"
        }
    }

    # --------------------------------------------------------------------
    # Step 4: Install Rust (if needed)
    # --------------------------------------------------------------------
    if (-not $SkipRust) {
        if (-not $prereqs.RustInstalled) {
            Write-StepProgress -StepName "Installing Rust" -Status "Running" -Details "Downloading and installing Rust toolchain..."

            $rustInstalled = Install-RustComplete -TempDir $TempDir -InstallTauriCli:(-not $SkipTauriCli)

            if ($rustInstalled) {
                Write-StepProgress -StepName "Installing Rust" -Status "Complete" -Details "Rust installed successfully"
            } else {
                Write-StepProgress -StepName "Installing Rust" -Status "Failed" -Details "Rust installation failed" -Error "Failed to install Rust"
                throw "Rust installation failed"
            }
        } else {
            Write-StepProgress -StepName "Installing Rust" -Status "Skipped" -Details "Rust already installed"
        }
    }

    # --------------------------------------------------------------------
    # Step 5: Pull Docker Images
    # --------------------------------------------------------------------
    if (-not $SkipServices) {
        Write-StepProgress -StepName "Pulling Docker Images" -Status "Running" -Details "Downloading Docker images for services..."

        $composePath = Join-Path $ScriptDir "..\docker-compose.yml"

        if (Test-Path $composePath) {
            $imagesPulled = Invoke-DockerPull -ComposePath $composePath

            if ($imagesPulled) {
                Write-StepProgress -StepName "Pulling Docker Images" -Status "Complete" -Details "Docker images downloaded"
            } else {
                Write-StepProgress -StepName "Pulling Docker Images" -Status "Warning" -Details "Some images may not have been pulled" -Error "Failed to pull some images"
            }
        } else {
            Write-StepProgress -StepName "Pulling Docker Images" -Status "Skipped" -Details "docker-compose.yml not found"
        }
    }

    # --------------------------------------------------------------------
    # Step 6: Start Docker Services
    # --------------------------------------------------------------------
    if (-not $SkipServices) {
        Write-StepProgress -StepName "Starting Services" -Status "Running" -Details "Starting Docker services..."

        $composePath = Join-Path $ScriptDir "..\docker-compose.yml"

        if (Test-Path $composePath) {
            $servicesStarted = Start-DockerServices -ComposePath $composePath -Detached $true

            if ($servicesStarted) {
                Write-StepProgress -StepName "Starting Services" -Status "Complete" -Details "Docker services started"
            } else {
                Write-StepProgress -StepName "Starting Services" -Status "Failed" -Details "Failed to start services" -Error "Failed to start Docker services"
                throw "Failed to start services"
            }
        } else {
            Write-StepProgress -StepName "Starting Services" -Status "Skipped" -Details "docker-compose.yml not found"
        }
    }

    # --------------------------------------------------------------------
    # Step 7: Verify Service Health
    # --------------------------------------------------------------------
    if (-not $SkipServices) {
        Write-StepProgress -StepName "Verifying Services" -Status "Running" -Details "Checking service health..."

        # Wait a bit for services to be ready
        Start-Sleep -Seconds 10

        $health = Test-AllServicesHealth

        if ($health.AllHealthy) {
            Write-StepProgress -StepName "Verifying Services" -Status "Complete" -Details "All services are healthy"
        } else {
            $unhealthyServices = @()
            if (-not $health.Services.N8N.Healthy) { $unhealthyServices += "N8N" }
            if (-not $health.Services.Ollama.Healthy) { $unhealthyServices += "Ollama" }
            if (-not $health.Services.Qdrant.Healthy) { $unhealthyServices += "Qdrant" }
            if (-not $health.Services.PocketBase.Healthy) { $unhealthyServices += "PocketBase" }

            $errorMsg = "Unhealthy services: $($unhealthyServices -join ', ')"

            Write-StepProgress -StepName "Verifying Services" -Status "Warning" -Details "Some services are unhealthy" -Error $errorMsg
        }
    }

    # ====================================================================
    # INSTALLATION COMPLETE
    # ====================================================================

    Write-Output "CLEMP_INSTALLATION_COMPLETE"

    # Output final status as JSON
    $finalStatus = @{
        success = $true
        message = "Clemp installation completed successfully"
        prerequisites = $prereqs
        service_health = Test-AllServicesHealth
    }

    Write-Output ($finalStatus | ConvertTo-Json -Compress)

    exit 0
}
catch {
    Write-Output "CLEMP_INSTALLATION_FAILED"

    # Output error as JSON
    $errorStatus = @{
        success = $false
        message = "Installation failed: $_"
        error = $_.Exception.Message
        stack_trace = $_.ScriptStackTrace
    }

    Write-Output ($errorStatus | ConvertTo-Json -Compress)

    exit 1
}
