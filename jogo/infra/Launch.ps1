param([ValidateSet('Play','LegacyPlay','Stop','Access')][string]$Action='Play')
$ErrorActionPreference='Stop'
$tools=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'runtime-tools.json') -Raw | ConvertFrom-Json
$shell=$tools.powershell
if (-not (Test-Path -LiteralPath $shell)) {throw 'PowerShell 7 indisponivel. Atualize infra/runtime-tools.json com o caminho de pwsh.exe.'}
switch ($Action) {
    'Play' {$script='Start-Current.ps1'}
    'LegacyPlay' {$script='Start-Client.ps1'}
    'Stop' {$script='Stop-Current.ps1'}
    'Access' {$script='Show-Access.ps1'}
}
& $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $script)
exit $LASTEXITCODE
