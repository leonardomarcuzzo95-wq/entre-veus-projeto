$ErrorActionPreference='Stop'
$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus'
$pidFile=Join-Path $runtime 'login.pid'
$node=(Get-Command node.exe).Source
if (Test-Path -LiteralPath $pidFile) {
    $existing=Get-Process -Id ([int](Get-Content -LiteralPath $pidFile)) -ErrorAction SilentlyContinue
    if ($existing -and $existing.Path -eq $node) {
        $health=Invoke-RestMethod 'http://127.0.0.1:8088/health' -TimeoutSec 3
        if ($health.service -eq 'entreveus-local-login') { Write-Output 'Local login ready';exit 0 }
        throw 'Recorded login PID exists but health check failed'
    }
}
$script=Join-Path $PSScriptRoot 'login-server.mjs'
$process=Start-Process -FilePath $node -ArgumentList @('"'+$script+'"') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'logs\login.out.log') -RedirectStandardError (Join-Path $runtime 'logs\login.err.log')
$process.Id | Set-Content -LiteralPath $pidFile
Write-Output "Login adapter started (PID $($process.Id))"
