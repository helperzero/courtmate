$ErrorActionPreference = 'Stop'
$backend = (Resolve-Path (Join-Path $PSScriptRoot '../backend')).Path
$python = Join-Path $backend '.venv\Scripts\python.exe'
if (-not (Test-Path $python)) { throw 'Missing Python environment. Run windows/01_setup_dev.ps1 first.' }
if (-not (Test-Path (Join-Path $backend '.env'))) { throw 'Missing backend/.env.' }

$code = @'
from sqlalchemy import text
from app.database import get_engine

engine = get_engine()
with engine.connect() as conn:
    db = conn.execute(text("SELECT DB_NAME()")).scalar()
    print("[PASS] SQL Server database:", db)
'@

Push-Location $backend
try {
    $code | & $python -
    if ($LASTEXITCODE -ne 0) {
        throw 'SQL Server connection test FAILED. Check instance, .env, ODBC driver, permissions and TLS certificate.'
    }
} finally { Pop-Location }