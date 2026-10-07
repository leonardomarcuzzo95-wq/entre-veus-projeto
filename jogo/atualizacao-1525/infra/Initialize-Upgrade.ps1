$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$legacy=Split-Path -Parent $project
$oldRuntime=Join-Path $env:LOCALAPPDATA 'EntreVeus'
$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus1525'
& (Join-Path $legacy 'infra/Initialize-Local.ps1')
New-Item -ItemType Directory -Path $runtime,"$runtime/logs","$runtime/backups" -Force | Out-Null
$secrets=Get-Content -LiteralPath "$oldRuntime/credentials.json" -Raw | ConvertFrom-Json
if (-not (Test-Path -LiteralPath "$runtime/credentials.json")) {Copy-Item -LiteralPath "$oldRuntime/credentials.json" -Destination "$runtime/credentials.json"}
$mysql=Join-Path $oldRuntime 'mariadb/bin/mariadb.exe'
$argsBase=@("--defaults-extra-file=$oldRuntime/admin.ini",'--batch','--skip-column-names')
$exists=& $mysql @argsBase '-e' "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='entreveus_1525' AND table_name='accounts'"
if ($LASTEXITCODE -ne 0) {throw 'Cannot inspect local database'}
if ([int]$exists -eq 0) {
    $backup=Join-Path $runtime ('backups/pre-upgrade-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.sql')
    & "$oldRuntime/mariadb/bin/mariadb-dump.exe" "--defaults-extra-file=$oldRuntime/admin.ini" '--single-transaction' '--routines' '--events' '--triggers' "--result-file=$backup" 'entreveus'
    if ($LASTEXITCODE -ne 0 -or (Get-Item -LiteralPath $backup).Length -lt 1000) {throw 'Backup failed'}
    & $mysql @argsBase '-e' 'CREATE DATABASE entreveus_1525 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
    if ($LASTEXITCODE -ne 0) {throw 'Cannot create isolated upgrade database'}
    $sourcePath=$backup.Replace('\','/')
    & $mysql @argsBase '--database=entreveus_1525' '-e' "source $sourcePath"
    if ($LASTEXITCODE -ne 0) {throw 'Cannot restore upgrade copy'}
    & $mysql @argsBase '--database=entreveus_1525' '-e' 'DELETE FROM players_online'
    $backup | Set-Content -LiteralPath "$runtime/backup-source.txt"
}
& $mysql @argsBase '-e' "CREATE USER IF NOT EXISTS 'entreveus_1525'@'127.0.0.1' IDENTIFIED BY '$($secrets.dbGame)'; GRANT ALL PRIVILEGES ON entreveus_1525.* TO 'entreveus_1525'@'127.0.0.1';"
if ($LASTEXITCODE -ne 0) {throw 'Cannot prepare upgrade database user'}
"[client]`nuser=entreveus_1525`npassword=$($secrets.dbGame)`nhost=127.0.0.1`nport=3307`nprotocol=tcp`ndatabase=entreveus_1525`n" | Set-Content -LiteralPath "$runtime/game-client.ini" -Encoding ascii
$config=Get-Content -LiteralPath (Join-Path $project 'servidor/config.lua.dist') -Raw
$settings=@{
 serverName='"Entre Veus"';serverMotd='"Bem-vindo ao Porto da Memoria."';worldType='"no-pvp"';ip='"127.0.0.1"';bindOnlyGlobalAddress='true'
 loginProtocolPort='7271';gameProtocolPort='7272';statusProtocolPort='7273';maxPlayers='20';defaultPriority='"normal"';allowOldProtocol='false'
 dataPackDirectory='"data-projeto"';useAnyDatapackFolder='true';mapName='"entreveus"';mapAuthor='"Projeto Entre Veus"';toggleDownloadMap='false';toggleMapCustom='false';mapDownloadUrl='""'
 mysqlHost='"127.0.0.1"';mysqlPort='3307';mysqlUser='"entreveus_1525"';mysqlPass=('"'+$secrets.dbGame+'"');mysqlDatabase='"entreveus_1525"'
 mysqlDatabaseBackup='false';startupDatabaseOptimization='false';freePremium='true';houseRentPeriod='"never"';forgeInfluencedLimit='0';forgeFiendishLimit='0'
 metricsEnablePrometheus='false';metricsEnableOstream='false';generateLuaApiDocs='false';preySystemEnabled='false';taskHuntingSystemEnabled='false';globalServerSaveShutdown='false'
}
foreach($key in $settings.Keys) {
 $pattern='(?m)^'+[regex]::Escape($key)+'\s*=.*$'
 if([regex]::IsMatch($config,$pattern)) {$config=[regex]::Replace($config,$pattern,($key+' = '+$settings[$key]))} else {$config+="`n$key = $($settings[$key])`n"}
}
[IO.File]::WriteAllText("$runtime/server.lua",$config,[Text.UTF8Encoding]::new($false))
Write-Output 'Copia do banco pronta: entreveus_1525. Backup privado preservado em AppData/Local/EntreVeus1525/backups.'
