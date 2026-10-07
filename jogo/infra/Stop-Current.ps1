$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot '../atualizacao-1525/infra/Stop-Upgrade.ps1')
& (Join-Path $PSScriptRoot 'Stop-Lab.ps1')
