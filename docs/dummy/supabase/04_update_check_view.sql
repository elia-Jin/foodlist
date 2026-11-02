-- 점검 뷰 수정: 대상이 '미확인'인 알레르기 행은 확인된 정보로 치지 않는다
-- 01_schema.sql을 이미 실행한 프로젝트에서만 실행 (새로 만드는 경우 01_schema.sql에 이미 반영됨)
-- 테이블 · 데이터는 바꾸지 않고 뷰 정의만 바꾼다

create or replace view product_data_check
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
