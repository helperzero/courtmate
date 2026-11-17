param(
    [switch]$AllowWrite,
    [string]$ApiBase = 'http://127.0.0.1:8000'
)
$ErrorActionPreference = 'Stop'
if (-not $AllowWrite) {
    throw 'This script INSERTs, UPDATEs and DELETEs rows in the CONNECTED database. Run only on a disposable DEVELOPMENT database using -AllowWrite.'
}
$base = $ApiBase.TrimEnd('/')
Write-Warning 'WRITING to the database behind the supplied API. Do not run against production.'
$createdMemberIds = New-Object 'System.Collections.Generic.List[int]'
$createdSessionId = $null
$runId = [guid]::NewGuid().ToString('N').Substring(0, 12)
$today = Get-Date -Format 'yyyy-MM-dd'
function Send-Json([string]$Method, [string]$Path, [object]$Payload, [hashtable]$Headers = @{}) {
    $json = $Payload | ConvertTo-Json -Depth 20 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return Invoke-RestMethod -Method $Method -Uri "$base$Path" -Headers $Headers -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 20
}
try {
    $health = Invoke-RestMethod "$base/api/health" -TimeoutSec 15
    if (-not $health.ok) { throw 'Database health check failed.' }
    $ids = New-Object 'System.Collections.Generic.List[int]'
    for ($n = 1; $n -le 4; $n++) {
        $member = Send-Json 'POST' '/api/members' @{name="CMTEST-$runId-$n"; gender='M'; level=3.0; phone=''; memo='Windows live smoke'; active=$true; joinedAt=$today}
        $ids.Add([int]$member.id)
        $createdMemberIds.Add([int]$member.id)
    }
    $sessionPayload = @{
        title="CMTEST-$runId"; playDate=$today; format='doubles'; courts=1
        matches=@(@{round=1; court=1; teamA1=$ids[0]; teamA2=$ids[1]; teamB1=$ids[2]; teamB2=$ids[3]})
    }
    $session = Send-Json 'POST' '/api/sessions' $sessionPayload @{'Idempotency-Key'=[guid]::NewGuid().ToString()}
    $createdSessionId = [int]$session.id
    $allMatches = Invoke-RestMethod "$base/api/matches" -TimeoutSec 15
    $match = @($allMatches | Where-Object { $_.sessionId -eq $createdSessionId })
    if ($match.Count -ne 1) { throw "Expected 1 match, got $($match.Count)." }
    $score = Send-Json 'PUT' "/api/matches/$($match[0].id)/score" @{scoreA=6; scoreB=4; scoreVersion=0}
    if ($score.scoreA -ne 6 -or $score.scoreB -ne 4 -or $score.scoreVersion -ne 1) { throw 'Score update verification failed.' }
    $history = @(Invoke-RestMethod "$base/api/matches/$($match[0].id)/history" -TimeoutSec 15)
    if ($history.Count -ne 1) { throw 'Score history verification failed.' }
    Write-Host '[PASS] Live CRUD: 4 members, 1 session, 1 match, score update, and history.' -ForegroundColor Green
} finally {
    if ($null -ne $createdSessionId) {
        try { Invoke-RestMethod -Method Delete -Uri "$base/api/sessions/$createdSessionId" -TimeoutSec 15 | Out-Null }
        catch { Write-Warning "Could not clean up session ID $createdSessionId : $_" }
    }
    foreach ($memberId in $createdMemberIds) {
        try { Invoke-RestMethod -Method Delete -Uri "$base/api/members/$memberId" -TimeoutSec 15 | Out-Null }
        catch { Write-Warning "Could not clean up member ID $memberId : $_" }
    }
    Write-Host "Cleanup attempted. Search for CMTEST-$runId in the DEVELOPMENT database if a step failed."
}
