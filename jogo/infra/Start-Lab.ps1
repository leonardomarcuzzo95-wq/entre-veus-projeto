$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus'
& (Join-Path $PSScriptRoot 'Initialize-Local.ps1')
& (Join-Path $PSScriptRoot 'Start-Login.ps1')
$exe=Join-Path $project 'servidor\canary.exe'
$pidFile=Join-Path $runtime 'server.pid'
if (Test-Path -LiteralPath $pidFile) {
    $existing=Get-Process -Id ([int](Get-Content -LiteralPath $pidFile)) -ErrorAction SilentlyContinue
    if ($existing -and $existing.Path -eq $exe) {
        $lastLog=Get-Content -LiteralPath (Join-Path $runtime 'logs\server.out.log') -Tail 10 -ErrorAction SilentlyContinue
        if ($lastLog -match 'No services running. The server is NOT online') {
            Stop-Process -Id $existing.Id
            $existing.WaitForExit(5000) | Out-Null
        } else { Write-Output "Canary process exists (PID $($existing.Id)); consult its log for readiness";exit 0 }
    }
}
$process=Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'logs\server.out.log') -RedirectStandardError (Join-Path $runtime 'logs\server.err.log')
$process.Id | Set-Content -LiteralPath $pidFile
Write-Output "Canary started (PID $($process.Id)); logs: $runtime\logs"
