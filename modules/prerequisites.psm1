# Prerequisites Checker Module for Clemp Installation
# Provides functions to check system prerequisites before installation

function Test-DockerInstalled {
    <#
    .SYNOPSIS
        Checks if Docker Desktop is installed
    .OUTPUTS
        System.Boolean
    #>
    $dockerPath = Get-Command "docker" -ErrorAction SilentlyContinue
    return -not ($null -eq $dockerPath)
}

function Get-DockerVersion {
    <#
    .SYNOPSIS
        Gets Docker Desktop version
    .OUTPUTS
        System.String
    #>
    try {
        $version = docker --version
        return $version
    }
    catch {
        return "Not Installed"
    }
}

function Test-DockerDaemonRunning {
    <#
    .SYNOPSIS
        Checks if Docker daemon is running
    .OUTPUTS
        System.Boolean
    #>
    try {
        $result = docker ps 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Test-NodeJsInstalled {
    <#
    .SYNOPSIS
        Checks if Node.js is installed
    .OUTPUTS
        System.Boolean
    #>
    $nodePath = Get-Command "node" -ErrorAction SilentlyContinue
    return -not ($null -eq $nodePath)
}

function Get-NodeJsVersion {
    <#
    .SYNOPSIS
        Gets Node.js version
    .OUTPUTS
        System.String
    #>
    try {
        $version = node --version
        return $version
    }
    catch {
        return "Not Installed"
    }
}

function Test-RustInstalled {
    <#
    .SYNOPSIS
        Checks if Rust toolchain is installed
    .OUTPUTS
        System.Boolean
    #>
    $rustcPath = Get-Command "rustc" -ErrorAction SilentlyContinue
    return -not ($null -eq $rustcPath)
}

function Get-RustVersion {
    <#
    .SYNOPSIS
        Gets Rust compiler version
    .OUTPUTS
        System.String
    #>
    try {
        $version = rustc --version
        return $version
    }
    catch {
        return "Not Installed"
    }
}

function Test-TauriCliInstalled {
    <#
    .SYNOPSIS
        Checks if Tauri CLI is installed
    .OUTPUTS
        System.Boolean
    #>
    try {
        $version = cargo tauri --version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Test-InternetConnection {
    <#
    .SYNOPSIS
        Tests internet connectivity
    .OUTPUTS
        System.Boolean
    #>
    try {
        $testUrls = @(
            "https://www.google.com",
            "https://www.github.com",
            "https://docker.com"
        )

        foreach ($url in $testUrls) {
            try {
                $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
                return $true
            }
            catch {
                continue
            }
        }
        return $false
    }
    catch {
        return $false
    }
}

function Test-DiskSpace {
    <#
    .SYNOPSIS
        Checks if sufficient disk space is available
    .OUTPUTS
        System.Boolean
    .PARAMETER RequiredGB
        Required disk space in GB
    #>
    param(
        [int]$RequiredGB = 10
    )

    try {
        $drive = $env:SystemDrive
        $driveInfo = Get-PSDrive $drive -ErrorAction Stop

        $freeGB = [math]::Round($driveInfo.Free / 1GB, 2)
        return $freeGB -ge $RequiredGB
    }
    catch {
        return $false
    }
}

function Get-DiskSpaceInfo {
    <#
    .SYNOPSIS
        Gets available disk space information
    .OUTPUTS
        System.Hashtable
    #>
    try {
        $drive = $env:SystemDrive
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$drive'" -ErrorAction Stop

        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $totalGB = [math]::Round($disk.Size / 1GB, 2)
        $usedGB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)

        return @{
            Drive = $drive
            FreeGB = $freeGB
            UsedGB = $usedGB
            TotalGB = $totalGB
        }
    }
    catch {
        return @{
            Drive = "C:"
            FreeGB = 0
            UsedGB = 0
            TotalGB = 0
        }
    }
}

function Get-SystemInfo {
    <#
    .SYNOPSIS
        Gets comprehensive system information for Clemp installation
    .OUTPUTS
        System.Hashtable
    #>
    $configPath = Join-Path $PSScriptRoot "..\config\versions.json"

    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
    } else {
        $config = @{}
    }

    return @{
        DockerInstalled = Test-DockerInstalled
        DockerVersion = Get-DockerVersion
        DockerRunning = Test-DockerDaemonRunning
        NodeJsInstalled = Test-NodeJsInstalled
        NodeJsVersion = Get-NodeJsVersion
        RustInstalled = Test-RustInstalled
        RustVersion = Get-RustVersion
        TauriCliInstalled = Test-TauriCliInstalled
        InternetConnected = Test-InternetConnection
        DiskSpace = Get-DiskSpaceInfo
        OSVersion = [System.Environment]::OSVersion.VersionString
        Is64Bit = [Environment]::Is64BitOperatingSystem
        AvailableRAMGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    }
}

function Write-PrerequisiteCheck {
    <#
    .SYNOPSIS
        Outputs prerequisite check result as JSON for Rust backend
    #>
    param(
        [hashtable]$CheckResult
    )

    $checkResult | ConvertTo-Json -Compress | Write-Output
}

function Test-AllPrerequisites {
    <#
    .SYNOPSIS
        Runs all prerequisite checks and returns structured data
    .OUTPUTS
        System.Void
    #>
    $info = Get-SystemInfo
    Write-PrerequisiteCheck -CheckResult $info
}

function Test-ClempReady {
    <#
    .SYNOPSIS
        Checks if system is ready for Clemp installation
    .OUTPUTS
        System.Boolean
    #>
    $info = Get-SystemInfo

    # All prerequisites must be met
    return $info.DockerInstalled -and
           $info.NodeJsInstalled -and
           $info.RustInstalled -and
           $info.InternetConnected -and
           ($info.DiskSpace.FreeGB -ge 10)
}

Export-ModuleMember -Function `
    Test-DockerInstalled,
    Get-DockerVersion,
    Test-DockerDaemonRunning,
    Test-NodeJsInstalled,
    Get-NodeJsVersion,
    Test-RustInstalled,
    Get-RustVersion,
    Test-TauriCliInstalled,
    Test-InternetConnection,
    Test-DiskSpace,
    Get-DiskSpaceInfo,
    Get-SystemInfo,
    Write-PrerequisiteCheck,
    Test-AllPrerequisites,
    Test-ClempReady
