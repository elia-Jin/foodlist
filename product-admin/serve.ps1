# product-admin 폴더를 http://localhost:<포트> 로 제공하는 정적 파일 서버 (Node.js 없이 실행)
# 프로젝트 루트의 .env.local을 읽어 /api/config 로 Supabase 연결 정보를 넘겨준다
# 실행: powershell -NoProfile -ExecutionPolicy Bypass -File product-admin/serve.ps1 [-Port 5173]
param([int]$Port = 5173)

$root = [IO.Path]::GetFullPath($PSScriptRoot)
$envPath = Join-Path (Split-Path $root -Parent) ".env.local"
$mime = @{
    ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"
    ".css" = "text/css; charset=utf-8"; ".json" = "application/json; charset=utf-8"
    ".svg" = "image/svg+xml"; ".png" = "image/png"; ".ico" = "image/x-icon"
}

# KEY=VALUE 형식의 env 파일을 읽는다 (# 주석, 따옴표, export 접두 허용)
function Read-EnvFile($path) {
    $vars = @{}
    foreach ($line in [IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8)) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $i = $t.IndexOf("=")
        if ($i -lt 1) { continue }
        $k = $t.Substring(0, $i).Trim()
        if ($k.StartsWith("export ")) { $k = $k.Substring(7).Trim() }
        $v = $t.Substring($i + 1).Trim()
        if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[-1] -eq '"') -or ($v[0] -eq "'" -and $v[-1] -eq "'"))) {
            $v = $v.Substring(1, $v.Length - 2)
        }
        $vars[$k] = $v
    }
    return $vars
}

# /api/config 응답 (상태 코드, JSON 문자열). 요청마다 다시 읽으므로 .env.local 수정 후 새로고침만 하면 됨
function Get-ConfigResponse {
    if (-not (Test-Path $envPath -PathType Leaf)) {
        return 404, (@{ error = ".env.local 파일이 없습니다: $envPath" } | ConvertTo-Json -Compress)
    }
    $e = Read-EnvFile $envPath
    $url = $e["SUPABASE_URL"]; $anon = $e["SUPABASE_ANON_KEY"]; $svc = $e["SUPABASE_SERVICE_ROLE_KEY"]
    if (-not $url -or -not $anon) {
        return 500, (@{ error = ".env.local의 SUPABASE_URL 또는 SUPABASE_ANON_KEY 값이 비어 있습니다" } | ConvertTo-Json -Compress)
    }
    # 예시 문구(<...>)를 그대로 붙여 넣은 경우
    foreach ($pair in @(@("SUPABASE_URL", $url), @("SUPABASE_ANON_KEY", $anon), @("SUPABASE_SERVICE_ROLE_KEY", $svc))) {
        if ($pair[1] -and $pair[1] -match "[<>]") {
            return 500, (@{ error = "$($pair[0])에 예시 문구(<...>)가 들어 있습니다. 대시보드에서 복사한 실제 값으로 바꾸세요" } | ConvertTo-Json -Compress)
        }
    }
    # Postgres 접속 문자열(세션 풀러 등)이나 https가 아닌 주소
    if ($url -notmatch "^https://[^/\s]+/?$") {
        return 500, (@{ error = "SUPABASE_URL 형식이 틀렸습니다. https://<프로젝트>.supabase.co 형태의 Project URL을 넣으세요 (postgres:// 접속 문자열 아님)" } | ConvertTo-Json -Compress)
    }
    # 관리자 키는 브라우저로 보내지 않는다. 있으면 /sb/ 프록시를 쓰라고만 알려준다
    return 200, (@{ url = $url; anonKey = $anon; adminProxy = [bool]$svc } | ConvertTo-Json -Compress)
}

# /sb/rest/v1/... 요청을 관리자 키(secret 또는 service_role)를 붙여 Supabase로 전달한다
# Supabase는 secret 키를 브라우저에서 쓰지 못하게 막으므로, 쓰기는 이 로컬 서버가 대신 보낸다
Add-Type -AssemblyName System.Net.Http
$http = New-Object System.Net.Http.HttpClient
$passHeaders = "Prefer", "Accept", "Range", "Accept-Profile", "Content-Profile"

