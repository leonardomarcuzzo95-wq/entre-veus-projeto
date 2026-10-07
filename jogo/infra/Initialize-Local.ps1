$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $env:LOCALAPPDATA 'EntreVeus'
$dbBase = Join-Path $runtime 'mariadb'
$dbData = Join-Path $runtime 'database'
$server = Join-Path $project 'servidor'
New-Item -ItemType Directory -Path $runtime,(Join-Path $runtime 'logs') -Force | Out-Null
if (-not (Test-Path -LiteralPath (Join-Path $dbBase 'bin\mariadbd.exe'))) {
    & (Join-Path $PSScriptRoot 'Expand-SafeZip.ps1') -Archive (Join-Path $project 'downloads\mariadb-11.4.13-winx64.zip') -Destination $dbBase -StripRoot
}
$secretPath = Join-Path $runtime 'credentials.json'
if (-not (Test-Path -LiteralPath $secretPath)) {
    function New-LocalSecret { [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(18)).ToLowerInvariant() }
    $secrets = @{dbRoot=New-LocalSecret;dbGame=New-LocalSecret;account='viajante';password=New-LocalSecret}
    $secrets | ConvertTo-Json | Set-Content -LiteralPath $secretPath -Encoding utf8
}
$secrets = Get-Content -LiteralPath $secretPath -Raw | ConvertFrom-Json
$myTemplate = Join-Path $runtime 'database-template.ini'
@'
[mysqld]
bind-address=127.0.0.1
innodb_buffer_pool_size=128M
max_connections=20
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
'@ | Set-Content -LiteralPath $myTemplate -Encoding ascii
if (-not (Test-Path -LiteralPath (Join-Path $dbData 'mysql'))) {
    & (Join-Path $dbBase 'bin\mariadb-install-db.exe') "--datadir=$dbData" '--port=3307' "--password=$($secrets.dbRoot)" "--config=$myTemplate" '--silent'
    if ($LASTEXITCODE -ne 0) { throw 'MariaDB initialization failed' }
}
$rootClient = Join-Path $runtime 'admin.ini'
"[client]`nuser=entreveus`npassword=$($secrets.dbGame)`nhost=127.0.0.1`nport=3307`nprotocol=tcp`ndatabase=entreveus`n" | Set-Content -LiteralPath (Join-Path $runtime 'game-client.ini') -Encoding ascii
"[client]`nuser=root`npassword=$($secrets.dbRoot)`nhost=127.0.0.1`nport=3307`nprotocol=tcp`n" | Set-Content -LiteralPath $rootClient -Encoding ascii
$dbPidFile = Join-Path $runtime 'database.pid'
$alive = $false
if (Test-Path -LiteralPath $dbPidFile) {
    $existing = Get-Process -Id ([int](Get-Content -LiteralPath $dbPidFile)) -ErrorAction SilentlyContinue
    $alive = $existing -and $existing.Path -eq (Join-Path $dbBase 'bin\mariadbd.exe')
}
if (-not $alive) {
    $dbProcess = Start-Process -FilePath (Join-Path $dbBase 'bin\mariadbd.exe') -ArgumentList @("--defaults-file=`"$dbData\my.ini`"",'--console') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'logs\database.out.log') -RedirectStandardError (Join-Path $runtime 'logs\database.err.log')
    $dbProcess.Id | Set-Content -LiteralPath $dbPidFile
}
$mysql = Join-Path $dbBase 'bin\mariadb.exe'
$ready = $false
for ($attempt=0; $attempt -lt 30; $attempt++) {
    & $mysql "--defaults-extra-file=$rootClient" '--batch' '--skip-column-names' '-e' 'SELECT 1' 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {$ready=$true;break}
    Start-Sleep -Milliseconds 500
}
if (-not $ready) { throw 'Database did not become ready; inspect local logs' }
& $mysql "--defaults-extra-file=$rootClient" '-e' "CREATE DATABASE IF NOT EXISTS entreveus CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER IF NOT EXISTS 'entreveus'@'127.0.0.1' IDENTIFIED BY '$($secrets.dbGame)'; GRANT ALL PRIVILEGES ON entreveus.* TO 'entreveus'@'127.0.0.1';"
if ($LASTEXITCODE -ne 0) {throw 'Could not create the game database/user'}
$schemaReady = & $mysql "--defaults-extra-file=$rootClient" '--batch' '--skip-column-names' '-e' "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='entreveus' AND table_name='accounts'"
if ([int]$schemaReady -eq 0) {
    $schema = (Join-Path $server 'schema.sql').Replace('\','/')
    & $mysql "--defaults-extra-file=$rootClient" '--database=entreveus' '-e' "source $schema"
    if ($LASTEXITCODE -ne 0) {throw 'Schema import failed'}
}
$config = Get-Content -LiteralPath (Join-Path $server 'config.lua.dist') -Raw
$settings = @{
    serverName='"Entre Veus - laboratorio"';serverMotd='"Bem-vindo ao laboratorio de Entre Veus."';worldType='"no-pvp"'
    ip='"127.0.0.1"';bindOnlyGlobalAddress='true';loginProtocolPort='7171';gameProtocolPort='7172';statusProtocolPort='7173'
    maxPlayers='20';defaultPriority='"normal"';allowOldProtocol='false';dataPackDirectory='"data-projeto"';useAnyDatapackFolder='true'
    mapName='"entreveus"';mapAuthor='"Projeto Entre Veus"';toggleDownloadMap='false';toggleMapCustom='false';mapDownloadUrl='""'
    mysqlHost='"127.0.0.1"';mysqlPort='3307';mysqlUser='"entreveus"';mysqlPass=('"'+$secrets.dbGame+'"');mysqlDatabase='"entreveus"'
    mysqlDatabaseBackup='false';startupDatabaseOptimization='false';freePremium='true';houseRentPeriod='"never"'
    forgeInfluencedLimit='0';forgeFiendishLimit='0';metricsEnablePrometheus='false';metricsEnableOstream='false';generateLuaApiDocs='false'
    preySystemEnabled='false';taskHuntingSystemEnabled='false';globalServerSaveShutdown='false'
}
foreach ($key in $settings.Keys) {
    $pattern = '(?m)^'+[regex]::Escape($key)+'\s*=.*$'
    if ([regex]::IsMatch($config,$pattern)) { $config = [regex]::Replace($config,$pattern,($key+' = '+$settings[$key])) }
    else {$config += "`n$key = $($settings[$key])`n"}
}
[IO.File]::WriteAllText((Join-Path $runtime 'server.lua'),$config,[Text.UTF8Encoding]::new($false))
$gameHash = [Convert]::ToHexString([Security.Cryptography.SHA1]::HashData([Text.Encoding]::UTF8.GetBytes($secrets.password))).ToLowerInvariant()
$seed = "INSERT INTO accounts (name,email,password,type,premdays) SELECT 'viajante','viajante@localhost','$gameHash',1,365 WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE name='viajante'); INSERT INTO players (name,group_id,account_id,level,vocation,health,healthmax,experience,looktype,mana,manamax,town_id,posx,posy,posz,conditions,cap,sex,lastlogin) SELECT 'Viajante',1,id,1,0,150,150,0,128,50,50,1,100,100,7,'',400,1,1 FROM accounts WHERE name='viajante' AND NOT EXISTS (SELECT 1 FROM players WHERE name='Viajante');"
& $mysql "--defaults-extra-file=$rootClient" '--database=entreveus' '-e' $seed
if ($LASTEXITCODE -ne 0) {throw 'Test account creation failed'}
Write-Output "Local database ready on 127.0.0.1:3307. Credentials: $secretPath"
