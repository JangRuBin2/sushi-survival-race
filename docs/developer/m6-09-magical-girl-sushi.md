# m6-09 전설 스킨 "마법소녀 스시" — 개발 작업 기록

## 2026-11-10 — 구현·렌더 비평·테스트 (사용자 확인 대기)
- 브랜치: `claude/gracious-curie-tl82em-magical` (worktree `/home/user/sushi-magical`). push 안 함(요청). 스펙 파일·CLAUDE.md·GDD·GAME-GUIDE·CHANGELOG·USER-TODO·DEV-SETUP과 공격 연출(`AttackFxLogic`·`AttackFxController`·`m6-08-attack` 테스트)은 메인 세션 담당이라 손대지 않음.
- 스펙 `docs/specs/m6-09-magical-girl-sushi.md`는 메인 체크아웃에서 복사해 읽기만 함(커밋 안 함).
- 디자인은 메인 세션이 고정한 오리지널 마법소녀(장르만 가져옴): 분홍 트윈테일 + 민트 리본 + 정수리 노란 별 핀, 흰·민트 프릴 짧은 망토 + 앞 아래 분홍 하트 브로치, 오른손 별 지팡이(노란 별·흰 날개 둘·분홍 손잡이). 참고 그림의 특정 작품 특징(머리 모양·이마 장식·달 모양 지팡이·큰 옷깃·가슴 큰 리본)은 쓰지 않음.

### 끝난 것
- 카탈로그 `src/shared/Skins.luau`: `magical-girl-sushi`(마법소녀 스시, Legendary, R$ 199, drawGrade Legendary, conceptBody, order 46, productId nil, 대사 2줄), `CONCEPT_BODY_IDS`·`DRAW_IDS`에 한 줄씩.
- 모양: 새 순수 데이터 모듈 `src/shared/ConceptMagicalGirl.luau`(`topping()`, PartMath만 require). 파츠 이름은 모두 `Magic…`. `SushiConceptSample.SKIN_IDS`·`TOPPINGS`에 연결.
- 규칙 표 `SushiBody.CONCEPT_BODY`: m6-08 `LEGEND_RULES`에 `partBudget = 80` 한 줄(용 둘·고등어와 같은 상한). 외곽 ±25%(concept-salmon 기준), `nameTagHeight` 안 씀(기본 3.6). 스킨 id 분기 없음.
- 지팡이 15파츠는 `attach = "ArmRight"` — 오른팔 Motor6D에 용접돼 걷기·숨쉬기 팔 흔들기를 따라가요(관절 수는 공유 8개 그대로, 클라이언트 코드 변경 없음).
- 현지화 `Strings.csv` 3행: 이름·대사(Source = 카탈로그, en).
- 테스트: 새 `tests/m6-09-magical-girl-sushi.spec.luau`(14개) + 개수·목록 고정 테스트 갱신(아래).

### 수치 (표정 6종)
| 항목 | 값 |
|---|---|
| 파츠 | 기본 76, 최대 80(화남·슬픔) / 상한 80 — 토핑 51 |
| 효과 | Glow(지팡이 별 가운데, 따뜻한 노랑) + Sparkles(지팡이 별 위 끝, 분홍) — 전설 2개 |
| 외곽 | 5.78 × 4.44 × 3.14 (한도 X 5.95 · Z 3.70, salmon 대비 X 1.22 · Z 1.06) |
| 꼭대기 | 2.19 (이름표 3.6 − 0.4 = 3.2 안, 탈의실 미리보기 한도 약 3.06 안) |
| 이름표 | 기본 3.6 |
| 발바닥·겹침·떠 있음 | 2.25 / 0 / 0, 얼굴 영역(x ±1.4, y −0.8~0.76)에서 밥 앞면보다 앞으로 나온 토핑 0 |
- 앞머리 갈래 아래끝 y 0.78, 얼굴 옆 머리카락 x ≥ 1.46, 하트 위끝 y −0.81(얼굴 아래).

