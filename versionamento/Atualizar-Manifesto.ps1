$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
[xml]$allow=Get-Content -LiteralPath (Join-Path $root 'versionamento/arquivos-publicos.xml') -Raw
$doc=[Xml.XmlDocument]::new()
[void]$doc.AppendChild($doc.CreateXmlDeclaration('1.0','UTF-8',$null))
$manifest=$doc.CreateElement('manifesto');$manifest.SetAttribute('versao','1.2');$manifest.SetAttribute('projeto','Entre Véus');$manifest.SetAttribute('algoritmo','SHA-256')
[void]$doc.AppendChild($manifest)
$scope=$doc.CreateElement('escopo');$scope.InnerText='Integridade dos arquivos publicos versionados; este manifesto nao calcula hash de si mesmo. Nao constitui evidencia de gameplay nem assinatura digital.';[void]$manifest.AppendChild($scope)
foreach($entry in ($allow.publicacao.arquivo | Sort-Object caminho)){
    $relative=[string]$entry.caminho
    if($relative -eq 'MANIFESTO.xml'){continue}
    if($relative -match '(^|/)\.\.?(/|$)|\\|:' -or [IO.Path]::IsPathRooted($relative)){throw 'Caminho invalido na lista publica.'}
    $full=Join-Path $root $relative
    $file=$doc.CreateElement('arquivo');$file.SetAttribute('caminho',$relative)
    $file.SetAttribute('bytes',[string](Get-Item -LiteralPath $full).Length)
    $file.SetAttribute('sha256',(Get-FileHash -LiteralPath $full).Hash.ToLowerInvariant())
    [void]$manifest.AppendChild($file)
}
$settings=[Xml.XmlWriterSettings]::new();$settings.Indent=$true;$settings.Encoding=[Text.UTF8Encoding]::new($false)
$writer=[Xml.XmlWriter]::Create((Join-Path $root 'MANIFESTO.xml'),$settings)
try{$doc.Save($writer)}finally{$writer.Dispose()}
Write-Output 'Manifesto atualizado; ainda e necessario revisar e validar o index antes do envio.'
