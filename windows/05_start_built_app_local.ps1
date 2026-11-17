param([switch]$Rebuild)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$backend = Join-Path $root 'backend'
$python = Join-Path $backend '.venv\Scripts\python.exe'
if (-not (Test-Path $python)) { throw 'Missing Python environment. Run windows/01_setup_dev.ps1 first.' }
if (-not (Test-Path (Join-Path $backend '.env'))) { throw 'Missing backend/.env.' }
if ($Rebuild -or -not (Test-Path (Join-Path $root 'dist/index.html'))) {
    $npm = (Get-Command npm.cmd -ErrorAction Stop).Source
    Push-Location $root
    try {
        & $npm run build
        if ($LASTEXITCODE -ne 0) { throw 'React build failed.' }
    } finally { Pop-Location }
}
Push-Location $backend
try {
    $env:SERVE_FRONTEND_DIST = '1'
    Write-Host 'Local built app: http://127.0.0.1:8000/ (Ctrl+C to stop)' -ForegroundColor Green
    & $python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
} finally { Pop-Location }
