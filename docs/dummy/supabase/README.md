# 상품 DB — Supabase 스키마 (실습용)

- 대상: `docs/dummy/products/` 가상 상품 10건. 모든 값은 가상 데이터이므로 실제 프로젝트에 섞지 않는다
- 실행: Supabase 대시보드 → SQL Editor에서 `01_schema.sql` → `02_seed.sql` 순서로 실행
  - `03_query_allergens.sql`: 알레르기 상품 조회 쿼리 모음 (필요할 때 실행)
  - `04_update_check_view.sql`: 01을 **수정 전에 이미 실행한 경우에만** 실행. 점검 뷰가 '미확인' 행을 미확인으로 세도록 바꿈
- 검증 상태: 로컬에 PostgreSQL이 없어 **실행 검증은 하지 않음**. 시드 행 수와 코드값 일관성만 확인

## 구조

```
products (상품 1행)
 ├─ product_ingredients  원재료 1개당 1행
 ├─ storage_rules        시점 · 보관방식별 1행
 └─ product_notices      주의사항 1건당 1행 ── notice_types (유형 코드표)
shipping_policies        전 상품 공통 배송 정책
product_data_check       (뷰) 상품별 정보 누락 점검
```

자식 테이블은 `product_id`로 `products`를 참조하고, 상품을 지우면 함께 지워진다(`on delete cascade`).

## 테이블 정의

### products — 상품

| 컬럼 | 타입 | 필수 | 설명 |
|---|---|---|---|
| id | text | PK | 상품코드. `P-0000` 형식 검사 |
| name | text | O | 상품명 |
| category | text | | 분류. 원문에 없어 지금은 전부 null |
| net_amount | numeric(10,2) | O | 용량 (0보다 큼) |
| unit | text | O | `g` / `kg` / `ml` |
| pack_count | text | | 입수 (30포, 20개 등) |
| price | integer | O | 가격(원), 0 이상 |
| description | text | | 상품설명 |
| sale_period | text | | 판매기간 (기간 한정 상품만) |
| created_at | timestamptz | O | 기본값 now() |

### product_ingredients — 원재료

| 컬럼 | 타입 | 필수 | 설명 |
|---|---|---|---|
| id | bigint | PK | 자동 증가 |
| product_id | text | O | → products.id |
| ingredient | text | O | 원재료명. 같은 상품 안에서 중복 불가 |
| origin | text | | 원산지. **null = 원문에 표기 없음** |
| ratio | text | | 비율 (원문에 있을 때만) |
| sort_order | smallint | O | 표시 순서 |

### storage_rules — 보관규칙

| 컬럼 | 타입 | 필수 | 설명 |
|---|---|---|---|
| id | bigint | PK | 자동 증가 |
| product_id | text | O | → products.id |
| phase | storage_phase | O | `unopened` 개봉 전 / `opened` 개봉 후 / `received` 수령 후 |
| storage_type | storage_type | | `room_temp` 상온 / `ambient` 실온 / `refrigerated` 냉장 / `frozen` 냉동. **null = 원문에 표기 없음** |
| period | integer | O | 기간. 0 = 당일 |
| period_unit | period_unit | O | `day` / `week` / `month` |
| period_days | integer | 자동 | 일 단위 환산 (주 = 7일, 개월 = 30일 근사). 생성 컬럼 |
| note | text | | 메모 |

원문에 정보가 없는 시점은 행을 만들지 않는다 (예: P-0421 개봉 전).

### product_notices — 주의사항

| 컬럼 | 타입 | 필수 | 설명 |
|---|---|---|---|
| id | bigint | PK | 자동 증가 |
| product_id | text | O | → products.id |
| notice_type | text | O | → notice_types.code |
| target | text | O | 알레르기 성분, 금지 대상 등. 확인 결과 없으면 `없음` |
| detail | text | | 내용 |

### notice_types — 주의사항 유형 코드표

| code | label |
|---|---|
| allergen_contains | 알레르기함유 |
| allergen_free | 알레르기미함유 |
| cross_contact | 교차오염 |
| storage_prohibited | 보관금지 |
| cooking_prohibited | 조리금지 |
| intake_caution | 섭취주의 |
| storage_tip | 보관팁 |
| cooking_guide | 조리안내 |

새 유형은 이 테이블에 행만 추가하면 된다 (enum과 달리 스키마 변경 불필요).

### shipping_policies — 배송정책

| 컬럼 | 타입 | 필수 | 설명 |
|---|---|---|---|
| id | text | PK | SHIP-01 등 |
| item | text | O | 배송비 / 배송일 / 발송요일 |
| condition | text | O | 조건 |
| value | text | O | 값 |

## "없음"과 "모름" 구분 규칙

| 상황 | 기록 방법 |
|---|---|
| 확인했는데 알레르기 유발 물질이 없음 | `product_notices`에 `allergen_contains / 없음` 1행 |
| 알레르기 정보를 아직 모름 | 행을 만들지 않거나 대상을 `미확인`으로 기록 → 점검 뷰에서 `allergen_checked = false` |
| 원산지를 모름 | `origin = null` |
| 보관방식을 모름 | `storage_type = null` |

## 점검 뷰 사용법

```sql
-- 원문 확인이 필요한 상품만 보기
select * from product_data_check
where missing_origin_count > 0
   or missing_storage_type_count > 0
   or not allergen_checked;
```

현재 데이터 기준으로 확인이 필요한 상품:

| 상품 | 확인 필요 항목 |
|---|---|
| P-0113 대구사과칩 | 알레르기 미확인 (글루텐 없음만 있음), 개봉 전 보관방식 |
| P-0318 흑마늘 진액 | 정제수 원산지, 개봉 후 보관방식 |
| P-0402 서문시장 납작만두 | 원재료 4개 원산지 전부 |
| P-0421 경산 대추칩 | 알레르기 미확인, 개봉 전 보관 정보 없음 |

## 접근 권한 (RLS)

- 모든 테이블에 RLS를 켰고, `anon` · `authenticated`에 **읽기만** 허용
- 추가 · 수정 · 삭제는 Supabase 대시보드(Table Editor)나 `service_role` 키로만 가능
- 앱에서 관리자 화면으로 수정하려면 관리자 역할에 맞는 insert/update/delete 정책을 따로 추가해야 함
