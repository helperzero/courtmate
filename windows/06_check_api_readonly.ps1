param([string]$ApiBase = 'http://127.0.0.1:8000')
$ErrorActionPreference = 'Stop'
$base = $ApiBase.TrimEnd('/')
Write-Host 'Read-only live API checks (no database writes):' -ForegroundColor Cyan
$health = Invoke-RestMethod -Method Get -Uri "$base/api/health" -TimeoutSec 15
if (-not $health.ok -or $health.database -ne 'connected') { throw 'Database health check failed.' }
Write-Host '[PASS] /api/health: DB connected' -ForegroundColor Green
foreach ($route in @('members', 'sessions', 'matches')) {
    $items = @(Invoke-RestMethod -Method Get -Uri "$base/api/$route" -TimeoutSec 15)
    Write-Host "[PASS] /api/$route: request succeeded"
}
Write-Host '[PASS] Read-only live checks.' -ForegroundColor Green
