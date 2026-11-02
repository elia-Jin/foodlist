-- 실습용 가상 상품 10건 시드 데이터 (출처: docs/dummy/products/)
-- 01_schema.sql 실행 후 실행

-- ---------- 주의사항 유형 ----------

insert into notice_types (code, label) values
  ('allergen_contains',   '알레르기함유'),
  ('allergen_free',       '알레르기미함유'),
  ('cross_contact',       '교차오염'),
  ('storage_prohibited',  '보관금지'),
  ('cooking_prohibited',  '조리금지'),
  ('intake_caution',      '섭취주의'),
  ('storage_tip',         '보관팁'),
  ('cooking_guide',       '조리안내');

-- ---------- 상품 (분류는 원문에 없어 null) ----------

insert into products (id, name, category, net_amount, unit, pack_count, price, description, sale_period) values
  ('P-0113', '대구사과칩',        null,  60, 'g',  null,     4900, '팔공산 사과를 저온에서 말린 과자. 설탕 · 첨가물 없음', null),
  ('P-0127', '팔공산 꿀사과',     null,   2, 'kg', '7~9개', 18000, '팔공산 해발 400m 과수원의 부사. 당도 14Brix 이상 선별. 표면 왁스 코팅 없음', null),
  ('P-0205', '성주 참외',         null, 1.5, 'kg', '5~6개', 12000, '성주 하우스 참외 특품', '4~7월 한정'),
  ('P-0207', '참외청',            null, 350, 'ml', null,     9500, '성주 참외와 비정제 원당을 1:1로 재운 청. 탄산수 희석 비율 1:4', null),
  ('P-0305', '청도 반건시',       null, 500, 'g',  '10개',  15000, '청도 감을 20일 자연 건조한 반건시. 겉은 쫀득, 속은 촉촉. 표면의 흰 가루는 당분이 굳은 것으로 정상', null),
  ('P-0312', '의성 마늘',         null,   1, 'kg', '약 15통', 11000, '의성 한지형 마늘. 알이 단단하고 매운맛이 강함', null),
  ('P-0318', '흑마늘 진액',       null,  70, 'ml', '30포',  24000, '의성 마늘을 15일 숙성한 흑마늘 추출액. 하루 1포 권장', null),
  ('P-0402', '서문시장 납작만두', null, 500, 'g',  '20개',   7900, '서문시장식 납작만두. 당면 · 부추 소, 간장 양념 포함', null),
  ('P-0410', '달성 토마토',       null,   1, 'kg', '6~8개',  8500, '달성군 하빈면 완숙 토마토. 산도가 낮아 생식용', null),
  ('P-0421', '경산 대추칩',       null,  50, 'g',  null,     5500, '경산 대추를 씨 빼고 말린 칩. 차로 우려도 됨', null);

-- ---------- 원재료 (origin null = 원문에 표기 없음) ----------

insert into product_ingredients (product_id, ingredient, origin, ratio, sort_order) values
  ('P-0113', '사과',         '대구 팔공산',       '100%', 1),
  ('P-0127', '사과(부사)',   '대구 팔공산',       null,   1),
  ('P-0205', '참외',         '경북 성주',         null,   1),
  ('P-0207', '참외',         '경북 성주',         null,   1),
  ('P-0207', '비정제 원당',  '국내산',            null,   2),
  ('P-0305', '감',           '경북 청도',         null,   1),
  ('P-0312', '마늘(한지형)', '경북 의성',         null,   1),
  ('P-0318', '흑마늘',       '경북 의성',         null,   1),
  ('P-0318', '정제수',       null,                null,   2),
  ('P-0402', '밀가루',       null,                null,   1),
  ('P-0402', '당면',         null,                null,   2),
  ('P-0402', '부추',         null,                null,   3),
  ('P-0402', '대두(간장)',   null,                null,   4),
  ('P-0410', '토마토',       '대구 달성(하빈면)', null,   1),
  ('P-0421', '대추',         '경북 경산',         '100%', 1);

-- ---------- 보관규칙 (storage_type null = 원문에 표기 없음) ----------

