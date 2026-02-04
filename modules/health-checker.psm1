# Health Checker Module for Clemp
# Tests health status of all Docker services

function Test-HttpEndpoint {
    <#
    .SYNOPSIS
        Tests HTTP endpoint availability
    .PARAMETER Url
        URL to test
    .PARAMETER TimeoutSeconds
        Request timeout
    .OUTPUTS
        System.Boolean
    #>
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 10
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
        return $response.StatusCode -eq 200
    }
    catch {
        return $false
    }
}

function Test-N8NHealth {
    <#
    .SYNOPSIS
        Tests N8N service health
    .PARAMETER Port
        N8N port (default: 5678)
    .OUTPUTS
        System.Hashtable
    #>
    param(
        [int]$Port = 5678
    )

    $url = "http://localhost:${Port}/healthz"

    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop

        return @{
            Healthy = $response.StatusCode -eq 200
            StatusCode = $response.StatusCode
            Url = $url
            Error = $null
        }
    }
    catch {
        return @{
            Healthy = $false
            StatusCode = 0
            Url = $url
            Error = $_.Exception.Message
        }
    }
}

function Test-OllamaHealth {
    <#
    .SYNOPSIS
        Tests Ollama service health
    .PARAMETER Port
        Ollama port (default: 11434)
    .OUTPUTS
        System.Hashtable
    #>
    param(
        [int]$Port = 11434
    )

    $url = "http://localhost:${Port}/api/tags"

    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop

        return @{
            Healthy = $response.StatusCode -eq 200
            StatusCode = $response.StatusCode
            Url = $url
            Error = $null
        }
    }
    catch {
        return @{
            Healthy = $false
            StatusCode = 0
            Url = $url
            Error = $_.Exception.Message
        }
    }
}

function Test-QdrantHealth {
    <#
    .SYNOPSIS
        Tests Qdrant service health
    .PARAMETER Port
        Qdrant port (default: 6333)
    .OUTPUTS
        System.Hashtable
    #>
    param(
        [int]$Port = 6333
    )

    $url = "http://localhost:${Port}/health"

    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop

        return @{
            Healthy = $response.StatusCode -eq 200
            StatusCode = $response.StatusCode
            Url = $url
            Error = $null
        }
    }
    catch {
        return @{
            Healthy = $false
            StatusCode = 0
            Url = $url
            Error = $_.Exception.Message
        }
    }
}

function Test-PocketBaseHealth {
    <#
    .SYNOPSIS
        Tests PocketBase service health
    .PARAMETER Port
        PocketBase port (default: 8090)
    .OUTPUTS
        System.Hashtable
    #>
    param(
        [int]$Port = 8090
    )

    $url = "http://localhost:${Port}/api/health"

    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop

        return @{
            Healthy = $response.StatusCode -eq 200
            StatusCode = $response.StatusCode
            Url = $url
            Error = $null
        }
    }
    catch {
        return @{
            Healthy = $false
            StatusCode = 0
            Url = $url
            Error = $_.Exception.Message
        }
    }
}

function Test-AllServicesHealth {
    <#
    .SYNOPSIS
        Tests health of all Clemp services
    .OUTPUTS
        System.Hashtable
    #>
    $n8n = Test-N8NHealth
    $ollama = Test-OllamaHealth
    $qdrant = Test-QdrantHealth
    $pocketbase = Test-PocketBaseHealth

    $allHealthy = $n8n.Healthy -and $ollama.Healthy -and $qdrant.Healthy -and $pocketbase.Healthy

    return @{
        AllHealthy = $allHealthy
        Services = @{
            N8N = $n8n
            Ollama = $ollama
            Qdrant = $qdrant
            PocketBase = $pocketbase
        }
    }
}

