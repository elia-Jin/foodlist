-- 알레르기 관련 상품 조회 (01_schema.sql, 02_seed.sql 실행 후 사용)
-- 함유(allergen_contains)와 교차오염(cross_contact)을 구분해서 본다

-- ---------- 1) 알레르기 주의가 필요한 상품 목록 ----------
-- 함유 또는 교차오염 정보가 하나라도 있는 상품. '없음' · '미확인'으로 적힌 행은 제외

select
  p.id                                                         as 상품코드,
  p.name                                                       as 상품명,
  string_agg(n.target, ', ' order by n.target)
    filter (where n.notice_type = 'allergen_contains')         as 함유_알레르기,
  string_agg(n.target, ', ' order by n.target)
    filter (where n.notice_type = 'cross_contact')             as 교차오염_주의
from products p
join product_notices n on n.product_id = p.id
where n.notice_type in ('allergen_contains', 'cross_contact')
  and n.target not in ('없음', '미확인')
group by p.id, p.name
order by p.id;

-- 현재 데이터 기준 예상 결과
-- P-0113 대구사과칩        | (null)    | 견과류
-- P-0402 서문시장 납작만두 | 대두, 밀  | 계란
-- P-0421 경산 대추칩       | (null)    | 견과류


-- ---------- 2) 특정 알레르기 성분으로 찾기 ----------
-- '견과류' 자리에 찾을 성분을 넣는다. 함유 · 교차오염 모두 포함

select
  p.id    as 상품코드,
  p.name  as 상품명,
  t.label as 구분,
  n.detail as 내용
from product_notices n
join products p     on p.id = n.product_id
join notice_types t on t.code = n.notice_type
where n.notice_type in ('allergen_contains', 'cross_contact')
  and n.target = '견과류'
order by p.id;


-- ---------- 3) 알레르기 정보가 확인되지 않은 상품 ----------
-- 확인된 함유 정보 행이 하나도 없는 상품 (원문 확인 필요). 위 1)의 결과에 없다고 안전한 상품은 아님
-- '미확인'으로 적힌 행은 확인된 정보로 치지 않는다

select
  p.id   as 상품코드,
  p.name as 상품명
from products p
where not exists (
  select 1 from product_notices n
  where n.product_id = p.id
    and n.notice_type = 'allergen_contains'
    and n.target <> '미확인'
)
order by p.id;

-- 현재 데이터 기준 예상 결과: P-0113 대구사과칩, P-0421 경산 대추칩
