$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus'
$client=Join-Path $project 'cliente\otclient_gl_x64.exe'
$oldValue=$env:ENTREVEUS_SMOKE
try {
    $env:ENTREVEUS_SMOKE='1'
    $process=Start-Process -FilePath $client -WorkingDirectory (Split-Path $client) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'logs\client.out.log') -RedirectStandardError (Join-Path $runtime 'logs\client.err.log')
    $process.Id | Set-Content -LiteralPath (Join-Path $runtime 'client-test.pid')
    Write-Output "Client test started (PID $($process.Id)). It will exit automatically."
} finally { $env:ENTREVEUS_SMOKE=$oldValue }
