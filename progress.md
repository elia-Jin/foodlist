# 진행 상황

마지막 갱신: 2026-11-02

## 완료

### 1. 가상 상품 10건 → Supabase DB 설계 (`docs/dummy/supabase/`)
- 상품 문서(`docs/dummy/products/`)를 정규화 구조로 정리
  - `products` 1행 + `product_ingredients` · `storage_rules` · `product_notices`(1:N) + `notice_types` 코드표 + `shipping_policies`
  - "없음"(확인됨)과 "모름"(행 없음 · null · '미확인') 구분
  - 점검 뷰 `product_data_check`로 원산지 · 보관방식 · 알레르기 누락 확인
- 파일: `01_schema.sql`, `02_seed.sql`, `03_query_allergens.sql`, `04_update_check_view.sql`, `README.md`
- 검증: 로컬에 PostgreSQL이 없어 **실행 검증 안 함**. 시드 행 수 · 코드값 일관성만 확인
- SQL은 사용자가 직접 실행

### 2. 상품 관리 웹페이지 (`product-admin/`)
- React(CDN, 빌드 없음) 단일 `index.html`. 조회 · 검색(코드/이름/설명, 원재료, 알레르기) · 추가 · 삭제
- 조회는 anon 키, 추가 · 삭제는 service_role 키 필요 (RLS가 읽기만 허용)
- 검증: 가짜 클라이언트로 화면 · 요청 형태 확인. **실제 Supabase 연결은 확인 안 함**

## 미완료 · 결정 필요

- 원문에 없는 정보: 전 상품 `category`, P-0402 원재료 원산지, P-0113 · P-0421 알레르기 함유 정보, P-0113 개봉 전 · P-0318 개봉 후 보관방식
- 옛 엑셀 산출물 `docs/dummy/product_db.xlsx`(신선식품여부 열이 남은 1차 버전), `docs/dummy/product_db_fields.md`(엑셀 기준 설명) — Supabase로 전환해 더 이상 안 씀. 삭제 여부 미정
- `01_schema.sql`은 재실행 시 "already exists" 오류. 재실행용 drop 구문은 넣지 않음
- 웹페이지에 상품 수정 기능 없음

## 환경 메모

- 이 PC에 Python · Node.js · PostgreSQL 없음. 엑셀(16.0)은 있음 → 엑셀 자동화는 PowerShell COM으로 가능
- PowerShell COM으로 엑셀에 쓸 때 첫 쓰기를 문자열로 하면 이후 2차원 배열 쓰기가 실패함 (엑셀 2차 버전 생성이 이 오류로 중단됨)
