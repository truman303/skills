# Start Development Environment Script
# Copy this file to your project's scripts/ folder and replace MyApp/myapp placeholders.

param(
    [switch]$Force,
    [switch]$Rebuild,
    [switch]$Logs
)

$ErrorActionPreference = "Stop"

Write-Host "Starting MyApp Development Environment..." -ForegroundColor Green
Write-Host ""

# Check if Docker is running
try {
    docker --version | Out-Null
    Write-Host "[OK] Docker is available" -ForegroundColor Green
} catch {
    Write-Error "[ERROR] Docker is not running or not installed. Please start Docker and try again."
    exit 1
}

# Check if Docker Compose is available
try {
    docker compose version | Out-Null
    Write-Host "[OK] Docker Compose is available" -ForegroundColor Green
} catch {
    Write-Error "[ERROR] Docker Compose is not available. Please install Docker Compose and try again."
    exit 1
}

# Navigate to project root
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

# Stop existing containers if Force is specified
if ($Force) {
    Write-Host "[INFO] Stopping existing containers..." -ForegroundColor Yellow
    docker compose down -v
}

# Build containers if Rebuild is specified
if ($Rebuild) {
    Write-Host "[INFO] Rebuilding containers..." -ForegroundColor Yellow
    docker compose build --no-cache
}

# Start the containers
Write-Host "[INFO] Starting containers..." -ForegroundColor Blue
docker compose up -d

# Wait for database to be healthy
Write-Host "[INFO] Waiting for database to be healthy..." -ForegroundColor Blue
$maxAttempts = 30
$attempt = 0

while ($attempt -lt $maxAttempts) {
    $attempt++

    $dbHealthy = docker inspect myapp-db --format='{{.State.Health.Status}}' 2>$null

    if ($dbHealthy -eq "healthy") {
        Write-Host "[OK] Database is healthy" -ForegroundColor Green
        break
    }

    Write-Host "[WAIT] Waiting for database... (attempt $attempt/$maxAttempts)" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

if ($attempt -eq $maxAttempts) {
    Write-Error "[ERROR] Database failed to become healthy within timeout"
    exit 1
}

Write-Host ""
Write-Host "[SUCCESS] Development environment started!" -ForegroundColor Green
Write-Host ""
Write-Host "[INFO] Next steps:" -ForegroundColor Blue
Write-Host "  - Run the app:     dotnet run --project MyApp" -ForegroundColor White
Write-Host "  - Login:           admin / Admin123!" -ForegroundColor White
Write-Host ""
Write-Host "[INFO] Useful commands:" -ForegroundColor Blue
Write-Host "  - View logs:       docker compose logs -f" -ForegroundColor White
Write-Host "  - Stop services:   docker compose down" -ForegroundColor White
Write-Host "  - Stop & cleanup:  docker compose down -v" -ForegroundColor White
Write-Host ""

# Show logs if requested
if ($Logs) {
    Write-Host "[INFO] Showing logs..." -ForegroundColor Blue
    docker compose logs -f
}
