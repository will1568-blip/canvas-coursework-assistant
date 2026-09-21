$bridge = Join-Path $PSScriptRoot '../work/canvas-bridge'
New-Item -ItemType Directory -Force -Path $bridge | Out-Null
Set-Content -LiteralPath (Join-Path $bridge 'stop') -Value 'stop'

