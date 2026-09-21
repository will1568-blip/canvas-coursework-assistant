$CanvasOrigin = 'https://miamioh.instructure.com'
function Assert-CanvasReadPath([string]$Path) {
    if ($Path.Length -gt 3000 -or $Path -match '[\r\n\\#]' -or $Path -match '(?i)%2f|%5c|%2e|%00') { throw 'Invalid path.' }
    $parts = $Path.Split('?', 2)
    $allowed = '^/api/v1/(users/self/profile|courses|announcements|planner/items|courses/[0-9]+(?:/(?:assignments(?:/[0-9]+(?:/submissions/self)?)?|modules(?:/[0-9]+/items)?|pages(?:/[A-Za-z0-9_-]+)?|front_page|files(?:/[0-9]+)?|discussion_topics(?:/[0-9]+(?:/entries)?)?))?|files/[0-9]+)$'
    if ($parts[0] -notmatch $allowed) { throw 'This endpoint is not enabled for read-only coursework access.' }
    if ($parts.Count -gt 1) {
        foreach ($pair in ($parts[1] -split '&')) {
            $key = [uri]::UnescapeDataString(($pair -split '=', 2)[0])
            if ($key -notin @('page','per_page','include[]','enrollment_type','enrollment_state','state[]','context_codes[]','start_date','end_date','only_announcements','order_by','sort','search_term','bucket','published','filter','filter[]')) { throw 'Unsupported query parameter.' }
        }
    }
    $uri = [uri]($CanvasOrigin + $Path)
    if ($uri.Scheme -ne 'https' -or $uri.Authority -ne 'miamioh.instructure.com') { throw 'Unexpected destination.' }
}
function Invoke-CanvasRead([string]$Path, [hashtable]$Headers) {
    Assert-CanvasReadPath $Path
    $next = $CanvasOrigin + $Path
    $results = [System.Collections.Generic.List[object]]::new()
    $seen = @{}
    for ($page = 0; $next; $page++) {
        if ($page -ge 20 -or $seen.ContainsKey($next)) { throw 'Pagination limit reached; response is incomplete.' }
        $seen[$next] = $true
        $uri = [uri]$next
        if ($uri.Scheme -ne 'https' -or $uri.Authority -ne 'miamioh.instructure.com') { throw 'Unexpected pagination destination.' }
        Assert-CanvasReadPath $uri.PathAndQuery
        $r = Invoke-WebRequest -Uri $uri -Headers $Headers -Method Get -MaximumRedirection 0 -UseBasicParsing -TimeoutSec 30
        foreach ($item in @((ConvertFrom-Json -InputObject $r.Content))) { if ($null -ne $item) { $results.Add($item) } }
        $next = $null
        foreach ($link in (($r.Headers['Link'] -join ',') -split ',')) {
            if ($link -match '<([^>]+)>;\s*rel="next"') { $next = $Matches[1] }
        }
    }
    return $results.ToArray()
}
function Write-BridgeJson([string]$Path, $Value) {
    $temp = $Path + '.tmp'
    $Value | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

