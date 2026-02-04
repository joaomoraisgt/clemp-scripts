# Services Manager Module for Clemp
# Manages Docker Compose services (N8N, Ollama, Qdrant, PocketBase)

function Get-DockerComposePath {
    <#
    .SYNOPSIS
        Gets path to docker-compose.yml file
    .OUTPUTS
        System.String
    #>
    $composePath = Join-Path $PSScriptRoot "..\..\docker-compose.yml"

    if (-not (Test-Path $composePath)) {
        throw "Docker Compose file not found: $composePath"
    }

    return $composePath
}

function Test-DockerComposeAvailable {
    <#
    .SYNOPSIS
        Tests if Docker Compose is available
    .OUTPUTS
        System.Boolean
    #>
    try {
        $null = docker compose version 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Invoke-DockerPull {
    <#
    .SYNOPSIS
        Pulls all Docker images defined in docker-compose.yml
    .PARAMETER ComposePath
        Path to docker-compose.yml file
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$ComposePath
    )

    if (-not $ComposePath) {
        $ComposePath = Get-DockerComposePath
    }

    if (-not (Test-Path $ComposePath)) {
        throw "Docker Compose file not found: $ComposePath"
    }

    Write-Host "Pulling Docker images..."

    try {
        $composeDir = Split-Path -Parent $ComposePath

        $process = Start-Process -FilePath "docker" `
            -ArgumentList "compose", "-f", $ComposePath, "pull" `
            -WorkingDirectory $composeDir `
            -Wait `
            -PassThru `
            -NoNewWindow

        $exitCode = $process.ExitCode

        if ($exitCode -eq 0) {
            Write-Host "Docker images pulled successfully"
            return $true
        } else {
            Write-Error "Failed to pull images with exit code: $exitCode"
            return $false
        }
    }
    catch {
        Write-Error "Failed to pull Docker images: $_"
        return $false
    }
}

function Start-DockerServices {
    <#
    .SYNOPSIS
        Starts all Docker services using docker-compose up
    .PARAMETER ComposePath
        Path to docker-compose.yml file
    .PARAMETER Detached
        Run in detached mode (background)
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$ComposePath,
        [bool]$Detached = $true
    )

    if (-not $ComposePath) {
        $ComposePath = Get-DockerComposePath
    }

    if (-not (Test-Path $ComposePath)) {
        throw "Docker Compose file not found: $ComposePath"
    }

    Write-Host "Starting Docker services..."

    try {
        $composeDir = Split-Path -Parent $ComposePath

        $args = @("compose", "-f", $ComposePath, "up")

        if ($Detached) {
            $args += "-d"
        }

        $process = Start-Process -FilePath "docker" `
            -ArgumentList $args `
            -WorkingDirectory $composeDir `
            -Wait `
            -PassThru `
            -NoNewWindow

        $exitCode = $process.ExitCode

        if ($exitCode -eq 0) {
            Write-Host "Docker services started successfully"
            return $true
        } else {
            Write-Error "Failed to start services with exit code: $exitCode"
            return $false
        }
    }
    catch {
        Write-Error "Failed to start Docker services: $_"
        return $false
    }
}

function Stop-DockerServices {
    <#
    .SYNOPSIS
        Stops all Docker services using docker-compose down
    .PARAMETER ComposePath
        Path to docker-compose.yml file
    .PARAMETER RemoveVolumes
        Remove named volumes
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$ComposePath,
        [bool]$RemoveVolumes = $false
    )

    if (-not $ComposePath) {
        $ComposePath = Get-DockerComposePath
    }

    if (-not (Test-Path $ComposePath)) {
        throw "Docker Compose file not found: $ComposePath"
    }

    Write-Host "Stopping Docker services..."

    try {
        $composeDir = Split-Path -Parent $ComposePath

        $args = @("compose", "-f", $ComposePath, "down")

        if ($RemoveVolumes) {
            $args += "-v"
        }

        $process = Start-Process -FilePath "docker" `
            -ArgumentList $args `
            -WorkingDirectory $composeDir `
            -Wait `
            -PassThru `
            -NoNewWindow

        $exitCode = $process.ExitCode

        if ($exitCode -eq 0) {
            Write-Host "Docker services stopped successfully"
            return $true
        } else {
            Write-Error "Failed to stop services with exit code: $exitCode"
            return $false
        }
    }
    catch {
        Write-Error "Failed to stop Docker services: $_"
        return $false
    }
}

function Restart-DockerServices {
    <#
    .SYNOPSIS
        Restarts all Docker services
    .PARAMETER ComposePath
        Path to docker-compose.yml file
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$ComposePath
    )

    Write-Host "Restarting Docker services..."

    $stopped = Stop-DockerServices -ComposePath $ComposePath
    if (-not $stopped) {
        return $false
    }

    Start-Sleep -Seconds 2

    $started = Start-DockerServices -ComposePath $ComposePath
    return $started
}

function Get-DockerServicesStatus {
    <#
    .SYNOPSIS
        Gets status of all Docker containers managed by docker-compose
    .PARAMETER ComposePath
        Path to docker-compose.yml file
    .OUTPUTS
        System.Array
    #>
    param(
        [string]$ComposePath
    )

    if (-not $ComposePath) {
        $ComposePath = Get-DockerComposePath
    }

    if (-not (Test-Path $ComposePath)) {
        throw "Docker Compose file not found: $ComposePath"
    }

    try {
        $composeDir = Split-Path -Parent $ComposePath

        # Get container status using docker compose ps
        $output = docker compose -f $ComposePath ps --format json 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to get services status"
            return @()
        }

        # Parse JSON output
        $containers = $output | ConvertFrom-Json

        $services = @()

        foreach ($container in $containers) {
            $serviceInfo = @{
                Name = $container.Name
                Service = $container.Service
                State = $container.State
                Health = $container.Health
                Ports = $container.Ports
            }
            $services += $serviceInfo
        }

        return $services
    }
    catch {
        Write-Error "Failed to get services status: $_"
        return @()
    }
}

function Get-DockerServiceLogs {
    <#
    .SYNOPSIS
        Gets logs from Docker services
    .PARAMETER ComposePath
        Path to docker-compose.yml file
    .PARAMETER Service
        Service name (empty = all services)
    .PARAMETER Tail
        Number of lines from end of logs
    .OUTPUTS
        System.String
    #>
    param(
        [string]$ComposePath,
        [string]$Service = "",
        [int]$Tail = 50
    )

    if (-not $ComposePath) {
        $ComposePath = Get-DockerComposePath
    }

    if (-not (Test-Path $ComposePath)) {
        throw "Docker Compose file not found: $ComposePath"
    }

    try {
        $composeDir = Split-Path -Parent $ComposePath

        $args = @("compose", "-f", $ComposePath, "logs", "--tail", $Tail)

        if ($Service) {
            $args += $Service
        }

        $output = docker $args 2>&1
        return $output
    }
    catch {
        Write-Error "Failed to get logs: $_"
        return ""
    }
}

function Test-DockerServicesRunning {
    <#
    .SYNOPSIS
        Tests if all Docker services are running
    .PARAMETER ComposePath
        Path to docker-compose.yml file
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$ComposePath
    )

    try {
        $services = Get-DockerServicesStatus -ComposePath $ComposePath

        # Check if we have the expected number of services
        $expectedServices = 4  # N8N, Ollama, Qdrant, PocketBase

        if ($services.Count -lt $expectedServices) {
            return $false
        }

        # Check if all services are running
        foreach ($service in $services) {
            if ($service.State -notlike "running*") {
                return $false
            }
        }

        return $true
    }
    catch {
        return $false
    }
}

function Get-DockerServicesInfo {
    <#
    .SYNOPSIS
        Gets comprehensive information about Docker services
    .PARAMETER ComposePath
        Path to docker-compose.yml file
    .OUTPUTS
        System.Hashtable
    #>
    param(
        [string]$ComposePath
    )

    try {
        $services = Get-DockerServicesStatus -ComposePath $ComposePath
        $allRunning = Test-DockerServicesRunning -ComposePath $ComposePath

        # Get individual service info
        $n8n = $services | Where-Object { $_.Service -like "*n8n*" }
        $ollama = $services | Where-Object { $_.Service -like "*ollama*" }
        $qdrant = $services | Where-Object { $_.Service -like "*qdrant*" }
        $pocketbase = $services | Where-Object { $_.Service -like "*pocketbase*" }

        $info = @{
            AllRunning = $allRunning
            TotalServices = $services.Count
            Services = @{
                N8N = @{
                    Running = -not ($null -eq $n8n) -and ($n8n.State -like "running*")
                    Name = if ($n8n) { $n8n.Name } else { $null }
                    State = if ($n8n) { $n8n.State } else { "Not running" }
                    Port = "5678"
                }
                Ollama = @{
                    Running = -not ($null -eq $ollama) -and ($ollama.State -like "running*")
                    Name = if ($ollama) { $ollama.Name } else { $null }
                    State = if ($ollama) { $ollama.State } else { "Not running" }
                    Port = "11434"
                }
                Qdrant = @{
                    Running = -not ($null -eq $qdrant) -and ($qdrant.State -like "running*")
                    Name = if ($qdrant) { $qdrant.Name } else { $null }
                    State = if ($qdrant) { $qdrant.State } else { "Not running" }
                    Port = "6333"
                }
                PocketBase = @{
                    Running = -not ($null -eq $pocketbase) -and ($pocketbase.State -like "running*")
                    Name = if ($pocketbase) { $pocketbase.Name } else { $null }
                    State = if ($pocketbase) { $pocketbase.State } else { "Not running" }
                    Port = "8090"
                }
            }
        }

        return $info
    }
    catch {
        Write-Error "Failed to get services info: $_"
        return @{
            AllRunning = $false
            TotalServices = 0
            Services = $null
        }
    }
}

function Start-DockerServicesComplete {
    <#
    .SYNOPSIS
        Complete workflow: pull images and start services
    .PARAMETER ComposePath
        Path to docker-compose.yml file
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$ComposePath
    )

    try {
        # Step 1: Pull images
        $pulled = Invoke-DockerPull -ComposePath $ComposePath
        if (-not $pulled) {
            Write-Warning "Failed to pull some images, continuing anyway..."
        }

        # Step 2: Start services
        $started = Start-DockerServices -ComposePath $ComposePath -Detached $true
        if (-not $started) {
            return $false
        }

        # Step 3: Wait a bit for services to initialize
        Start-Sleep -Seconds 5

        # Step 4: Verify
        $running = Test-DockerServicesRunning -ComposePath $ComposePath

        if ($running) {
            Write-Host "All Docker services started successfully!"
            return $true
        } else {
            Write-Warning "Some services may not be running properly"
            return $false
        }
    }
    catch {
        Write-Error "Failed to start Docker services: $_"
        return $false
    }
}

Export-ModuleMember -Function `
    Get-DockerComposePath,
    Test-DockerComposeAvailable,
    Invoke-DockerPull,
    Start-DockerServices,
    Stop-DockerServices,
    Restart-DockerServices,
    Get-DockerServicesStatus,
    Get-DockerServiceLogs,
    Test-DockerServicesRunning,
    Get-DockerServicesInfo,
    Start-DockerServicesComplete
