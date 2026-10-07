param([switch]$PreviewOnly)
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus1525'
$oldRuntime=Join-Path $env:LOCALAPPDATA 'EntreVeus'
$runId='run-'+[datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[guid]::NewGuid().ToString('N')
$startedAt=[datetime]::UtcNow.ToString('o')
& "$PSScriptRoot/Start-Upgrade.ps1" | Out-Null
$secrets=Get-Content -LiteralPath "$runtime/credentials.json" -Raw | ConvertFrom-Json
$hash=[Convert]::ToHexString([Security.Cryptography.SHA1]::HashData([Text.Encoding]::UTF8.GetBytes($secrets.password))).ToLowerInvariant()
$mysql=Join-Path $oldRuntime 'mariadb/bin/mariadb.exe'
$argsBase=@("--defaults-extra-file=$runtime/game-client.ini",'--batch','--skip-column-names')
$count=& $mysql @argsBase '-e' "SELECT COUNT(*) FROM players_online o JOIN players p ON p.id=o.player_id WHERE p.name='Explorador QA'"
if($LASTEXITCODE -ne 0 -or [int]$count -ne 0){throw 'QA character must be offline'}
$allOnline=& $mysql @argsBase '-e' 'SELECT COUNT(*) FROM players_online'
if($LASTEXITCODE -ne 0 -or [int]$allOnline -ne 0){throw 'Execute a rodada isolada sem jogadores conectados.'}
$backupId='content-'+$runId+'.sql'
$backupPath=Join-Path "$runtime/backups" $backupId
& "$oldRuntime/mariadb/bin/mariadb-dump.exe" "--defaults-extra-file=$oldRuntime/admin.ini" '--single-transaction' '--routines' '--events' '--triggers' '--hex-blob' "--result-file=$backupPath" 'entreveus_1525'
if($LASTEXITCODE -ne 0 -or (Get-Item -LiteralPath $backupPath).Length -lt 1000){throw 'Backup privado da rodada falhou; QA nao foi redefinido.'}
$context=[ordered]@{runId=$runId;startedAt=$startedAt;character='Explorador QA';previewOnly=[bool]$PreviewOnly;backup=@{id=$backupId;sha256=(Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash.ToLowerInvariant()};status='preparing'}
$context | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$runtime/content-run-$runId.json" -Encoding utf8
if(-not $PreviewOnly){@{runId=$runId} | ConvertTo-Json | Set-Content -LiteralPath "$runtime/latest-content-run.json" -Encoding utf8}
$sql="INSERT INTO accounts (name,email,password,type,premdays) SELECT 'ensaio','ensaio@localhost','$hash',1,365 WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE name='ensaio'); INSERT INTO players (name,group_id,account_id,level,vocation,health,healthmax,experience,looktype,mana,manamax,town_id,posx,posy,posz,conditions,cap,sex,lastlogin) SELECT 'Explorador QA',1,id,1,0,150,150,0,128,50,50,1,100,100,7,'',400,1,1 FROM accounts WHERE name='ensaio' AND NOT EXISTS (SELECT 1 FROM players WHERE name='Explorador QA'); DELETE s FROM player_storage s JOIN players p ON p.id=s.player_id WHERE p.name='Explorador QA' AND s.`"key`"=110020; UPDATE players SET posx=100,posy=100,posz=7,experience=0,level=1 WHERE name='Explorador QA';"
# MariaDB column quoting is supplied literally without shell backtick interpolation.
$sql=$sql.Replace('s."key"','s.'+[char]96+'key'+[char]96)
# A repeat starts from an empty QA inventory; never reset the player's inventory.
$sql += " DELETE i FROM player_items i JOIN players p ON p.id=i.player_id WHERE p.name='Explorador QA';"
& $mysql @argsBase '-e' $sql
if($LASTEXITCODE -ne 0){throw 'QA preparation failed'}
$old=$env:ENTREVEUS_CONTENT_SMOKE
$oldRun=$env:ENTREVEUS_RUN_ID
$oldPlay=$env:ENTREVEUS_PLAY
$oldSmoke=$env:ENTREVEUS_SMOKE
$oldPreview=$env:ENTREVEUS_UI_PREVIEW
try {
 $env:ENTREVEUS_CONTENT_SMOKE='1'
 $env:ENTREVEUS_RUN_ID=$runId
 $env:ENTREVEUS_PLAY=$null
 $env:ENTREVEUS_SMOKE=$null
 $env:ENTREVEUS_UI_PREVIEW=if($PreviewOnly){'1'}else{$null}
 $client=Join-Path $project 'cliente/otclient_gl_x64.exe'
 $proc=Start-Process -FilePath $client -WorkingDirectory (Split-Path $client) -WindowStyle Normal -PassThru
 $proc.Id | Set-Content -LiteralPath "$runtime/content-test.pid"
 $context.status='client_started'
 $context.clientPid=$proc.Id
 $context | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$runtime/content-run-$runId.json" -Encoding utf8
 if($PreviewOnly){Write-Output "Captura inicial QA iniciada; sem missao. RunId=$runId"}
 else{Write-Output "Uma rodada QA iniciada. RunId=$runId"}
}finally{
 $env:ENTREVEUS_CONTENT_SMOKE=$old
 $env:ENTREVEUS_RUN_ID=$oldRun
 $env:ENTREVEUS_PLAY=$oldPlay
 $env:ENTREVEUS_SMOKE=$oldSmoke
 $env:ENTREVEUS_UI_PREVIEW=$oldPreview
}
