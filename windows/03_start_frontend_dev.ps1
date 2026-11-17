$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$npm = (Get-Command npm.cmd -ErrorAction Stop).Source
$frontend = Join-Path $root 'frontend'

if (-not (Test-Path (Join-Path $frontend 'node_modules'))) { throw 'Missing node_modules. Run windows/01_setup_dev.ps1 first.' }
Push-Location $root
Push-Location $frontend
try {
    Write-Host 'Starting Vite at http://127.0.0.1:5173 (Ctrl+C to stop)' -ForegroundColor Cyan
    & $npm run dev -- --host 127.0.0.1 --port 5173 --strictPort
} finally { Pop-Location }
