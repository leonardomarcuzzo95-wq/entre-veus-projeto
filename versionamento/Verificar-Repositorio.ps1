param([switch]$CheckIndex,[switch]$RequireLua)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion -lt [version]'7.5'){throw 'Use PowerShell 7.5 ou superior.'}
$root=Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    [xml]$allow=Get-Content -LiteralPath 'versionamento/arquivos-publicos.xml' -Raw
    $paths=@($allow.publicacao.arquivo | ForEach-Object {[string]$_.caminho})
    if(@($paths | Sort-Object -Unique).Count -ne $paths.Count){throw 'Caminhos duplicados na lista publica.'}
    if($CheckIndex){
        $tracked=@(& git -c core.quotepath=false ls-files)
        if($LASTEXITCODE -ne 0){throw 'Nao foi possivel ler o index Git.'}
        $difference=@(Compare-Object ($paths | Sort-Object) ($tracked | Sort-Object))
        if($difference.Count){throw ('Index fora da lista publica: '+(($difference | ForEach-Object InputObject) -join ', '))}
    }
    $utf8=[Text.UTF8Encoding]::new($false,$true)
    $counts=@{powershell=0;lua=0;javascript=0;xml=0;json=0}
    $blockedExtensions=@('.exe','.dll','.zip','.7z','.sql','.dump','.db','.sqlite','.log','.pem','.key','.pfx','.dat','.spr','.otbm')
    foreach($path in $paths){
        if($path -match '(^|/)\.\.?(/|$)|\\|:' -or [IO.Path]::IsPathRooted($path)){throw "Caminho invalido: $path"}
        $full=[IO.Path]::GetFullPath((Join-Path $root $path))
        if(-not(Test-Path -LiteralPath $full -PathType Leaf)){throw "Arquivo ausente: $path"}
        if((Get-Item -LiteralPath $full).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Link nao autorizado: $path"}
        $extension=[IO.Path]::GetExtension($path)
        if($extension -in $blockedExtensions -or $path -match '(^|/)(credentials[^/]*|admin\.ini|game-client\.ini|config\.otml|runtime-tools\.json|\.env.*)$'){
            throw "Arquivo privado/gerado nao permitido: $path"
        }
        $content=$utf8.GetString([IO.File]::ReadAllBytes($full))
        if($content.IndexOf([char]0) -ge 0){throw "Arquivo binario inesperado: $path"}
        if($content -match '[A-Za-z]:[\\/]Users[\\/]|github_pat_[A-Za-z0-9_]{15,}|ghp_[A-Za-z0-9]{20,}|BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY|AKIA[0-9A-Z]{16}'){
            throw "Possivel segredo ou caminho pessoal em $path; conteudo omitido."
        }
        switch($extension){
            '.ps1' {
                $tokens=$null;$errors=$null
                [void][Management.Automation.Language.Parser]::ParseFile($full,[ref]$tokens,[ref]$errors)
                if($errors.Count){throw "Erro de sintaxe PowerShell em $path"}
                $counts.powershell++
            }
            '.mjs' { & node --check $full; if($LASTEXITCODE -ne 0){throw "Erro de sintaxe JavaScript em $path"};$counts.javascript++ }
            '.xml' { $xml=[Xml.XmlDocument]::new();$xml.XmlResolver=$null;$xml.LoadXml($content);$counts.xml++ }
            '.json' { [void]($content | ConvertFrom-Json -DateKind String);$counts.json++ }
            '.lua' { $counts.lua++ }
        }
    }
    [xml]$manifest=Get-Content -LiteralPath 'MANIFESTO.xml' -Raw
    $hashPaths=@($manifest.manifesto.arquivo | ForEach-Object {[string]$_.caminho})
    if(Compare-Object ($paths | Where-Object {$_ -ne 'MANIFESTO.xml'} | Sort-Object) ($hashPaths | Sort-Object)){throw 'Manifesto de integridade incompleto.'}
    foreach($item in $manifest.manifesto.arquivo){
        if((Get-FileHash -LiteralPath $item.caminho).Hash.ToLowerInvariant() -ne $item.sha256){throw ('Manifesto desatualizado: '+$item.caminho)}
    }
    [xml]$project=Get-Content -LiteralPath 'projeto.xml' -Raw
    $shares=@($project.dossie.autoria_e_participacao.quadro_societario.participante)
    if([int]($shares | Where-Object id -eq 'fundador').percentual -ne 51 -or [int]($shares | Where-Object id -eq 'demais').percentual -ne 49){throw 'Diretriz societaria alterada.'}
    # Reuse the already implemented validator on a public historical regression fixture.
    # The temp copy prevents overwriting the original evidence or a previous result.
    $temp=Join-Path ([IO.Path]::GetTempPath()) ('entreveus-regression-'+[guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($temp)
    $fixture=Join-Path $temp 'qa-historico.json'
    Copy-Item -LiteralPath 'versionamento/fixtures/qa-2026-10-06.json' -Destination $fixture
    & 'jogo/atualizacao-1525/infra/Test-EvidenceChecks.ps1' -ReportPath $fixture
    $lua=Get-Command luajit,lua5.1,lua -ErrorAction SilentlyContinue | Select-Object -First 1
    $luaStatus='nao executado: interpretador Lua independente ausente'
    if($lua){
        $luaPaths=@($paths | Where-Object {$_ -like '*.lua'})
        & $lua.Source 'versionamento/Verificar-Lua.lua' @luaPaths
        if($LASTEXITCODE -ne 0){throw 'Sintaxe ou regressao Lua falhou.'}
        $luaStatus='passed'
    }elseif($RequireLua){throw 'Lua exigido nesta verificacao, mas indisponivel.'}
    [pscustomobject]@{status='passed';scope='repository-static-and-unit-checks';files=$paths.Count;syntax=$counts;lua=$luaStatus;negativeValidatorCases=8;gameplayExecuted=$false;databaseAccessed=$false} | ConvertTo-Json -Depth 4
}finally{Pop-Location}
