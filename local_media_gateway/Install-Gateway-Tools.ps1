param(
    [switch]$SkipFfmpeg
)

$ErrorActionPreference = 'Stop'
$gatewayRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolsRoot = Join-Path $gatewayRoot '.tools'
$mediaMtxRoot = Join-Path $toolsRoot 'mediamtx'

New-Item -ItemType Directory -Path $toolsRoot -Force | Out-Null

if (-not $SkipFfmpeg) {
    $ffmpeg = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    if (-not $ffmpeg) {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if (-not $winget) {
            throw 'winget is unavailable. Install Microsoft App Installer, then run this script again.'
        }
        Write-Host 'Installing the FFmpeg Essentials build for the current user...' -ForegroundColor Cyan
        & $winget.Source install --exact --id Gyan.FFmpeg --scope user --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            throw "winget could not install FFmpeg (exit code $LASTEXITCODE)."
        }
    }
}

Write-Host 'Downloading the latest official MediaMTX Windows binary...' -ForegroundColor Cyan
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/bluenviron/mediamtx/releases/latest' -Headers @{
    Accept = 'application/vnd.github+json'
    'User-Agent' = 'SentinVMS-Gateway-Installer'
}
$asset = $release.assets |
    Where-Object { $_.name -match 'windows_amd64\.zip$' } |
    Select-Object -First 1
if (-not $asset) {
    throw 'The latest MediaMTX release does not contain a Windows amd64 archive.'
}

$archivePath = Join-Path $toolsRoot $asset.name
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archivePath
if (Test-Path -LiteralPath $mediaMtxRoot) {
    Remove-Item -LiteralPath $mediaMtxRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $mediaMtxRoot -Force | Out-Null
Expand-Archive -LiteralPath $archivePath -DestinationPath $mediaMtxRoot -Force
Remove-Item -LiteralPath $archivePath -Force

$mediaMtxExe = Get-ChildItem -LiteralPath $mediaMtxRoot -Filter 'mediamtx.exe' -Recurse |
    Select-Object -First 1
if (-not $mediaMtxExe) {
    throw 'MediaMTX archive was downloaded but mediamtx.exe was not found.'
}

Write-Host "MediaMTX ready: $($mediaMtxExe.FullName)" -ForegroundColor Green
Write-Host 'FFmpeg is installed. Open a new PowerShell window if it is not yet on PATH.' -ForegroundColor Green
Write-Host 'Next: .\Start-Gateway-Native.ps1' -ForegroundColor Yellow
