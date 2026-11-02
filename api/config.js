// Vercel 배포용 /api/config — 로컬의 serve.ps1이 하던 일을 대신한다
// 공개 사이트이므로 Project URL과 anon 키만 넘긴다. service_role 키는 절대 넘기지 않는다 (→ 조회 전용)
// 값은 Vercel 대시보드 → Project Settings → Environment Variables 에 넣는다
module.exports = (req, res) => {
  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  if (!url || !anonKey) {
    res.statusCode = 500;
    res.end(JSON.stringify({ error: "Vercel 환경 변수 SUPABASE_URL 또는 SUPABASE_ANON_KEY가 비어 있습니다" }));
    return;
  }
  res.statusCode = 200;
  res.end(JSON.stringify({ url, anonKey, serviceRoleKey: null }));
};
