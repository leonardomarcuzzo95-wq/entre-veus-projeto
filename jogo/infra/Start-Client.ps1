$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus'
& (Join-Path $PSScriptRoot 'Start-Lab.ps1')
$loginReady=$false
for ($i=0;$i -lt 20;$i++) {
    try {
        $health=Invoke-RestMethod 'http://127.0.0.1:8088/health' -TimeoutSec 2
        if ($health.service -eq 'entreveus-local-login') {$loginReady=$true;break}
    } catch {Start-Sleep -Milliseconds 500}
}
if (-not $loginReady) {throw 'Login local indisponivel. Consulte AppData/Local/EntreVeus/logs.'}
$ready=$false
for ($i=0;$i -lt 30;$i++) {
    $socket=[Net.Sockets.TcpClient]::new()
    try {$socket.Connect('127.0.0.1',7172);$ready=$true;break} catch {Start-Sleep -Milliseconds 500} finally {$socket.Dispose()}
}
if (-not $ready) {throw 'Servidor ainda indisponivel. Consulte AppData/Local/EntreVeus/logs.'}
$client=Join-Path $project 'cliente\otclient_gl_x64.exe'
$oldPlay=$env:ENTREVEUS_PLAY
$oldSmoke=$env:ENTREVEUS_SMOKE
try {
    $env:ENTREVEUS_PLAY='1'
    $env:ENTREVEUS_SMOKE=$null
    # This launcher is explicitly for the user's interactive game window.
    $process=Start-Process -FilePath $client -WorkingDirectory (Split-Path $client) -WindowStyle Normal -PassThru
    $process.Id | Set-Content -LiteralPath (Join-Path $runtime 'client-play.pid')
} finally {$env:ENTREVEUS_PLAY=$oldPlay;$env:ENTREVEUS_SMOKE=$oldSmoke}
Write-Output 'Cliente aberto: conectando automaticamente ao Viajante. Use as setas para andar.'
