# Windows PowerShell 5.1 / PowerShell 7 supported.
$ErrorActionPreference = 'Continue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Write-Host '=== CourtMate Windows prerequisites ===' -ForegroundColor Cyan
Write-Host "Project: $root"
foreach ($name in @('py.exe', 'python.exe', 'node.exe', 'npm.cmd', 'git.exe')) {
    $found = Get-Command $name -ErrorAction SilentlyContinue
    if ($null -eq $found) { Write-Host "[MISSING] $name" -ForegroundColor Yellow }
    else {
        Write-Host "[FOUND] $name : $($found.Source)"
        if ($name -eq 'py.exe') { & $found.Source --version }
        if ($name -eq 'python.exe') { & $found.Source --version }
        if ($name -eq 'node.exe') { & $found.Source --version }
        if ($name -eq 'npm.cmd') { & $found.Source --version }
    }
}
try {
    $drivers = Get-OdbcDriver -ErrorAction Stop | Where-Object { $_.Name -like '*ODBC Driver 18 for SQL Server*' }
    if ($drivers) { $drivers | Select-Object Name, Platform | Format-Table -AutoSize }
    else { Write-Host '[MISSING] ODBC Driver 18 for SQL Server' -ForegroundColor Yellow }
} catch {
    Write-Host "[INFO] Could not enumerate ODBC drivers: $_" -ForegroundColor Yellow
}
Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'MSSQLSERVER' -or $_.Name -like 'MSSQL$*' } | Select-Object Name, Status | Format-Table -AutoSize
foreach ($port in @(8000, 5173)) {
    $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($listener) { Write-Host "[BUSY] Port $port is already listening" -ForegroundColor Yellow }
    else { Write-Host "[FREE] Port $port" }
}
if (Test-Path (Join-Path $root 'backend/.venv/Scripts/python.exe')) { Write-Host '[FOUND] Python virtual environment' }
if (Test-Path (Join-Path $root 'backend/.env')) { Write-Host '[FOUND] backend/.env (contents hidden)' }
if (Test-Path (Join-Path $root 'node_modules')) { Write-Host '[FOUND] node_modules' }
Write-Host '=== End diagnostics ==='
