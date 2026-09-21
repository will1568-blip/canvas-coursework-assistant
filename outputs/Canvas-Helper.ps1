$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Canvas-Bridge-Core.ps1')
$bridge = Join-Path $PSScriptRoot '../work/canvas-bridge'
New-Item -ItemType Directory -Force -Path $bridge | Out-Null
$lock = $null
$headers = @{}
try {
    try { $lock = [System.IO.File]::Open((Join-Path $bridge 'helper.lock'), 'OpenOrCreate', 'ReadWrite', 'None') } catch { exit }
    $stop = Join-Path $bridge 'stop'
    if (Test-Path -LiteralPath $stop) { Remove-Item -LiteralPath $stop }
    try {
        $secure = Import-Clixml -LiteralPath (Join-Path $PSScriptRoot '../work/canvas-token.xml')
        $cred = [System.Net.NetworkCredential]::new('', $secure)
        $headers.Authorization = 'Bearer ' + $cred.Password
        $secure = $null; $cred = $null
    } catch {
        Write-BridgeJson (Join-Path $bridge 'status.json') @{state='error';reason='Token could not be unlocked. Start this helper from the Windows account that saved the token.';timestamp=[DateTime]::UtcNow.ToString('o')}
        exit 2
    }
    while (!(Test-Path -LiteralPath $stop)) {
        Write-BridgeJson (Join-Path $bridge 'status.json') @{state='ready';pid=$PID;timestamp=[DateTime]::UtcNow.ToString('o')}
        foreach ($file in (Get-ChildItem -LiteralPath $bridge -Filter '*.request.json')) {
            $id = $file.Name -replace '\.request\.json$', ''
            if ($id -notmatch '^[a-f0-9]{32}$') { continue }
            $output = Join-Path $bridge ($id + '.response.json')
            try {
                if ($file.Length -gt 8192) { throw 'Request too large.' }
                $request = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
                if ($request.id -ne $id) { throw 'Invalid request ID.' }
                $age = ([DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse($request.created_at)).TotalSeconds
                if ($age -gt 120 -or $age -lt -30) { throw 'Expired request.' }
                Assert-CanvasReadPath ([string]$request.path)
                $data = @(Invoke-CanvasRead ([string]$request.path) $headers)
                Write-BridgeJson $output @{id=$id;available=$true;source='Canvas live API';retrieved_at=[DateTime]::UtcNow.ToString('o');data=$data}
            } catch {
                $http = $null
                if ($_.Exception.Response) { $http = [int]$_.Exception.Response.StatusCode }
                Write-BridgeJson $output @{id=$id;available=$false;http_status=$http;reason='Read failed: invalid or expired request, API access error, network failure, or pagination limit. No complete result returned.';retrieved_at=[DateTime]::UtcNow.ToString('o')}
            }
            Remove-Item -LiteralPath $file.FullName
        }
        Start-Sleep -Milliseconds 500
    }
    Write-BridgeJson (Join-Path $bridge 'status.json') @{state='stopped';timestamp=[DateTime]::UtcNow.ToString('o')}
} finally {
    $headers.Clear()
    if ($lock) { $lock.Dispose() }
}

