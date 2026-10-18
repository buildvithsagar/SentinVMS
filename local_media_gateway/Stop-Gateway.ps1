$ErrorActionPreference = 'Stop'
$gatewayRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $gatewayRoot
docker compose down
