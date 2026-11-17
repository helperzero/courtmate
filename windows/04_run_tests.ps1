param([switch]$CheckLiveApi)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$backend = Join-Path $root 'backend'
$python = Join-Path $backend '.venv\Scripts\python.exe'
$npm = (Get-Command npm.cmd -ErrorAction Stop).Source
if (-not (Test-Path $python)) { throw 'Missing Python virtual environment. Run windows/01_setup_dev.ps1 first.' }
Push-Location $backend
try {
    & $python -m pytest -q
    if ($LASTEXITCODE -ne 0) { throw 'Python API tests FAILED.' }
} finally { Pop-Location }
Push-Location $root

try {
    & $npm run typecheck
    if ($LASTEXITCODE -ne 0) { throw 'TypeScript typecheck FAILED.' }
    & $npm run build
    if ($LASTEXITCODE -ne 0) { throw 'React build FAILED.' }
} finally { Pop-Location }
if ($CheckLiveApi) { & (Join-Path $PSScriptRoot '06_check_api_readonly.ps1') }


Write-Host '[PASS] Offline API tests, TypeScript typecheck, and React build.' -ForegroundColor Green
