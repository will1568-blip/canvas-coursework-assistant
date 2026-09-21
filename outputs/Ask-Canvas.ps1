param(
    [Parameter(Mandatory=$true)][string]$ApiPath,
    [ValidateRange(1,900)][int]$TimeoutSeconds = 90
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Canvas-Bridge-Core.ps1')
Assert-CanvasReadPath $ApiPath
$bridge = Join-Path $PSScriptRoot '../work/canvas-bridge'
$statusPath = Join-Path $bridge 'status.json'
if (!(Test-Path -LiteralPath $statusPath)) { throw 'Canvas helper is not running. Open Start Canvas Helper.' }
$status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
if ($status.state -ne 'ready' -or ([DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse($status.timestamp)).TotalSeconds -gt 90) { throw 'Canvas helper is stopped, unavailable, or busy. Start it or try again shortly.' }
$id = [guid]::NewGuid().ToString('N')
$requestPath = Join-Path $bridge ($id + '.request.json')
$responsePath = Join-Path $bridge ($id + '.response.json')
Write-BridgeJson $requestPath @{id=$id;path=$ApiPath;created_at=[DateTime]::UtcNow.ToString('o')}
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $responsePath) {
        $content = Get-Content -LiteralPath $responsePath -Raw
        $response = $content | ConvertFrom-Json
        if ($response.id -ne $id) { throw 'Unexpected response ID.' }
        Remove-Item -LiteralPath $responsePath
        Write-Output $content
        if (!$response.available) { exit 1 }
        exit 0
    }
    Start-Sleep -Milliseconds 250
}
if (Test-Path -LiteralPath $requestPath) { Remove-Item -LiteralPath $requestPath }
throw 'Canvas helper timed out. No fresh data was returned.'

