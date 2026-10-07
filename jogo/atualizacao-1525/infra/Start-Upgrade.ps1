param([switch]$Play,[switch]$Smoke)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus1525'
& "$PSScriptRoot/Initialize-Upgrade.ps1"
function Start-LocalService($name,$exe,$working,$arguments) {
 $pidFile=Join-Path $runtime ($name+'.pid')
 if(Test-Path -LiteralPath $pidFile) {
  $existing=Get-Process -Id ([int](Get-Content -LiteralPath $pidFile)) -ErrorAction SilentlyContinue
  if($existing -and $existing.Path -eq $exe) {return}
 }
 $options=@{FilePath=$exe;WorkingDirectory=$working;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput="$runtime/logs/$name.out.log";RedirectStandardError="$runtime/logs/$name.err.log"}
 if($arguments){$options.ArgumentList=$arguments}
 $proc=Start-Process @options
 $proc.Id | Set-Content -LiteralPath $pidFile
}
$node=(Get-Command node.exe).Source
Start-LocalService 'login' $node $PSScriptRoot @('"'+(Join-Path $PSScriptRoot 'login-server.mjs')+'"')
Start-LocalService 'server' (Join-Path $project 'servidor/canary.exe') (Join-Path $project 'servidor') @()
$ready=$false
for($i=0;$i -lt 60;$i++) {
 $socket=[Net.Sockets.TcpClient]::new()
 try {$socket.Connect('127.0.0.1',7272);$health=Invoke-RestMethod 'http://127.0.0.1:8090/health' -TimeoutSec 2;if($health.protocol -eq 1525){$ready=$true;break}}catch{Start-Sleep -Milliseconds 500}finally{$socket.Dispose()}
}
if(-not $ready){throw 'Atualizacao ainda indisponivel. Consulte AppData/Local/EntreVeus1525/logs.'}
$mysql=Join-Path $env:LOCALAPPDATA 'EntreVeus/mariadb/bin/mariadb.exe'
$schemaReady=& $mysql "--defaults-extra-file=$runtime/game-client.ini" '--batch' '--skip-column-names' '-e' "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema='entreveus_1525' AND table_name='players' AND column_name='expert_pvp_mode'"
if($LASTEXITCODE -ne 0 -or [int]$schemaReady -ne 1){throw 'Migracao 59 incompleta: login bloqueado para evitar perda de progresso.'}
Write-Output 'Servidor 15.25 e login prontos no computador.'
if($Play -or $Smoke) {
 $oldPlay=$env:ENTREVEUS_PLAY;$oldSmoke=$env:ENTREVEUS_SMOKE
 try {
  $env:ENTREVEUS_PLAY=if($Play){'1'}else{$null};$env:ENTREVEUS_SMOKE=if($Smoke){'1'}else{$null}
  $client=Join-Path $project 'cliente/otclient_gl_x64.exe'
  $proc=Start-Process -FilePath $client -WorkingDirectory (Split-Path $client) -WindowStyle Normal -PassThru
  $proc.Id | Set-Content -LiteralPath "$runtime/client.pid"
 }finally{$env:ENTREVEUS_PLAY=$oldPlay;$env:ENTREVEUS_SMOKE=$oldSmoke}
}
