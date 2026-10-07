$ErrorActionPreference='Stop'
$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus'
$project=Split-Path -Parent $PSScriptRoot
$evidence=Join-Path (Split-Path -Parent $project) 'avaliacao\etapa-1'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$secrets=Get-Content -LiteralPath "$runtime/credentials.json" -Raw | ConvertFrom-Json
$valid=Invoke-RestMethod 'http://127.0.0.1:8088/login' -Method Post -ContentType 'application/json' -Body (@{email=$secrets.account;password=$secrets.password;type='login'} | ConvertTo-Json)
$invalid=Invoke-RestMethod 'http://127.0.0.1:8088/login' -Method Post -ContentType 'application/json' -Body (@{email=$secrets.account;password='invalid-test-password';type='login'} | ConvertTo-Json)
$injection=Invoke-RestMethod 'http://127.0.0.1:8088/login' -Method Post -ContentType 'application/json' -Body (@{email="' OR 1=1 --";password='invalid';type='login'} | ConvertTo-Json)
$client=Get-Content -LiteralPath "$runtime/client-smoke.json" -Raw | ConvertFrom-Json
$mysql=Join-Path $runtime 'mariadb/bin/mariadb.exe'
$row=& $mysql "--defaults-extra-file=$runtime/admin.ini" '--database=entreveus' '--batch' '--skip-column-names' '-e' "SELECT posx,posy,posz,level FROM players WHERE name='Viajante'"
if ($LASTEXITCODE -ne 0) {throw 'Database verification failed'}
$values=$row -split "`t"
$ports=Get-NetTCPConnection -State Listen | Where-Object {$_.LocalPort -in 3307,7171,7172,7173,8088} | Select-Object LocalAddress,LocalPort
$required=@(3307,7172,7173,8088)
$missing=@($required | Where-Object {$_ -notin $ports.LocalPort})
$report=[ordered]@{
    verifiedAt=(Get-Date).ToString('o')
    validLogin=($valid.playdata.characters[0].name -eq 'Viajante')
    wrongPasswordRejected=($invalid.errorCode -ne 0 -and -not $invalid.session)
    invalidAccountRejected=($injection.errorCode -ne 0 -and -not $injection.session)
    nativeClient=$client
    databasePosition=@{x=[int]$values[0];y=[int]$values[1];z=[int]$values[2]}
    positionMatchesDatabase=([int]$values[0] -eq $client.moved.x -and [int]$values[1] -eq $client.moved.y -and [int]$values[2] -eq $client.moved.z)
    loopbackOnly=(@($ports | Where-Object {$_.LocalAddress -ne '127.0.0.1'}).Count -eq 0 -and $missing.Count -eq 0)
    listeners=@($ports)
}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence 'verificacao.json') -Encoding utf8
Copy-Item -LiteralPath "$runtime/client-smoke.json" -Destination (Join-Path $evidence 'cliente.json') -Force
if ($client.screenshot -and (Test-Path -LiteralPath $client.screenshot)) {
    Copy-Item -LiteralPath $client.screenshot -Destination (Join-Path $evidence 'prototipo.png') -Force
}
if (-not ($report.validLogin -and $report.wrongPasswordRejected -and $report.invalidAccountRejected -and $client.success -and $report.positionMatchesDatabase -and $report.loopbackOnly)) {throw 'Verification failed. Inspect avaliacao/etapa-1/verificacao.json'}
Write-Output 'PASS: login, invalid credentials, movement, reconnect, database persistence and loopback listeners.'
