param([switch]$AfterRestart,[string]$RunId,[switch]$ChecksOnly)
$ErrorActionPreference='Stop'

# Loads pure validation for negative unit tests; no game or database work.
function Get-EvidenceValidationFailures($report) {
    $issues=[Collections.Generic.List[string]]::new()
    if(-not ($report.persistedQA.experience -eq 100)){
        $issues.Add('A experiencia do QA deve ser exatamente 100 XP.')
    }
    if(-not ($report.persistedQA.questState -eq 2 -and $report.persistedQA.rewardCount -eq 1 -and $report.persistedQA.bagCount -eq 1)){
        $issues.Add('Estado final, bolsa e recompensa unica do QA nao confirmados.')
    }
    if($report.schemaVersion -ne 59){$issues.Add('Esquema diferente de 59.')}
    if(-not $report.freshEvidence){$issues.Add('Evidencia antiga ou sem execucao recente correlacionada.')}
    if(-not $report.localOnly){$issues.Add('Portas locais ausentes ou expostas.')}
    if(-not $report.backupExists){$issues.Add('Backup privado da rodada nao confirmado.')}
    if($report.persistedQA.online -ne 0){$issues.Add('QA ainda conectado; persistencia nao confirmada.')}
    $content=$report.contentTest
    if(-not ($content.success -and $content.result.status -eq 'passed' -and $content.npcPresent -and $content.creaturePresent -and $content.fragmentReached -and $content.fragmentMessage -and $content.rewardOnce -and $content.duplicateRewardRejected -and $content.experienceBefore -eq 0 -and $content.experienceAfter -eq 100)){
        $issues.Add('Missao do cliente real nao confirmou todas as condicoes.')
    }
    if(-not ($content.luaSyntax.passed -and $content.recorderUnitTests.passed)){
        $issues.Add('Preflight Lua/regressao do registro nao passou.')
    }
    $launcher=$report.launcherObservation
    if(-not ($launcher.mode -eq 'qa-observer' -and $launcher.character -eq 'Explorador QA' -and $launcher.success -and $launcher.result.status -eq 'passed' -and $launcher.formCredentialsMatch)){
        $issues.Add('Observacao de login do QA nao confirmada.')
    }
    foreach($source in @($launcher,$content)){
        if(-not $source){$issues.Add('Relatorio ausente.');continue}
        if($source.schemaVersion -ne 2 -or $source.runId -ne $report.runId -or $source.isHistorical){
            $issues.Add('Formato/runId da fonte invalido ou historico.')
        }
        if($source.protocol -ne 1525 -or $source.clientVersion -ne 1525){$issues.Add('Protocolo/cliente atual nao confirmado.')}
        if($source.PSObject.Properties.Name -contains 'error'){$issues.Add('Campo error legado ambiguo em evidencia nova.')}
        if(-not $source.result.completedAt){$issues.Add('Resultado sem horario de conclusao.')}
        if($source.state.connection -ne 'offline'){$issues.Add('Desconexao final nao observada.')}
        $events=@($source.events)
        if(-not $events.Count){$issues.Add('Fonte sem eventos.');continue}
        $sequence=0;$lastElapsed=-1;$lastTime=[datetimeoffset]::MinValue
        foreach($event in $events){
            $sequence++
            $parsed=[datetimeoffset]::MinValue
            if($event.timestamp -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$' -or -not [datetimeoffset]::TryParse($event.timestamp,[ref]$parsed)){
                $issues.Add('Evento sem horario ISO-8601 UTC valido.')
            }elseif($parsed -lt $lastTime){$issues.Add('Relogio UTC retrocedeu entre eventos.')}
            $lastTime=$parsed
            if($event.runId -ne $report.runId -or $event.sequence -ne $sequence -or $event.elapsedMs -lt $lastElapsed){
                $issues.Add('Evento sem correlacao ou ordem consistente.')
            }
            $lastElapsed=$event.elapsedMs
        }
        $successful=@($events | Where-Object {$_.event -eq 'checkCompleted' -and $_.passed})
        $lastSuccess=if($successful.Count){$successful[-1].sequence}else{$null}
        $errors=@($events | Where-Object isError)
        $before=@($errors | Where-Object {$lastSuccess -and $_.sequence -lt $lastSuccess}).Count
        $after=@($errors | Where-Object {$lastSuccess -and $_.sequence -gt $lastSuccess}).Count
        $order='no_success_or_error_observed'
        if($lastSuccess){
            $order='no_error_observed'
            if($before -and $after){$order='errors_before_and_after_success'}
            elseif($before){$order='error_before_success'}
            elseif($after){$order='error_after_success'}
        }elseif($errors.Count){$order='error_without_verified_success'}
        if($source.eventSummary.errorOrder -ne $order -or $source.eventSummary.errorCount -ne $errors.Count){
            $issues.Add('Resumo nao corresponde a ordem dos eventos.')
        }
    }
    return $issues.ToArray()
}
if($ChecksOnly){return}

