param(
    [string]$GatewayUrl = '',
    [string]$GatewayToken = ''
)

$ErrorActionPreference = 'Stop'
$gatewayRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$envPath = Join-Path $gatewayRoot '.env'

if (Test-Path -LiteralPath $envPath) {
    $environment = @{}
    foreach ($line in Get-Content -LiteralPath $envPath) {
        if ($line -match '^([^#=]+)=(.*)$') {
            $environment[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
    if (-not $GatewayUrl -and $environment.SENTINVMS_HOST_IP) {
        $GatewayUrl = "http://$($environment.SENTINVMS_HOST_IP):8090"
    }
    if (-not $GatewayToken -and $environment.SENTINVMS_GATEWAY_TOKEN) {
        $GatewayToken = $environment.SENTINVMS_GATEWAY_TOKEN
    }
}

if (-not $GatewayUrl) {
    throw 'Gateway URL is unavailable. Start the gateway or pass -GatewayUrl.'
}

$baseUri = [Uri]$GatewayUrl
$headers = @{}
if ($GatewayToken) {
    $headers.Authorization = "Bearer $GatewayToken"
}

$healthRequest = @{
    Uri        = [Uri]::new($baseUri, '/health')
    Headers    = $headers
    TimeoutSec = 10
}
$health = Invoke-RestMethod @healthRequest

$ports = 8090, 8888, 8889, 8189
$results = foreach ($port in $ports) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $connected = $client.ConnectAsync($baseUri.Host, $port).Wait(3000)
        [pscustomobject]@{ Port = $port; Reachable = $connected -and $client.Connected }
    }
    catch {
        [pscustomobject]@{ Port = $port; Reachable = $false }
    }
    finally {
        $client.Dispose()
    }
}

Write-Host "Gateway health: $($health.status)" -ForegroundColor Green
Write-Host "Active streams: $($health.active_streams)" -ForegroundColor Cyan
$results | Format-Table -AutoSize

if ($results.Where({ -not $_.Reachable }).Count -gt 0) {
    throw 'One or more phone-facing gateway ports are unreachable.'
}

Write-Host 'LAN preflight passed. The phone can use this gateway URL when connected to the same network:' -ForegroundColor Green
Write-Host $GatewayUrl -ForegroundColor Yellow
