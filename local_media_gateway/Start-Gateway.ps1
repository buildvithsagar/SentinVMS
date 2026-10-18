param(
    [string]$HostIp,
    [string]$GatewayToken = ''
)

$ErrorActionPreference = 'Stop'
$gatewayRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $gatewayRoot
$envPath = Join-Path $gatewayRoot '.env'

if (-not (Get-Command docker.exe -ErrorAction SilentlyContinue)) {
    throw 'Docker CLI was not found. Install or start Docker Desktop, then retry.'
}

docker version --format '{{.Server.Version}}' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop engine is not ready. Start Docker Desktop and wait until it reports Engine running.'
}

if (-not $HostIp) {
    $HostIp = Get-NetIPConfiguration |
        Where-Object {
            $_.NetAdapter.Status -eq 'Up' -and
            $_.IPv4DefaultGateway -and
            $_.IPv4Address.IPAddress -notlike '127.*' -and
            $_.IPv4Address.IPAddress -notlike '169.254.*' -and
            $_.InterfaceAlias -notlike '*WSL*' -and
            $_.InterfaceAlias -notlike '*vEthernet*' -and
            $_.InterfaceAlias -notlike '*VMware*' -and
            $_.InterfaceAlias -notlike '*VirtualBox*'
        } |
        Sort-Object { $_.NetAdapter.InterfaceMetric } |
        Select-Object -First 1 -ExpandProperty IPv4Address |
        Select-Object -ExpandProperty IPAddress
}

if (-not $HostIp) {
    throw 'Unable to detect a LAN IPv4 address. Pass -HostIp explicitly.'
}

if (-not $GatewayToken) {
    if (Test-Path -LiteralPath $envPath) {
        $existingTokenLine = Get-Content -LiteralPath $envPath |
            Where-Object { $_ -match '^SENTINVMS_GATEWAY_TOKEN=' } |
            Select-Object -First 1
        if ($existingTokenLine) {
            $GatewayToken = ($existingTokenLine -split '=', 2)[1].Trim()
        }
    }
}

if (-not $GatewayToken) {
    $tokenBytes = New-Object byte[] 32
    $tokenGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $tokenGenerator.GetBytes($tokenBytes)
    }
    finally {
        $tokenGenerator.Dispose()
    }
    $GatewayToken = [BitConverter]::ToString($tokenBytes).Replace('-', '').ToLowerInvariant()
}

@(
    "SENTINVMS_HOST_IP=$HostIp"
    "SENTINVMS_GATEWAY_TOKEN=$GatewayToken"
) | Set-Content -LiteralPath $envPath -Encoding utf8

Write-Host "Starting SentinVMS gateway on LAN IP $HostIp..." -ForegroundColor Cyan
docker compose up --build -d --force-recreate --wait --wait-timeout 120
if ($LASTEXITCODE -ne 0) {
    docker compose ps
    docker compose logs --tail 80 gateway mediamtx
    throw 'Gateway containers did not become healthy within 120 seconds.'
}

$headers = @{ Authorization = "Bearer $GatewayToken" }
$healthRequest = @{
    Uri        = "http://${HostIp}:8090/health"
    Headers    = $headers
    TimeoutSec = 10
}
$health = Invoke-RestMethod @healthRequest
if ($health.status -ne 'ok') {
    throw 'Gateway health endpoint returned an unexpected response.'
}

docker compose ps
Write-Host 'Gateway health: OK' -ForegroundColor Green
Write-Host "Gateway API: http://${HostIp}:8090" -ForegroundColor Green
Write-Host "Gateway token: $GatewayToken" -ForegroundColor Yellow
Write-Host "MediaMTX HLS: http://${HostIp}:8888" -ForegroundColor Green
Write-Host "MediaMTX WHEP: http://${HostIp}:8889/<stream-id>/whep" -ForegroundColor Green
Write-Host 'Use the same Wi-Fi/hotspot on the phone and keep H.265 compatibility enabled.' -ForegroundColor Cyan