function Invoke-AdminProxy($req, $res, $rel) {
    $e = Read-EnvFile $envPath
    $url = $e["SUPABASE_URL"]; $svc = $e["SUPABASE_SERVICE_ROLE_KEY"]
    if (-not $url -or -not $svc -or $svc -match "[<>]") {
        $res.StatusCode = 503; $res.ContentType = "application/json; charset=utf-8"
        return [Text.Encoding]::UTF8.GetBytes('{"message":".env.local의 SUPABASE_SERVICE_ROLE_KEY가 비어 있어 추가 · 삭제를 할 수 없습니다"}')
    }
    $target = $url.TrimEnd("/") + "/" + $rel.Substring(3) + $req.Url.Query
    $msg = New-Object System.Net.Http.HttpRequestMessage((New-Object System.Net.Http.HttpMethod($req.HttpMethod)), $target)
    if ($req.HasEntityBody) {
        $ms = New-Object IO.MemoryStream; $req.InputStream.CopyTo($ms)
        $msg.Content = New-Object System.Net.Http.ByteArrayContent(, $ms.ToArray())
        if ($req.ContentType) { $msg.Content.Headers.TryAddWithoutValidation("Content-Type", $req.ContentType) | Out-Null }
    }
    foreach ($h in $passHeaders) { if ($req.Headers[$h]) { $msg.Headers.TryAddWithoutValidation($h, $req.Headers[$h]) | Out-Null } }
    $msg.Headers.TryAddWithoutValidation("apikey", $svc) | Out-Null
    # 예전 JWT 형식 키(eyJ…)만 Authorization에도 넣는다. 새 secret 키(sb_secret_…)는 apikey 헤더만 쓴다
    if ($svc.StartsWith("eyJ")) { $msg.Headers.TryAddWithoutValidation("Authorization", "Bearer $svc") | Out-Null }
    $r = $http.SendAsync($msg).GetAwaiter().GetResult()
    $res.StatusCode = [int]$r.StatusCode
    if ($r.Content.Headers.ContentType) { $res.ContentType = $r.Content.Headers.ContentType.ToString() }
    $cr = $null
    if ($r.Content.Headers.TryGetValues("Content-Range", [ref]$cr) -or $r.Headers.TryGetValues("Content-Range", [ref]$cr)) {
        $res.Headers.Add("Content-Range", ($cr -join ","))
    }
    return $r.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")   # localhost만 열어 외부 접속 차단
$listener.Start()
Write-Host "Serving $root at http://localhost:$Port/"
Write-Host "env: $envPath $(if (Test-Path $envPath) { '(있음)' } else { '(없음)' })"

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $res = $ctx.Response
        try {
            $res.Headers.Add("Cache-Control", "no-store")   # 수정 후 새로고침하면 바로 반영
            $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart("/")
            if ($rel -eq "") { $rel = "index.html" }

            if ($rel -eq "api/config") {
                # 키가 담긴 응답이므로 localhost에서 온 요청만 허용 (CORS 헤더는 주지 않음)
                if (-not $ctx.Request.IsLocal -or $ctx.Request.Url.Host -ne "localhost") {
                    $res.StatusCode = 403; $json = '{"error":"forbidden"}'
                } else {
                    $code, $json = Get-ConfigResponse
                    $res.StatusCode = $code
                }
                $res.ContentType = "application/json; charset=utf-8"
                $bytes = [Text.Encoding]::UTF8.GetBytes($json)
            } elseif ($rel.StartsWith("sb/rest/v1/")) {
                # 관리자 권한으로 DB를 바꾸는 통로이므로 localhost 페이지에서 온 요청만 허용
                # (다른 사이트가 이 주소로 몰래 요청을 보내지 못하도록 Origin도 검사)
                $origin = $ctx.Request.Headers["Origin"]
                if (-not $ctx.Request.IsLocal -or $ctx.Request.Url.Host -ne "localhost" -or
                    ($origin -and $origin -ne "http://localhost:$Port")) {
                    $res.StatusCode = 403; $res.ContentType = "application/json; charset=utf-8"
                    $bytes = [Text.Encoding]::UTF8.GetBytes('{"message":"forbidden"}')
                } else {
                    $bytes = Invoke-AdminProxy $ctx.Request $res $rel
                }
            } else {
                $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
                $name = [IO.Path]::GetFileName($full)
                $ext = [IO.Path]::GetExtension($full).ToLower()
                # 폴더 밖 파일(../), 숨김 파일(.env 등), .ps1 · .md는 제공하지 않음
                if (-not $full.StartsWith($root + [IO.Path]::DirectorySeparatorChar) -or $name.StartsWith(".") -or
                    -not (Test-Path $full -PathType Leaf) -or $ext -in ".ps1", ".md") {
                    $res.StatusCode = 404
                    $bytes = [Text.Encoding]::UTF8.GetBytes("404 Not Found")
                } else {
                    $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
                    $bytes = [IO.File]::ReadAllBytes($full)
                }
            }
            # 로그에는 경로와 상태만 남긴다 (키 값은 출력하지 않음)
            Write-Host "$($ctx.Request.HttpMethod) /$rel $($res.StatusCode)"
            $res.ContentLength64 = $bytes.Length
            # HEAD 요청은 본문 없이 헤더만 보낸다
            if ($ctx.Request.HttpMethod -ne "HEAD") { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
        } catch {
            Write-Host "error: $($_.Exception.Message)"
        } finally {
            $res.Close()
        }
    }
} finally {
    $listener.Stop()
}
