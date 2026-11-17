param([switch]$SkipPython, [switch]$SkipNode)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$backend = Join-Path $root 'backend'
$frontend = Join-Path $root 'frontend'
$venvPython = Join-Path $backend '.venv\Scripts\python.exe'

if (-not (Test-Path (Join-Path $backend '.env'))) {
    Copy-Item (Join-Path $backend '.env.example') (Join-Path $backend '.env')
    Write-Host '[CREATED] backend/.env; configure MSSQL credentials before running API.' -ForegroundColor Yellow
} else { Write-Host '[SKIPPED] backend/.env already exists.' }
if (-not (Test-Path (Join-Path $root 'frontend/.env'))) {
    Copy-Item (Join-Path $root 'frontend/.env.example') (Join-Path $root 'frontend/.env')
    Write-Host '[CREATED] root .env for Vite proxy.'
}

if (-not $SkipPython) {
    if (-not (Test-Path $venvPython)) {
        $launcher = Get-Command py.exe -ErrorAction SilentlyContinue
        if ($launcher) {
            $has312 = $false
            try {
                & $launcher.Source -3.12 --version *> $null
                $has312 = ($LASTEXITCODE -eq 0)
            } catch { $has312 = $false }
            if ($has312) { & $launcher.Source -3.12 -m venv (Join-Path $backend '.venv') }
            else { & $launcher.Source -3 -m venv (Join-Path $backend '.venv') }
        } else {
            $python = Get-Command python.exe -ErrorAction Stop
            & $python.Source -m venv (Join-Path $backend '.venv')
        }
        if ($LASTEXITCODE -ne 0) { throw 'Failed to create Python virtual environment.' }
    }
    Push-Location $backend
    try {
        & $venvPython -m pip install -r requirements-dev.txt
        if ($LASTEXITCODE -ne 0) { throw 'Python dependencies could not be installed.' }
        
        $check = @'
import sys, fastapi, sqlalchemy, pyodbc, pytest
print("Python", sys.version.split()[0])
print("fastapi", fastapi.__version__)
print("sqlalchemy", sqlalchemy.__version__)
print("pyodbc", pyodbc.version)
print("pytest", pytest.__version__)
'@
        
        $check | & $venvPython -
        if ($LASTEXITCODE -ne 0) { throw 'Python dependencies cannot be imported.' }
    } finally { Pop-Location }
}

if (-not $SkipNode) {
    $npm = Get-Command npm.cmd -ErrorAction Stop
    Push-Location $frontend
    try {
        & $npm.Source ci
        if ($LASTEXITCODE -ne 0) { throw 'npm ci failed.' }
    } finally { Pop-Location }
}
Write-Host '[DONE] Setup completed. Review backend/.env and create the SQL Server schema.' -ForegroundColor Green
