$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus1525'
$oldRuntime=Join-Path $env:LOCALAPPDATA 'EntreVeus'
if(Test-Path -LiteralPath "$runtime/server.pid") {
 $proc=Get-Process -Id ([int](Get-Content -LiteralPath "$runtime/server.pid")) -ErrorAction SilentlyContinue
 if($proc) {
  if($proc.Path -ne (Join-Path $project 'servidor/canary.exe')){throw 'Server PID mismatch'}
  $online=& "$oldRuntime/mariadb/bin/mariadb.exe" "--defaults-extra-file=$runtime/game-client.ini" '--batch' '--skip-column-names' '-e' 'SELECT COUNT(*) FROM players_online'
  if($LASTEXITCODE -ne 0 -or [int]$online -ne 0){throw 'Saia do personagem atualizado antes de encerrar.'}
  [IO.File]::WriteAllText("$runtime/shutdown.request",'stop')
  if(-not $proc.WaitForExit(20000)){
   Remove-Item -LiteralPath "$runtime/shutdown.request" -ErrorAction SilentlyContinue
   throw 'Servidor ainda nao encerrou; banco compartilhado preservado.'
  }
 }
}
if(Test-Path -LiteralPath "$runtime/login.pid") {
 $proc=Get-CimInstance Win32_Process -Filter ("ProcessId="+[int](Get-Content -LiteralPath "$runtime/login.pid"))
 if($proc) {
  if(-not $proc.CommandLine.Contains((Join-Path $PSScriptRoot 'login-server.mjs'))){throw 'Login PID mismatch'}
  Stop-Process -Id $proc.ProcessId
 }
}
Write-Output 'Servidor atualizado encerrado com salvamento. Banco compartilhado preservado.'
