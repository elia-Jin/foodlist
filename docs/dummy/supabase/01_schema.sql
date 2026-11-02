-- 상품 DB 스키마 (실습용 가상 상품 10건 기준)
-- Supabase SQL Editor에서 01_schema.sql → 02_seed.sql 순서로 실행

-- ---------- 코드값 ----------

-- 보관 시점: 개봉 전 / 개봉 후 / 수령 후(개봉 개념이 없는 농산물)
create type storage_phase as enum ('unopened', 'opened', 'received');

-- 보관방식: 상온(15~25℃) / 실온(1~35℃) / 냉장 / 냉동 — 식품 표시 기준상 상온과 실온은 다름
create type storage_type as enum ('room_temp', 'ambient', 'refrigerated', 'frozen');

-- 기간 단위
create type period_unit as enum ('day', 'week', 'month');

-- 주의사항 유형은 늘어날 수 있으므로 enum 대신 코드 테이블로 관리
create table notice_types (
  code  text primary key,
  label text not null unique   -- 화면 표시용 한글 이름
);

comment on table notice_types is '주의사항 유형 코드표';

-- ---------- 상품 ----------

create table products (
  id          text primary key check (id ~ '^P-[0-9]{4}$'),   -- 상품코드 (예: P-0113)
  name        text not null,
  category    text,                                           -- 분류 (원문에 없음, 직접 입력)
  net_amount  numeric(10, 2) not null check (net_amount > 0), -- 용량
  unit        text not null check (unit in ('g', 'kg', 'ml')),
  pack_count  text,                                           -- 입수 (30포, 20개 등)
  price       integer not null check (price >= 0),            -- 가격 (원)
  description text,
  sale_period text,                                           -- 판매기간 (기간 한정 상품만)
  created_at  timestamptz not null default now()
);

comment on table products is '상품 기본 정보. 모든 상품에 항상 있는 값만 둔다';

-- ---------- 원재료 (상품 1 : N) ----------

create table product_ingredients (
  id         bigint generated always as identity primary key,
  product_id text not null references products (id) on delete cascade,
  ingredient text not null,
  origin     text,          -- null = 원문에 원산지 표기 없음
  ratio      text,          -- 원문에 있을 때만 (예: 100%)
  sort_order smallint not null default 1,
  unique (product_id, ingredient)
);

create index on product_ingredients (product_id);

comment on table product_ingredients is '원재료 1개당 1행';
comment on column product_ingredients.origin is 'null = 원문에 원산지 표기 없음';

-- ---------- 보관규칙 (상품 1 : N) ----------

create table storage_rules (
  id           bigint generated always as identity primary key,
  product_id   text not null references products (id) on delete cascade,
  phase        storage_phase not null,
  storage_type storage_type,              -- null = 원문에 보관방식 표기 없음
  period       integer not null check (period >= 0),   -- 0 = 당일
  period_unit  period_unit not null,
  -- 일 단위 환산 (주 = 7일, 개월 = 30일 근사)
  period_days  integer generated always as (
    case period_unit
      when 'day'   then period
      when 'week'  then period * 7
      when 'month' then period * 30
    end
  ) stored,
  note         text,
  unique (product_id, phase, storage_type)
);

create index on storage_rules (product_id);

comment on table storage_rules is '시점 · 보관방식별 보관 기간. 원문에 정보가 없는 시점은 행을 만들지 않는다';

-- ---------- 주의사항 (상품 1 : N) ----------

create table product_notices (
  id          bigint generated always as identity primary key,
  product_id  text not null references products (id) on delete cascade,
  notice_type text not null references notice_types (code),
  target      text not null,   -- 알레르기 성분, 금지 대상 등. 확인 결과 없으면 '없음'
  detail      text
);

create index on product_notices (product_id);
create index on product_notices (notice_type);

comment on table product_notices is '알레르기 · 교차오염 · 보관금지 · 보관팁 등. 정보가 있을 때만 1행씩';

-- ---------- 배송정책 (전 상품 공통) ----------

create table shipping_policies (
  id        text primary key,   -- SHIP-01 등
  item      text not null,      -- 배송비 / 배송일 / 발송요일
  condition text not null,
  value     text not null
);

comment on table shipping_policies is '전 상품 공통 배송 정책';

-- ---------- 점검 뷰: 원문 확인이 필요한 상품 찾기 ----------

create view product_data_check
with (security_invoker = true) as
select
  p.id,
  p.name,
  (select count(*) from product_ingredients i where i.product_id = p.id)                         as ingredient_count,
  (select count(*) from product_ingredients i where i.product_id = p.id and i.origin is null)    as missing_origin_count,
  (select count(*) from storage_rules s where s.product_id = p.id)                               as storage_rule_count,
  (select count(*) from storage_rules s where s.product_id = p.id and s.storage_type is null)    as missing_storage_type_count,
  (select count(*) from product_notices n where n.product_id = p.id)                             as notice_count,
  exists (select 1 from product_notices n
          where n.product_id = p.id and n.notice_type = 'allergen_contains'
            and n.target <> '미확인')                                                             as allergen_checked
from products p
order by p.id;

comment on view product_data_check is '상품별 정보 누락 점검. allergen_checked = false 이면 알레르기 정보 미확인 (대상이 ''미확인''인 행은 확인으로 치지 않음)';

-- ---------- RLS: 누구나 읽기, 쓰기는 대시보드 · service_role만 ----------

alter table notice_types        enable row level security;
alter table products            enable row level security;
alter table product_ingredients enable row level security;
alter table storage_rules       enable row level security;
alter table product_notices     enable row level security;
alter table shipping_policies   enable row level security;

create policy "공개 읽기" on notice_types        for select to anon, authenticated using (true);
create policy "공개 읽기" on products            for select to anon, authenticated using (true);
create policy "공개 읽기" on product_ingredients for select to anon, authenticated using (true);
create policy "공개 읽기" on storage_rules       for select to anon, authenticated using (true);
create policy "공개 읽기" on product_notices     for select to anon, authenticated using (true);
create policy "공개 읽기" on shipping_policies   for select to anon, authenticated using (true);
