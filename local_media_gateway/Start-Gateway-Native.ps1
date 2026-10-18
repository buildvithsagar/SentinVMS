param(
    [string]$HostIp,
    [string]$GatewayToken = '',
    [string]$FfmpegPath = '',
    [string]$FfprobePath = ''
)

$ErrorActionPreference = 'Stop'
$gatewayRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$statePath = Join-Path $gatewayRoot '.native-gateway.json'
$logsRoot = Join-Path $gatewayRoot 'build\native-logs'

if (Test-Path -LiteralPath $statePath) {
    throw 'A native gateway state file already exists. Run .\Stop-Gateway-Native.ps1 first.'
}

if (-not $HostIp) {
    $HostIp = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.InterfaceAlias -notlike '*WSL*' -and
            $_.InterfaceAlias -notlike '*vEthernet*'
        } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1 -ExpandProperty IPAddress
}
if (-not $HostIp) {
    throw 'Unable to detect a LAN IPv4 address. Pass -HostIp explicitly.'
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

$mediaMtxExe = Get-ChildItem -LiteralPath (Join-Path $gatewayRoot '.tools\mediamtx') -Filter 'mediamtx.exe' -Recurse -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
if (-not $mediaMtxExe) {
    throw 'MediaMTX is missing. Run .\Install-Gateway-Tools.ps1 first.'
}

if (-not $FfmpegPath) {
    $ffmpegCommand = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    if ($ffmpegCommand) { $FfmpegPath = $ffmpegCommand.Source }
}
if (-not $FfprobePath) {
    $ffprobeCommand = Get-Command ffprobe.exe -ErrorAction SilentlyContinue
    if ($ffprobeCommand) { $FfprobePath = $ffprobeCommand.Source }
}
if (-not $FfmpegPath -or -not (Test-Path -LiteralPath $FfmpegPath)) {
    throw 'ffmpeg.exe is missing. Open a new PowerShell after installing it, or pass -FfmpegPath.'
}
if (-not $FfprobePath -or -not (Test-Path -LiteralPath $FfprobePath)) {
    throw 'ffprobe.exe is missing. Open a new PowerShell after installing it, or pass -FfprobePath.'
}

$dartCommand = Get-Command dart.exe -ErrorAction SilentlyContinue
if (-not $dartCommand) {
    throw 'dart.exe is missing. Add the Flutter SDK bin directory to PATH.'
}

New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null
$mediaMtxProcess = Start-Process -FilePath $mediaMtxExe `
    -ArgumentList (Join-Path $gatewayRoot 'mediamtx.native.yml') `
    -WorkingDirectory $gatewayRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $logsRoot 'mediamtx.out.log') `
    -RedirectStandardError (Join-Path $logsRoot 'mediamtx.err.log') `
    -PassThru

$env:GATEWAY_BIND_ADDRESS = '0.0.0.0'
$env:GATEWAY_PORT = '8090'
$env:GATEWAY_ADVERTISED_HOST = $HostIp
$env:GATEWAY_API_TOKEN = $GatewayToken
$env:FFMPEG_PATH = $FfmpegPath
$env:FFPROBE_PATH = $FfprobePath
$env:MEDIAMTX_RTSP_BASE = 'rtsp://127.0.0.1:8554'
$env:MEDIAMTX_HLS_BASE = 'http://127.0.0.1:8888'
$env:PUBLIC_HLS_PORT = '8888'
$env:PUBLIC_WEBRTC_PORT = '8889'
$env:MAX_STREAMS = '4'
$env:STREAM_TTL_MINUTES = '30'

try {
    $gatewayProcess = Start-Process -FilePath $dartCommand.Source `
        -ArgumentList @('run', 'bin/server.dart') `
        -WorkingDirectory $gatewayRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $logsRoot 'gateway.out.log') `
        -RedirectStandardError (Join-Path $logsRoot 'gateway.err.log') `
        -PassThru
}
catch {
    Stop-Process -Id $mediaMtxProcess.Id -Force -ErrorAction SilentlyContinue
    throw
}

Start-Sleep -Seconds 2
if ($mediaMtxProcess.HasExited -or $gatewayProcess.HasExited) {
    Stop-Process -Id $mediaMtxProcess.Id,$gatewayProcess.Id -Force -ErrorAction SilentlyContinue
    throw "Native gateway failed to start. Inspect $logsRoot."
}

@{
    startedAt = (Get-Date).ToString('o')
    hostIp = $HostIp
    gatewayToken = $GatewayToken
    mediaMtxPid = $mediaMtxProcess.Id
    mediaMtxPath = $mediaMtxExe
    gatewayPid = $gatewayProcess.Id
    gatewayPath = $dartCommand.Source
} | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding utf8

Write-Host 'SentinVMS native gateway is running.' -ForegroundColor Green
Write-Host "Gateway API: http://${HostIp}:8090" -ForegroundColor Green
Write-Host "Gateway token: $GatewayToken" -ForegroundColor Yellow
Write-Host "Logs: $logsRoot" -ForegroundColor DarkGray
