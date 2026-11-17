$ErrorActionPreference = 'Stop'
$backend = (Resolve-Path (Join-Path $PSScriptRoot '../backend')).Path
$python = Join-Path $backend '.venv\Scripts\python.exe'
if (-not (Test-Path $python)) { throw 'Missing Python environment. Run windows/01_setup_dev.ps1 first.' }
if (-not (Test-Path (Join-Path $backend '.env'))) { throw 'Missing backend/.env. Copy and configure backend/.env.example.' }
Push-Location $backend
try {
    Write-Host 'Starting development API at http://127.0.0.1:8000/api/docs (Ctrl+C to stop)' -ForegroundColor Cyan
    $env:SERVE_FRONTEND_DIST = '0'
    & $python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
} finally { Pop-Location }
