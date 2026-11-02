# 상품 관리 페이지 (로컬 전용)

Supabase에 저장된 상품 정보를 조회 · 검색 · 추가 · 삭제하는 React 페이지.
DB 구조는 `docs/dummy/supabase/01_schema.sql` 기준이다.

## 실행

Node.js 설치나 빌드 없이 `index.html`을 브라우저로 열면 된다 (더블클릭).
React · Supabase 라이브러리는 CDN에서 불러오므로 인터넷 연결은 필요하다.

1. 프로젝트 루트의 `.env.local`에 값 채우기 (Supabase 대시보드 → Project Settings → API)
   ```
   SUPABASE_URL=https://<project-ref>.supabase.co
   SUPABASE_ANON_KEY=<anon public 키>
   SUPABASE_SERVICE_ROLE_KEY=<service_role 키, 비우면 조회 전용>
   ```
2. 로컬 서버 실행
   ```bash
   powershell -NoProfile -ExecutionPolicy Bypass -File product-admin/serve.ps1 -Port 5173
   ```
3. http://localhost:5173 열기 → `.env.local` 값으로 자동 연결 (종료: Ctrl+C)

- `serve.ps1`이 요청마다 `.env.local`을 다시 읽으므로, 값을 바꾼 뒤 "설정 다시 읽기"나 새로고침만 하면 된다
- 세션 풀러 등 Postgres 접속 문자열은 쓰지 않는다. 브라우저는 Supabase REST API(Project URL + 키)로만 접속한다
- `index.html`을 파일로 직접 열면 `.env.local`을 읽을 수 없어 직접 입력 화면이 나온다

## Vercel 배포 (조회 전용)

Root Directory는 바꾸지 않는다 (저장소 루트 그대로). 루트의 `vercel.json`이 `/`를 `product-admin/index.html`로 연결한다.

1. Vercel 프로젝트 → Settings → Environment Variables에 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 두 개만 추가
   - **SUPABASE_SERVICE_ROLE_KEY는 넣지 않는다.** 공개 사이트에서 누구나 DB를 바꿀 수 있게 된다
2. Deployments → 최신 배포 → Redeploy

- 배포 사이트에서는 루트의 `api/config.js`가 URL · anon 키만 넘겨주므로 "조회 전용"으로 동작한다 (추가 · 삭제 불가)
- 추가 · 삭제는 로컬(`serve.ps1`)에서만 한다
- anon 키로 읽을 수 있는 데이터(RLS "공개 읽기")는 누구나 볼 수 있다

## 키 선택

| 변수 | 용도 |
|---|---|
| SUPABASE_ANON_KEY | 조회 · 검색 (RLS가 읽기만 허용) |
| SUPABASE_SERVICE_ROLE_KEY | 추가 · 삭제. 없으면 "조회 전용"으로 동작하고 추가 · 삭제 버튼이 비활성 |

- service_role 키는 RLS를 무시하는 관리자 키다. `.env.local`은 공유 · 업로드하지 않는다
- `serve.ps1`은 localhost 요청에만 `/api/config`(키 포함)를 응답하고, `.env*` 같은 숨김 파일은 제공하지 않는다

## 기능

- **조회**: 상품 목록 → 클릭하면 원재료 · 보관규칙 · 주의사항 상세
- **검색**: 코드 · 이름 · 설명 / 원재료 / 알레르기 성분 (알레르기 검색은 '없음' · '미확인' 제외)
- **추가**: 상품 + 원재료 · 보관규칙 · 주의사항을 한 번에 입력. 중간에 실패하면 상품까지 지워 일부만 저장되지 않게 한다
- **삭제**: 확인 창 → 상품 삭제 시 원재료 · 보관규칙 · 주의사항도 함께 삭제 (되돌릴 수 없음)
- 수정 기능은 없다

## 검증 상태

- 브라우저에서 화면 로드, 목록 · 상세 · 검색 · 추가 화면을 가짜 데이터로 확인
- 실제 Supabase 프로젝트에 연결한 동작은 확인하지 않음
