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
    return 200, (@{ url = $url; anonKey = $anon; serviceRoleKey = $(if ($svc) { $svc } else { $null }) } | ConvertTo-Json -Compress)
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