function Get-ServiceHealthReport {
    <#
    .SYNOPSIS
        Gets a formatted health report for all services
    .OUTPUTS
        System.String
    #>
    $health = Test-AllServicesHealth

    $report = [System.Text.StringBuilder]::new()
    [void]$report.AppendLine("=== Clemp Services Health Report ===")
    [void]$report.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$report.AppendLine()

    # N8N
    [void]$report.AppendLine("N8N (Port 5678):")
    if ($health.Services.N8N.Healthy) {
        [void]$report.AppendLine("  Status: ✅ Healthy")
    } else {
        [void]$report.AppendLine("  Status: ❌ Unhealthy")
        if ($health.Services.N8N.Error) {
            [void]$report.AppendLine("  Error: $($health.Services.N8N.Error)")
        }
    }
    [void]$report.AppendLine()

    # Ollama
    [void]$report.AppendLine("Ollama (Port 11434):")
    if ($health.Services.Ollama.Healthy) {
        [void]$report.AppendLine("  Status: ✅ Healthy")
    } else {
        [void]$report.AppendLine("  Status: ❌ Unhealthy")
        if ($health.Services.Ollama.Error) {
            [void]$report.AppendLine("  Error: $($health.Services.Ollama.Error)")
        }
    }
    [void]$report.AppendLine()

    # Qdrant
    [void]$report.AppendLine("Qdrant (Port 6333):")
    if ($health.Services.Qdrant.Healthy) {
        [void]$report.AppendLine("  Status: ✅ Healthy")
    } else {
        [void]$report.AppendLine("  Status: ❌ Unhealthy")
        if ($health.Services.Qdrant.Error) {
            [void]$report.AppendLine("  Error: $($health.Services.Qdrant.Error)")
        }
    }
    [void]$report.AppendLine()

    # PocketBase
    [void]$report.AppendLine("PocketBase (Port 8090):")
    if ($health.Services.PocketBase.Healthy) {
        [void]$report.AppendLine("  Status: ✅ Healthy")
    } else {
        [void]$report.AppendLine("  Status: ❌ Unhealthy")
        if ($health.Services.PocketBase.Error) {
            [void]$report.AppendLine("  Error: $($health.Services.PocketBase.Error)")
        }
    }
    [void]$report.AppendLine()

    # Summary
    [void]$report.AppendLine("Summary:")
    [void]$report.AppendLine("  Overall: $(if ($health.AllHealthy) { '✅ All systems operational' } else { '⚠️ Some services are unhealthy' })")

    return $report.ToString()
}

function Watch-ServicesHealth {
    <#
    .SYNOPSIS
        Continuously monitors services health
    .PARAMETER IntervalSeconds
        Check interval in seconds
    .PARAMETER DurationSeconds
        Total duration to monitor (0 = infinite)
    #>
    param(
        [int]$IntervalSeconds = 10,
        [int]$DurationSeconds = 0
    )

    $startTime = Get-Date
    $iterations = 0

    Write-Host "Starting services health monitoring..."
    Write-Host "Press Ctrl+C to stop`n"

    try {
        while ($true) {
            $iterations++

            Clear-Host
            Write-Host "Health Check - Iteration $iterations - $(Get-Date -Format 'HH:mm:ss')`n"

            $report = Get-ServiceHealthReport
            Write-Host $report

            if ($DurationSeconds -gt 0) {
                $elapsed = (Get-Date) - $startTime
                if ($elapsed.TotalSeconds -ge $DurationSeconds) {
                    Write-Host "`nMonitoring duration reached. Stopping..."
                    break
                }
            }

            Start-Sleep -Seconds $IntervalSeconds
        }
    }
    catch {
        Write-Host "`nMonitoring stopped by user"
    }
}

function Get-ServiceHealthAsJson {
    <#
    .SYNOPSIS
        Gets service health status as JSON (for Rust backend)
    .OUTPUTS
        System.String
    #>
    $health = Test-AllServicesHealth

    $jsonObj = @{
        all_healthy = $health.AllHealthy
        services = @{
            n8n = @{
                healthy = $health.Services.N8N.Healthy
                url = $health.Services.N8N.Url
                error = $health.Services.N8N.Error
            }
            ollama = @{
                healthy = $health.Services.Ollama.Healthy
                url = $health.Services.Ollama.Url
                error = $health.Services.Ollama.Error
            }
            qdrant = @{
                healthy = $health.Services.Qdrant.Healthy
                url = $health.Services.Qdrant.Url
                error = $health.Services.Qdrant.Error
            }
            pocketbase = @{
                healthy = $health.Services.PocketBase.Healthy
                url = $health.Services.PocketBase.Url
                error = $health.Services.PocketBase.Error
            }
        }
        timestamp = (Get-Date).ToString("o")
    }

    return $jsonObj | ConvertTo-Json -Compress
}

Export-ModuleMember -Function `
    Test-HttpEndpoint,
    Test-N8NHealth,
    Test-OllamaHealth,
    Test-QdrantHealth,
    Test-PocketBaseHealth,
    Test-AllServicesHealth,
    Get-ServiceHealthReport,
    Watch-ServicesHealth,
    Get-ServiceHealthAsJson
