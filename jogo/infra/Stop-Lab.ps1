$ErrorActionPreference='Stop'
$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus'
$project=Split-Path -Parent $PSScriptRoot
$serverExe=Join-Path $project 'servidor\canary.exe'
$server=$null
if (Test-Path -LiteralPath "$runtime/server.pid") {
    $server=Get-Process -Id ([int](Get-Content -LiteralPath "$runtime/server.pid")) -ErrorAction SilentlyContinue
    if ($server -and $server.Path -ne $serverExe) {throw 'Server PID identity mismatch'}
}
if ($server) {
    $count=& "$runtime/mariadb/bin/mariadb.exe" "--defaults-extra-file=$runtime/admin.ini" '--database=entreveus' '--batch' '--skip-column-names' '-e' 'SELECT COUNT(*) FROM players_online'
    if ($LASTEXITCODE -ne 0) {throw 'Could not verify online players'}
    if ([int]$count -gt 0) {throw 'Saia do personagem antes de encerrar o laboratorio.'}
    [IO.File]::WriteAllText("$runtime/shutdown.request",'stop')
    if (-not $server.WaitForExit(20000)) {
        Remove-Item -LiteralPath "$runtime/shutdown.request" -ErrorAction SilentlyContinue
        throw 'Canary did not stop gracefully; database has been left running.'
    }
}
if (Test-Path -LiteralPath "$runtime/login.pid") {
    $loginProcess=Get-CimInstance Win32_Process -Filter ("ProcessId="+[int](Get-Content -LiteralPath "$runtime/login.pid"))
    if ($loginProcess) {
        $script=Join-Path $PSScriptRoot 'login-server.mjs'
        if (-not $loginProcess.CommandLine.Contains($script)) {throw 'Login process identity mismatch'}
        Stop-Process -Id $loginProcess.ProcessId
    }
}
if (Test-Path -LiteralPath "$runtime/database.pid") {
    $db=Get-Process -Id ([int](Get-Content -LiteralPath "$runtime/database.pid")) -ErrorAction SilentlyContinue
    if ($db) {
        if ($db.Path -ne (Join-Path $runtime 'mariadb/bin/mariadbd.exe')) {throw 'Database PID identity mismatch'}
        & "$runtime/mariadb/bin/mariadb-admin.exe" "--defaults-extra-file=$runtime/admin.ini" 'shutdown'
        if ($LASTEXITCODE -ne 0) {throw 'Database shutdown failed'}
        if (-not $db.WaitForExit(15000)) {throw 'Database is still shutting down'}
    }
}
Write-Output 'Laboratorio encerrado com salvamento do servidor e do banco.'
