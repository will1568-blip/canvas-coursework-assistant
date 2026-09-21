$ErrorActionPreference = 'Stop'
$secretPath = Join-Path $PSScriptRoot '../work/canvas-token.xml'
New-Item -ItemType Directory -Force -Path (Split-Path $secretPath) | Out-Null
$token = Read-Host 'Paste your Canvas access token (input is hidden)' -AsSecureString
if ($token.Length -eq 0) { throw 'No token entered.' }
$token | Export-Clixml -LiteralPath $secretPath
Write-Host 'Token saved encrypted for your Windows account. Testing Canvas access...'
& (Join-Path $PSScriptRoot 'Read-Canvas.ps1') -ApiPath '/api/v1/users/self/profile'

