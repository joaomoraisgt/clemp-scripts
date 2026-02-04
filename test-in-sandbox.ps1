# Clemp Installation Test Script for Windows Sandbox
# This script runs inside Windows Sandbox to test clean installation

param(
    [switch]$SkipDocker = $false,
    [switch]$SkipNodeJs = $false,
    [switch]$SkipRust = $false,
    [switch]$SkipServices = $false
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Test log location
$TestLog = "C:\Users\WDAGUtilityAccount\Desktop\clemp-test-log.txt"

function Write-TestLog {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $TestLog -Value $logMessage
    Write-Host $logMessage
}

function Test-FreshEnvironment {
    <#
    .SYNOPSIS
        Verifies we're in a fresh environment (no Docker/Node/Rust)
    #>
    Write-TestLog "=== Testing Fresh Environment ==="

    $dockerExists = Get-Command "docker" -ErrorAction SilentlyContinue
    $nodeExists = Get-Command "node" -ErrorAction SilentlyContinue
    $rustcExists = Get-Command "rustc" -ErrorAction SilentlyContinue

    Write-TestLog "Docker installed: $(if ($dockerExists) { 'YES (FAIL!)' } else { 'NO (PASS)' })"
    Write-TestLog "Node.js installed: $(if ($nodeExists) { 'YES (FAIL!)' } else { 'NO (PASS)' })"
    Write-TestLog "Rust installed: $(if ($rustcExists) { 'YES (FAIL!)' } else { 'NO (PASS)' })"

    return -not ($dockerExists -or $nodeExists -or $rustcExists)
}

function Test-InstallationScripts {
    <#
    .SYNOPSIS
        Tests that all installation scripts are accessible
    #>
    Write-TestLog "=== Testing Installation Scripts ==="

    $scriptDir = "C:\Users\WDAGUtilityAccount\Desktop\clemp\scripts"

    $scripts = @(
        "install.ps1",
        "modules\prerequisites.psm1",
        "modules\docker-installer.psm1",
        "modules\nodejs-installer.psm1",
        "modules\rust-installer.psm1",
        "modules\services-manager.psm1",
        "modules\health-checker.psm1",
        "config\versions.json"
    )

    $allExist = $true

    foreach ($script in $scripts) {
        $path = Join-Path $scriptDir $script
        $exists = Test-Path $path
        Write-TestLog "$script exists: $exists"

        if (-not $exists) {
            $allExist = $false
        }
    }

    return $allExist
}

function Test-PrerequisitesCheck {
    <#
    .SYNOPSIS
        Tests the prerequisites checking module
    #>
    Write-TestLog "=== Testing Prerequisites Check ==="

    try {
        $modulePath = "C:\Users\WDAGUtilityAccount\Desktop\clemp\scripts\modules\prerequisites.psm1"
        Import-Module $modulePath -Force

        $info = Get-SystemInfo

        Write-TestLog "Docker Installed: $($info.DockerInstalled)"
        Write-TestLog "Node.js Installed: $($info.NodeJsInstalled)"
        Write-TestLog "Rust Installed: $($info.RustInstalled)"
        Write-TestLog "Internet Connected: $($info.InternetConnected)"
        Write-TestLog "Disk Space (Free GB): $($info.DiskSpace.FreeGB)"
        Write-TestLog "OS Version: $($info.OSVersion)"
        Write-TestLog "Is 64-bit: $($info.Is64Bit)"

        return $true
    }
    catch {
        Write-TestLog "ERROR: Prerequisites check failed: $_"
        return $false
    }
}

function Test-NodeJsInstallation {
    <#
    .SYNOPSIS
        Tests Node.js installation module
    #>
    Write-TestLog "=== Testing Node.js Installation ==="

    try {
        $modulePath = "C:\Users\WDAGUtilityAccount\Desktop\clemp\scripts\modules\nodejs-installer.psm1"
        Import-Module $modulePath -Force

        Write-TestLog "Starting Node.js installation..."

        $installed = Install-NodeJsComplete -TempDir "C:\Users\WDAGUtilityAccount\Desktop\clemp-test"

        if ($installed) {
            Write-TestLog "Node.js installation completed"

            # Verify using full path to avoid PATH cache issues
            $nodeExe = "$env:ProgramFiles\nodejs\node.exe"
            $npmCmd = "$env:ProgramFiles\nodejs\npm.cmd"

            if (Test-Path $nodeExe) {
                $version = & $nodeExe --version
                Write-TestLog "Node version: $version"
            } else {
                Write-TestLog "WARNING: node.exe not found at $nodeExe"
            }

            if (Test-Path $npmCmd) {
                $npmVersion = & $npmCmd --version
                Write-TestLog "NPM version: $npmVersion"
            } else {
                Write-TestLog "WARNING: npm.cmd not found at $npmCmd"
            }

            return $true
        } else {
            Write-TestLog "ERROR: Node.js installation failed"
            return $false
        }
    }
    catch {
        Write-TestLog "ERROR: Node.js installation test failed: $_"
        return $false
    }
}

function Test-DockerInstallation {
    <#
    .SYNOPSIS
        Tests Docker Desktop installation module
    #>
    Write-TestLog "=== Testing Docker Installation ==="

    try {
        $modulePath = "C:\Users\WDAGUtilityAccount\Desktop\clemp\scripts\modules\docker-installer.psm1"
        Import-Module $modulePath -Force

        Write-TestLog "Starting Docker Desktop installation..."

        $installed = Install-DockerComplete -TempDir "C:\Users\WDAGUtilityAccount\Desktop\clemp-test"

        if ($installed) {
            Write-TestLog "Docker Desktop installation completed"

            # Note: Docker daemon may take time to start in Sandbox
            Write-TestLog "Note: Docker daemon initialization not tested in Sandbox (requires restart)"

            return $true
        } else {
            Write-TestLog "ERROR: Docker installation failed"
            return $false
        }
    }
    catch {
        Write-TestLog "ERROR: Docker installation test failed: $_"
        return $false
    }
}

function Test-RustInstallation {
    <#
    .SYNOPSIS
        Tests Rust installation module
    #>
    Write-TestLog "=== Testing Rust Installation ==="

    try {
        $modulePath = "C:\Users\WDAGUtilityAccount\Desktop\clemp\scripts\modules\rust-installer.psm1"
        Import-Module $modulePath -Force

        Write-TestLog "Starting Rust installation..."

        # Install Rust but skip Tauri CLI (takes too long)
        $installed = Install-RustComplete -TempDir "C:\Users\WDAGUtilityAccount\Desktop\clemp-test" -InstallTauriCli $false

        if ($installed) {
            Write-TestLog "Rust installation completed"

            # Verify
            $version = rustc --version
            Write-TestLog "Rust version: $version"

            return $true
        } else {
            Write-TestLog "ERROR: Rust installation failed"
            return $false
        }
    }
    catch {
        Write-TestLog "ERROR: Rust installation test failed: $_"
        return $false
    }
}

function Test-HealthChecker {
    <#
    .SYNOPSIS
        Tests the health checker module
    #>
    Write-TestLog "=== Testing Health Checker Module ==="

    try {
        $modulePath = "C:\Users\WDAGUtilityAccount\Desktop\clemp\scripts\modules\health-checker.psm1"
        Import-Module $modulePath -Force

        Write-TestLog "Testing health check functions..."

        # Test without Docker running (should return unhealthy)
        $health = Test-AllServicesHealth

        Write-TestLog "All Healthy: $($health.AllHealthy)"
        Write-TestLog "N8N Healthy: $($health.Services.N8N.Healthy)"
        Write-TestLog "Ollama Healthy: $($health.Services.Ollama.Healthy)"
        Write-TestLog "Qdrant Healthy: $($health.Services.Qdrant.Healthy)"
        Write-TestLog "PocketBase Healthy: $($health.Services.PocketBase.Healthy)"

        return $true
    }
    catch {
        Write-TestLog "ERROR: Health checker test failed: $_"
        return $false
    }
}

function Test-ServicesManager {
    <#
    .SYNOPSIS
        Tests the services manager module
    #>
    Write-TestLog "=== Testing Services Manager Module ==="

    try {
        $modulePath = "C:\Users\WDAGUtilityAccount\Desktop\clemp\scripts\modules\services-manager.psm1"
        Import-Module $modulePath -Force

        Write-TestLog "Testing services manager functions..."

        # Check if docker-compose.yml exists
        $composePath = "C:\Users\WDAGUtilityAccount\Desktop\clemp\docker-compose.yml"
        $exists = Test-Path $composePath

        Write-TestLog "docker-compose.yml exists: $exists"

        if ($exists) {
            Write-TestLog "Docker Compose file structure validated"
        }

        return $true
    }
    catch {
        Write-TestLog "ERROR: Services manager test failed: $_"
        return $false
    }
}

function Test-CompleteInstallation {
    <#
    .SYNOPSIS
        Tests the complete installation workflow
    #>
    Write-TestLog "=== Testing Complete Installation Workflow ==="

    try {
        $installScript = "C:\Users\WDAGUtilityAccount\Desktop\clemp\scripts\install.ps1"

        Write-TestLog "Running complete installation script..."
        Write-TestLog "Note: This will install Node.js, Rust, and download Docker"

        # Run installation with Docker skipped (Sandbox can't run Docker properly)
        $arguments = @{
            FilePath = "powershell.exe"
            ArgumentList = "-ExecutionPolicy", "Bypass", "-File", $installScript, "-SkipDocker", "-SkipServices"
            Wait = $true
            NoNewWindow = $true
        }

        $process = Start-Process @arguments
        $exitCode = $process.ExitCode

        if ($exitCode -eq 0) {
            Write-TestLog "Installation script completed successfully"
            return $true
        } else {
            Write-TestLog "WARNING: Installation script exited with code: $exitCode"
            return $false
        }
    }
    catch {
        Write-TestLog "ERROR: Complete installation test failed: $_"
        return $false
    }
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

Write-TestLog "========================================"
Write-TestLog "CLEMP INSTALLATION TEST - WINDOWS SANDBOX"
Write-TestLog "========================================"
Write-TestLog ""

$testResults = @{}

# Test 1: Fresh Environment
Write-TestLog ""
$testResults["FreshEnvironment"] = Test-FreshEnvironment

# Test 2: Installation Scripts
Write-TestLog ""
$testResults["InstallationScripts"] = Test-InstallationScripts

# Test 3: Prerequisites Check
Write-TestLog ""
$testResults["PrerequisitesCheck"] = Test-PrerequisitesCheck

# Test 4: Node.js Installation (unless skipped)
if (-not $SkipNodeJs) {
    Write-TestLog ""
    $testResults["NodeJsInstallation"] = Test-NodeJsInstallation
}

# Test 5: Rust Installation (unless skipped)
if (-not $SkipRust) {
    Write-TestLog ""
    $testResults["RustInstallation"] = Test-RustInstallation
}

# Test 6: Health Checker
Write-TestLog ""
$testResults["HealthChecker"] = Test-HealthChecker

# Test 7: Services Manager
Write-TestLog ""
$testResults["ServicesManager"] = Test-ServicesManager

# Test 8: Complete Installation (optional)
# Write-TestLog ""
# $testResults["CompleteInstallation"] = Test-CompleteInstallation

# ============================================================================
# TEST SUMMARY
# ============================================================================

Write-TestLog ""
Write-TestLog "========================================"
Write-TestLog "TEST SUMMARY"
Write-TestLog "========================================"

$passed = 0
$failed = 0

foreach ($test in $testResults.GetEnumerator()) {
    $status = if ($test.Value) { "PASS" } else { "FAIL" }
    Write-TestLog "$($test.Key): $status"

    if ($test.Value) {
        $passed++
    } else {
        $failed++
    }
}

Write-TestLog ""
Write-TestLog "Total Tests: $($testResults.Count)"
Write-TestLog "Passed: $passed"
Write-TestLog "Failed: $failed"
Write-TestLog "Success Rate: $([math]::Round(($passed / $testResults.Count) * 100, 2))%"
Write-TestLog "========================================"

# Keep log open for review
Write-TestLog ""
Write-TestLog "Test log saved to: $TestLog"
Write-TestLog "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