$runtime=Join-Path $env:LOCALAPPDATA 'EntreVeus1525'
$oldRuntime=Join-Path $env:LOCALAPPDATA 'EntreVeus'
$project=Split-Path -Parent $PSScriptRoot
$evidence=Join-Path (Split-Path -Parent (Split-Path -Parent $project)) 'avaliacao/atualizacao-1525'
if(-not $RunId){
    $pointer=Get-Content -LiteralPath "$runtime/latest-content-run.json" -Raw | ConvertFrom-Json -DateKind String
    $RunId=$pointer.runId
}
if($RunId -notmatch '^run-[A-Za-z0-9_-]+$'){throw 'runId invalido; rode Test-Content.ps1.'}
$context=Get-Content -LiteralPath "$runtime/content-run-$RunId.json" -Raw | ConvertFrom-Json -DateKind String
if($context.runId -ne $RunId -or $context.character -ne 'Explorador QA'){throw 'Contexto QA inconsistente.'}
$content=Get-Content -LiteralPath "$runtime/content-smoke-$RunId.json" -Raw | ConvertFrom-Json -DateKind String
$launcher=Get-Content -LiteralPath "$runtime/launcher-login-$RunId.json" -Raw | ConvertFrom-Json -DateKind String
$mysql=Join-Path $oldRuntime 'mariadb/bin/mariadb.exe'
$argsBase=@("--defaults-extra-file=$runtime/game-client.ini",'--batch','--skip-column-names')
$query=@'
SELECT (SELECT value FROM server_config WHERE config='db_version'),p.experience,COALESCE(s.value,-1),
(SELECT COUNT(*) FROM player_items i WHERE i.player_id=p.id AND i.itemtype=62011),
(SELECT COUNT(*) FROM player_items i WHERE i.player_id=p.id AND i.itemtype=62012),
(SELECT COUNT(*) FROM players_online o WHERE o.player_id=p.id)
FROM players p LEFT JOIN player_storage s ON s.player_id=p.id AND s.`key`=110020 WHERE p.name='Explorador QA';
'@
$row=& $mysql @argsBase '-e' $query
if($LASTEXITCODE -ne 0 -or -not $row){throw 'Nao foi possivel ler persistencia do QA.'}
$values=$row -split "\t"
if($values.Count -ne 6){throw 'Resposta SQL inesperada.'}
$listeners=@(Get-NetTCPConnection -State Listen | Where-Object {$_.LocalPort -in 7271,7272,7273,8090} | Select-Object LocalAddress,LocalPort)
$missing=@(7271,7272,7273,8090 | Where-Object {$_ -notin $listeners.LocalPort})
$now=[datetimeoffset]::UtcNow
$fresh=$false
try{
    $started=[datetimeoffset]$context.startedAt
    $fresh=($now - $started).TotalMinutes -le 60 -and $now -ge $started
    foreach($source in @($content,$launcher)){
        $sourceStart=[datetimeoffset]$source.startedAt
        $sourceEnd=[datetimeoffset]$source.result.completedAt
        $fresh=$fresh -and $sourceStart -ge $started.AddSeconds(-1) -and $sourceEnd -ge $sourceStart -and $sourceEnd -le $now
    }
}catch{$fresh=$false}
# Private paths never enter the public report.
$backupId=[string]$context.backup.id
if($backupId -notmatch '^content-run-[A-Za-z0-9_-]+\.sql$'){throw 'Identificador de backup invalido.'}
$backupPath=Join-Path "$runtime/backups" $backupId
$backupExists=(Test-Path -LiteralPath $backupPath)
if($backupExists){$backupExists=(Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash.ToLowerInvariant() -eq $context.backup.sha256}
$report=[ordered]@{
    reportVersion=2;runId=$RunId;verifiedAt=$now.ToString('o');protocol=1525;schemaVersion=[int]$values[0]
    isHistorical=$false;freshEvidence=$fresh
    scope='One QA mission run; database read now; interactive Viajante and restart not executed.'
    contentTest=$content;launcherObservation=$launcher
    persistedQA=@{observedAt=$now.ToString('o');character='Explorador QA';experience=[int]$values[1];questState=[int]$values[2];rewardCount=[int]$values[3];bagCount=[int]$values[4];online=[int]$values[5]}
    backupExists=$backupExists;backup=@{id=$backupId;sha256=$context.backup.sha256}
    localOnly=($missing.Count -eq 0 -and @($listeners | Where-Object {$_.LocalAddress -ne '127.0.0.1'}).Count -eq 0)
    listeners=$listeners
    historicalEvidence=@{
        isHistorical=$true;executionDate='2026-10-02'
        directory='historico/2026-10-02'
        interactiveLogin='Not rerun; old error/success order remains unknown.'
        protocolReconnect='Historical only; not reused as a pass in this run.'
    }
    restartCheck=@{requested=[bool]$AfterRestart;performed=$false}
}
if($AfterRestart){
    $server=Get-Process -Id ([int](Get-Content -LiteralPath "$runtime/server.pid"))
    $database=Get-Process -Id ([int](Get-Content -LiteralPath "$oldRuntime/database.pid"))
    $completed=([datetimeoffset]$content.result.completedAt).UtcDateTime
    $report.restartCheck=@{
        requested=$true;performed=$true
        serverStartedAt=$server.StartTime.ToUniversalTime().ToString('o')
        databaseStartedAt=$database.StartTime.ToUniversalTime().ToString('o')
        servicesRestartedAfterQuest=($server.StartTime.ToUniversalTime() -gt $completed -and $database.StartTime.ToUniversalTime() -gt $completed)
        scope='Process start times and persisted QA database state; no automatic reconnect test.'
    }
}
$issues=@(Get-EvidenceValidationFailures ([pscustomobject]$report))
if($AfterRestart -and -not $report.restartCheck.servicesRestartedAfterQuest){$issues+='Servidor/banco nao reiniciados apos esta rodada.'}
$warnings=@()
if($content.eventSummary.errorCount -gt 0 -or $launcher.eventSummary.errorCount -gt 0){
    $warnings+='Connection events occurred; inspect timed sequence. A completed check is not continuous connection health.'
}
$report.result=@{status=if($issues.Count){'failed'}elseif($warnings.Count){'passed_with_warnings'}else{'passed'};errors=$issues;warnings=$warnings}
$report.currentState=@{observedAt=$now.ToString('o');qaOnline=([int]$values[5] -gt 0);servicesListening=$report.localOnly}
$runDirectory=Join-Path $evidence "execucoes/$RunId"
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$verificationId='verification-'+$now.ToString('yyyyMMddTHHmmssfffZ')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$report.verificationId=$verificationId
$reportFile=Join-Path $runDirectory "$verificationId.json"
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $reportFile -Encoding utf8
# Frozen copies per verification; earlier evidence is never replaced.
$content | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $runDirectory "$verificationId-missao.json") -Encoding utf8
$launcher | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $runDirectory "$verificationId-entrada-qa.json") -Encoding utf8
$reportReference="execucoes/$RunId/$verificationId.json"
@{runId=$RunId;report=$reportReference;verifiedAt=$now.ToString('o');status=$report.result.status} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'ultimo-relatorio.json') -Encoding utf8
if($issues.Count){throw ('Validacao falhou: '+($issues -join ' '))}
Write-Output "PASS: QA, 100 XP exatos, recompensa unica, eventos correlacionados, backup e portas locais. RunId=$RunId"
if($warnings.Count){Write-Warning ($warnings -join ' ')}
Write-Output "Relatorio: avaliacao/atualizacao-1525/$reportReference"

