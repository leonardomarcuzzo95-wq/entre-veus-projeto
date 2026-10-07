param([Parameter(Mandatory)][string]$ReportPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Verify-Upgrade.ps1') -ChecksOnly
$raw=Get-Content -LiteralPath $ReportPath -Raw
$baseline=$raw | ConvertFrom-Json -DateKind String
if(@(Get-EvidenceValidationFailures $baseline).Count){throw 'Baseline real nao passou; testes negativos nao podem mascarar isso.'}
$results=[Collections.Generic.List[object]]::new()
foreach($xp in @(0,99,101,$null)){
    $copy=$raw | ConvertFrom-Json -DateKind String
    $copy.persistedQA.experience=$xp
    $errors=@(Get-EvidenceValidationFailures $copy)
    if(-not @($errors | Where-Object {$_ -like '*exatamente 100 XP*'}).Count){throw 'XP incorreto nao foi rejeitado.'}
    $results.Add(@{case="persisted XP $(if($null -eq $xp){'missing'}else{$xp})";rejected=$true})
}
foreach($caseName in @('stale','wrong-run','missing-timestamp','wrong-order-summary')){
    $copy=$raw | ConvertFrom-Json -DateKind String
    switch($caseName){
        'stale' {$copy.freshEvidence=$false}
        'wrong-run' {$copy.launcherObservation.events[0].runId='different-run'}
        'missing-timestamp' {$copy.launcherObservation.events[0].timestamp=$null}
        'wrong-order-summary' {$copy.launcherObservation.eventSummary.errorOrder='error_after_success'}
    }
    if(-not @(Get-EvidenceValidationFailures $copy).Count){throw "Caso negativo nao rejeitado: $caseName"}
    $results.Add(@{case=$caseName;rejected=$true})
}
$report=@{kind='synthetic-negative-validator-tests';noDatabaseMutation=$true;sourceRunId=$baseline.runId;checkedAt=[datetime]::UtcNow.ToString('o');baselineAccepted=$true;cases=$results.ToArray()}
$output=Join-Path (Split-Path $ReportPath) 'validacao-negativa.json'
if(Test-Path -LiteralPath $output){throw 'Evidencia de testes negativos ja existe; preservar antes de repetir.'}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $output -Encoding utf8
Write-Output 'PASS: baseline real + oito casos negativos, sem alterar banco ou repetir missao.'

