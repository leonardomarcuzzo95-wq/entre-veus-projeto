$ErrorActionPreference='Stop'
$secretPath=Join-Path $env:LOCALAPPDATA 'EntreVeus1525\credentials.json'
if (-not (Test-Path -LiteralPath $secretPath)) {throw 'Abra Jogar.cmd primeiro para preparar a conta local.'}
$account=Get-Content -LiteralPath $secretPath -Raw | ConvertFrom-Json
Write-Host ''
Write-Host 'ACESSO AO PERSONAGEM VIAJANTE NESTE COMPUTADOR'
Write-Host ('Conta / Email: '+$account.account)
Write-Host ('Senha: '+$account.password)
Write-Host ''
Write-Host 'Servidor: http://127.0.0.1:8090/login | Cliente: 1525 | HTTP: sim'
Write-Host 'Jogar.cmd preenche esses dados e entra automaticamente.'