### 렌더 비평 (`lune run tools/render-character magical-girl-sushi --view closeup|turntable|expressions|gameplay`)
1. v1: 머리 위 테두리 판이 네모 모자 챙 같고, 앞머리 둥근 공 셋이 구슬 장식처럼 보여 이마 장식으로 읽힐 위험. 트윈테일이 짧고 거의 가로라 앞에서 뿔·귀처럼 보임. 리본은 얇은 판이라 안 보임. 지팡이 별이 머리·꼬리에 가려 작게 보이고 날개가 흰 배경에 묻힘. 망토 아래 원판 넷이 통째로 보여 물방울 무늬 같음. → 앞머리를 아래로 뾰족한 쐐기 넷(V 두 개)으로, 꼬리를 길게(어깨 밖으로 내려가 팔 높이까지), 리본 고리를 크게·앞으로 돌림, 지팡이를 앞 14°·바깥 16°로 기울이고 별 반지름 0.44 → 0.5, 프릴 원판을 등 판 속에 반 묻어 아래 반만 물결 단으로, 망토를 옷깃에서 8° 뒤로 퍼지게.
2. v2: 등 뒤 물결 단이 또렷하고 트윈테일·리본이 뒤 카메라에서 잘 읽힘. 지팡이 별·날개가 얼굴 옆 앞에 보임. 앞머리 V가 테두리 판 아래로 0.16만 나와 가는 줄처럼 약함. 외곽 X가 한도를 0.005 넘음(validate 실패). → 앞머리 쐐기를 위로 키우고(1.34 → 0.78) 테두리보다 조금 진한 분홍, 꼬리를 안으로 당김.
3. v3: 앞에서 V 두 갈래 앞머리 + 얼굴 옆 머리카락 + 트윈테일로 "분홍 머리"가 바로 읽힘. 표정 6종 모두 얼굴 안 가림. 꼬리 끝이 평평하게 잘려 보임 → 끝을 뒤로 조금 휘게, 망토 판 재질을 SmoothPlastic으로(밝게).
4. v4(최종): 3/4·뒤·게임 뒤 카메라에서 분홍 머리·민트 리본·흰 망토와 민트 물결 단·노란 별 지팡이가 모두 읽힘. 남은 차이: 망토가 해 반대쪽이라 회색으로 그려짐(조명 탓, 밥 등면도 같음), 둥근 머리가 큰 돔이라 위에서 보면 매끈함(파츠 상한 80이 다 차서 가르마 등은 못 넣음).
- 처음·마지막 렌더: `docs/renders/characters/magical-girl-sushi/before-closeup.png`·`before-turntable.png`, `after-closeup.png`·`after-turntable.png`·`after-turntable-lobby.png`·`after-expressions.png`·`after-gameplay-back.png`·`after-mobile-back.png`.

### 바뀐 테스트 (기존 고정 값 갱신)
- 개수: `m5-03-foundation`·`m5-22-qa`·`m5-29-concept-skins-2`·`m5-32-fresh-mackerel`·`m6-08-legend-skins`·`skins`(45 → 46, 전설 11 → 12, 표에 1행, 효과 표 1행), `m5-27-concept-skin`·`m5-28-concept-skins`(콘셉트 몸 14 → 15, 상한 80 목록에 추가), `m5-30-qa`(상한 80 목록).
- 순서: `m5-28-concept-skins`(맨 끝 = 마법소녀, 45번 = 섀도 제트), `m5-28-qa`·`m5-29-qa`·`m5-29-concept-skins-2`(끝에서 세던 위치 한 칸 앞), `m5-32-fresh-mackerel`(전설 탭 끝에서 여섯째), `m6-08-legend-skins`(전설 탭 끝 6장).
- 뽑기: `m5-31-draw-logic`·`m5-31-qa`의 "m5-31 때 카탈로그"(`SOLD_LEGENDS`)에 마법소녀 추가, `DRAW_IDS`·`totalSkins` 15, `m5-32-*`·`m6-08-legend-skins`의 전설 등급 목록 6종·스킨별 0.17%, 레이아웃 스냅숏은 새 스킨 제외.
- require: `m5-28-concept-skins`·`sushi-body` — 견본 모듈이 토핑 모듈 4개(고등어·용·전투기·마법소녀)를 부르고 각각 PartMath만.
- `m6-08-legend-skins`의 "공유 코드에서 새 id" 허용 목록 검사는 그 4종 id만 보므로 그대로 통과.

### 검증
- `rojo build` 통과, `stylua --check src tests tools` 통과, `luau-lsp analyze` 끝 코드 0(경고 없음), `lune run tests` **2513 passed, 0 failed** (기준 2499 + 새 14).
- `selene src`: 이 환경에서는 Roblox API dump를 못 받아(사설 CA 프록시) **근사 std**(`tools/cloud/selene.toml`, Roblox API 검사 없음)로 돌림 — 0 errors / 0 warnings. 진짜 `std = "roblox"`는 사용자 PC에서 한 번 확인 필요.

### Studio에서 확인할 것 (사용자)
1. 탈의실 전설 탭 맨 끝(섀도 제트 다음) 카드 "R$ 199 — 곧 열려요" + "🎫 뽑기 전설에서도 나와요". Studio 전부 입기로 입어 보기.
2. 입은 캐릭터: 걸을 때 지팡이가 오른팔과 같이 흔들리는지(손에서 안 떨어지는지), 지팡이 별 Glow 밝기·분홍 Sparkles가 과하지 않은지, 이름표·👑가 별 핀·지팡이와 안 겹치는지.
3. 뽑기 화면: 전설 줄 1.0%, ⓘ 스킨별 "각 0.17%" 6줄, 보유 n/15.
4. 탈락 말풍선 대사 2줄, 영어 클라이언트에서 영어 이름·대사.
5. 개발자 상품(R$ 199)을 만들어 `Skins.luau`의 `productId`에 넣기(USER-TODO C3와 같은 절차).
6. 공격 연출 `StarRibbon`은 메인 세션 작업(DEV-SETUP 3-18).

### 남은 것 / 막힌 점
- 남은 것: 사용자 Studio 확인, 상품 id, 문서 반영(메인 세션), 진짜 roblox std로 selene 한 번.
- 막힌 점: 없음.
