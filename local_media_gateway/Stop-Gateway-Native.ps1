$ErrorActionPreference = 'Stop'
$gatewayRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$statePath = Join-Path $gatewayRoot '.native-gateway.json'

if (-not (Test-Path -LiteralPath $statePath)) {
    Write-Host 'No native gateway state file was found.' -ForegroundColor Yellow
    exit 0
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$targets = @(
    @{ Pid = [int]$state.gatewayPid; ExpectedPath = [string]$state.gatewayPath; Name = 'gateway' }
    @{ Pid = [int]$state.mediaMtxPid; ExpectedPath = [string]$state.mediaMtxPath; Name = 'MediaMTX' }
)

foreach ($target in $targets) {
    $process = Get-Process -Id $target.Pid -ErrorAction SilentlyContinue
    if (-not $process) { continue }
    if ($process.Path -ne $target.ExpectedPath) {
        throw "Refusing to stop PID $($target.Pid): it no longer belongs to $($target.Name)."
    }
    Stop-Process -Id $target.Pid -Force
}

Remove-Item -LiteralPath $statePath -Force
Write-Host 'SentinVMS native gateway stopped.' -ForegroundColor Green