insert into storage_rules (product_id, phase, storage_type, period, period_unit, note) values
  ('P-0113', 'unopened', null,           6,  'month', '유통기한'),
  ('P-0113', 'opened',   'room_temp',    7,  'day',   '밀봉해 서늘한 곳'),
  ('P-0127', 'received', 'refrigerated', 3,  'week',  null),
  ('P-0127', 'received', 'room_temp',    7,  'day',   null),
  ('P-0205', 'received', 'refrigerated', 5,  'day',   null),
  ('P-0207', 'unopened', 'room_temp',    12, 'month', null),
  ('P-0207', 'opened',   'refrigerated', 30, 'day',   null),
  ('P-0305', 'received', 'refrigerated', 10, 'day',   '받은 즉시 냉장'),
  ('P-0312', 'received', 'room_temp',    2,  'month', '통풍이 잘 되는 그늘, 망에 보관'),
  ('P-0318', 'unopened', 'room_temp',    18, 'month', null),
  ('P-0318', 'opened',   null,           0,  'day',   '개봉한 포는 당일 섭취'),
  ('P-0402', 'received', 'frozen',       3,  'month', null),
  ('P-0410', 'received', 'ambient',      3,  'day',   null),
  ('P-0410', 'received', 'refrigerated', 7,  'day',   null),
  ('P-0421', 'opened',   'room_temp',    14, 'day',   '밀봉');

-- ---------- 주의사항 ----------

insert into product_notices (product_id, notice_type, target, detail) values
  ('P-0113', 'storage_prohibited', '냉장',                  '습기를 먹어 눅눅해짐'),
  ('P-0113', 'cross_contact',      '견과류',                '견과류 생산 라인 공유'),
  ('P-0113', 'allergen_free',      '글루텐',                '글루텐 없음'),
  ('P-0127', 'allergen_contains',  '없음',                  '알레르기 유발 물질 없음'),
  ('P-0127', 'storage_prohibited', '다른 과일과 함께 보관', '에틸렌으로 다른 과일이 빨리 익음'),
  ('P-0205', 'allergen_contains',  '없음',                  '알레르기 유발 물질 없음'),
  ('P-0205', 'storage_tip',        '섭취 시기',             '꼭지가 마르면 당도가 떨어지므로 받은 날부터 3일 안에 섭취 권장'),
  ('P-0207', 'allergen_contains',  '없음',                  '알레르기 유발 물질 없음'),
  ('P-0207', 'storage_prohibited', '금속 숟가락',           '발효가 빨라짐. 나무 또는 플라스틱 숟가락 사용'),
  ('P-0305', 'allergen_contains',  '없음',                  '알레르기 유발 물질 없음'),
  ('P-0305', 'storage_prohibited', '냉동',                  '해동하면 수분이 빠져 질겨짐'),
  ('P-0312', 'allergen_contains',  '없음',                  '알레르기 유발 물질 없음'),
  ('P-0312', 'storage_prohibited', '비닐봉지 밀봉',         '곰팡이가 생김'),
  ('P-0312', 'storage_prohibited', '냉장',                  '싹이 남'),
  ('P-0318', 'allergen_contains',  '없음',                  '알레르기 유발 물질 없음'),
  ('P-0318', 'intake_caution',     '임산부 · 수술 전후',    '섭취 전 전문가 상담'),
  ('P-0318', 'storage_tip',        '여름철',                '냉장 보관 권장'),
  ('P-0402', 'allergen_contains',  '밀',                    '밀가루'),
  ('P-0402', 'allergen_contains',  '대두',                  '간장'),
  ('P-0402', 'cross_contact',      '계란',                  '제조 라인에서 계란 사용'),
  ('P-0402', 'cooking_prohibited', '전자레인지',            '피가 질겨짐'),
  ('P-0402', 'cooking_guide',      '팬 조리',               '해동하지 말고 냉동 상태로 팬에 기름 두르고 중불 3분'),
  ('P-0410', 'allergen_contains',  '없음',                  '알레르기 유발 물질 없음'),
  ('P-0410', 'storage_tip',        '꼭지 방향',             '꼭지를 아래로 두고 보관(수분 증발 감소)'),
  ('P-0410', 'storage_tip',        '냉장 후 섭취',          '먹기 30분 전 꺼내면 맛이 돌아옴'),
  ('P-0421', 'cross_contact',      '견과류',                '견과류 생산 라인 공유'),
  ('P-0421', 'storage_tip',        '실리카겔',              '습기에 약하므로 실리카겔을 버리지 않기'),
  ('P-0421', 'cooking_guide',      '차',                    '80℃ 물 300ml에 5조각');

-- ---------- 배송정책 ----------

insert into shipping_policies (id, item, condition, value) values
  ('SHIP-01', '배송비',   '주문 금액 3만원 이상',               '무료'),
  ('SHIP-02', '배송비',   '주문 금액 3만원 미만',               '2,500원'),
  ('SHIP-03', '배송일',   '수성구 · 달서구, 오후 2시 이전 주문', '당일 배송'),
  ('SHIP-04', '배송일',   '그 외 지역',                          '익일 배송'),
  ('SHIP-05', '발송요일', '신선 식품',                           '월~목 발송'),
  ('SHIP-06', '발송요일', '신선 식품, 금요일 주문',              '다음 주 월요일 발송');
