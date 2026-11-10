# m6-11 전설 스킨 "다이너마이트 스시" — 개발 작업 기록

## 2026-11-10 — 구현·렌더 비평·테스트 (사용자 확인 대기)
- 브랜치: `claude/gracious-curie-tl82em-dynamite` (worktree `/home/user/sushi-dynamite`). push 안 함(요청). 스펙 문서·CLAUDE.md·GDD·GAME-GUIDE·CHANGELOG·USER-TODO·DEV-SETUP·README와 공격 연출(`AttackFxLogic` — 메인 세션이 main에서 `dynamite-sushi` 연출 추가)·공격 코드·Config/Remotes/Types/Attributes·init 스크립트는 손대지 않음.
- 요청(메인 세션 → 사용자 콘셉트 그림, 파일 없음): 콘셉트 몸 위 귀여운 다이너마이트 묶음. 빨간 막대 약 8개가 통처럼 두르고, 숯빛 띠 두 줄, 위에 갈색 받침 + 꼰 심지 + 노랑·주황 Neon 불꽃, 효과 2개(불꽃 Sparkles/Fire + 옅은 회색 Smoke). 전설 R$ 199, drawGrade Legendary, conceptBody, order 49, productId nil, 대사 2줄. 특정 작품 없음.

### 끝난 것
- 카탈로그 `src/shared/Skins.luau`: `dynamite-sushi`(다이너마이트 스시, order 49), `CONCEPT_BODY_IDS`·`DRAW_IDS`에 한 줄씩, 머리 주석.
- 모양: 새 순수 데이터 모듈 `src/shared/ConceptDynamite.luau`(`topping()`, PartMath만 require). 파츠 이름은 `Dynamite…`. `SushiConceptSample.SKIN_IDS`·`TOPPINGS`에 연결.
- 규칙 표 `SushiBody` `LEGEND_RULES`: `["dynamite-sushi"] = { partBudget = 70 }`(80 안 씀). 외곽 ±25%, 이름표 기본 3.6. 스킨 id 분기 없음.
- 현지화 `Strings.csv` 3행(이름·대사 ko/en).
- 테스트: 새 `tests/m6-11-dynamite-sushi.spec.luau`(17개) + 개수 고정 테스트 갱신(아래).
- 렌더: `docs/renders/characters/dynamite-sushi/` — `before-closeup.png`·`before-turntable.png`(v1), `after-closeup.png`·`after-turntable.png`·`after-turntable-lobby.png`·`after-expressions.png`·`after-gameplay-back.png`·`after-mobile-back.png`(최종). 천사와 같은 파일 묶음.

### 모양
- 막대 9개(빨강 원기둥, 위끝에 한 단 좁은 밝은 빨강 마개 = 깎인 끝): 뒤 5개(지름 0.8, 서로 닿아 뒤에서 통째로 막대 묶음), 옆 2개(지름 0.8, 팔 뒤 z 0.45), 앞 모서리 2개(지름 0.56, 둥근 밥 모서리에 반쯤 묻힘 — 팔이 앞에서도 반쯤 보여요). 위끝 높이 1.40~1.66으로 들쭉날쭉(밥 위 1.0 위로 삐죽).
- 띠 2줄(숯빛 {56,56,62}, Fabric): 위 y 0.78~1.12, 아래 y −1.08~−0.82. 앞(밥 앞면 위, 얼굴 위·아래로만)·뒤(뒤 막대 바깥)·양옆(옆 막대 바깥) 판 + 앞 모서리 막대를 감는 고리. 뒤 모서리는 네모로 만나요.
- 심지: 밥 위 가운데 짙은 갈색 받침(Wood) → 꼰 심지 4마디(밝은/어두운 황갈색 번갈아)가 +X쪽으로 휘어 올라감 → 끝에 노란 Neon 공(Sparkles) + 주황 Neon 빛살 3개(60°마다 별). 마지막 심지 마디에 옅은 회색 Smoke.
- 얼굴은 공유 콘셉트 얼굴 그대로(벌린 웃는 입 + 볼). 빨간 앞판(선택 사항)은 넣지 않음 — 얼굴 높이에서 밥 앞면 앞으로 나오면 m5-28 얼굴 검사에 걸리고, 밥 색을 바꾸면 공유 몸 검사가 깨져요.

### 수치 (표정 6종)
| 파츠 (기본/최소~최대) | 상한 | 효과 | 외곽 X × Y × Z (salmon 대비 X·Z) | 꼭대기 | 이름표 |
|---|---|---|---|---|---|
| 64 / 60~68 | 70 | Sparkles(불꽃 공) + Smoke(심지 끝 마디) | 4.76 × 4.87 × 3.30 (1.00 · 1.11) | 2.62 | 3.6 |
- 발바닥 2.25, 겹침·떠 있는 파츠 0, 관절 공유 8개(토핑은 모두 Body 용접, attach 없음), 얼굴 높이에서 밥 앞면보다 앞으로 나온 토핑 0. 폭은 팔(±2.33)이 정해요 — 막대 바깥 x 1.98·띠 2.02라 제트기와 달리 X 한도(5.95)에 여유.

### 렌더 비평 (`lune run tools/render-character dynamite-sushi --view closeup|turntable|expressions|gameplay [--light studio|lobby]`)
1. v1(막대 8개 지름 0.6, 띠 두께 0.2): 다이너마이트로 읽히지만 뒤에서 막대 사이로 흰 밥이 줄무늬처럼 보여 울타리·바코드 같음. 띠가 가늘어 얼굴 둘레 검은 액자 선 같음. 앞 모서리 막대(지름 0.6)가 팔을 거의 다 가림. 위에서 보면 막대가 띄엄띄엄. → 뒤 5개·옆 2개를 지름 0.8로 굵게 해 서로 닿게, 띠 두께 0.34/0.26, 앞 모서리 막대는 0.56으로 가늘게 바깥 x를 옆 막대와 맞춤(팔 보이게), 불꽃·심지 조금 크게.
2. v2: 뒤·게임 카메라에서 통통한 막대 묶음 + 띠 두 줄로 바로 읽힘, 팔도 보임. 불꽃이 게임 화면에서 작음, 앞 모서리 막대가 낮아 띠 위로 거의 안 나옴. → 심지를 더 높게 휘고(꼭대기 2.62) 불꽃 공 0.46·빛살 0.96, 앞 모서리 막대 위끝 +0.1.
3. v3: 불꽃이 또렷. 테스트에서 m5-28 "얼굴 높이에서 밥 앞면보다 앞으로 안 나옴"(x 제한 없음)에 앞 모서리 막대(z −1.58)가 걸림 → 앞 모서리 막대를 z −1.06으로 밥 둥근 모서리에 묻음.
4. v4(최종): 앞에서는 빨간 모서리 막대 + 띠 고리가 얼굴을 둥근 틀처럼 감싸고, 뒤·옆은 막대 묶음, 위에 휜 심지와 노란 불꽃. 로비 조명에서도 빨강·숯빛이 구분됨. 남은 차이: 앞 모서리 막대가 반쯤 묻혀 앞에서는 가는 빨간 기둥으로 보여요(얼굴 검사 한도 때문). 위에서 보면 밥 윗면이 흰 채로 넓어요(초밥 밥 — 의도).

### 바뀐 테스트 (기존 고정 값 갱신, +1)
- 개수: 스킨 48 → 49, 전설 14 → 15, 콘셉트 몸·뽑기·견본 17 → 18(`m5-03-foundation`·`m5-22-qa`·`m5-27-concept-skin`·`m5-28-concept-skins`·`m5-29-concept-skins-2`·`m5-31-draw-logic`·`m5-32-fresh-mackerel`·`m6-08-legend-skins`·`m6-09-magical-girl-sushi`·`m6-10-angel-devil-sushi`·`skins`), 효과 표 1행(`skins`).
- 순서: 끝에서 세던 위치 한 칸 앞(`m5-28-qa`·`m5-29-qa`·`m5-29-concept-skins-2`·`m5-32-fresh-mackerel`·`m6-08-legend-skins`·`m6-09-magical-girl-sushi`·`m6-10-angel-devil-sushi`), 맨 끝 = 다이너마이트(`m5-28-concept-skins`).
- 뽑기: 전설 등급 9종, 스킨마다 0.111% — 화면 표시(`DrawLogic.perSkinPercent`)는 **"0.11%"**. `SOLD_LEGENDS`(m5-31 때 카탈로그)에 추가, 고등어 레이아웃 스냅숏 제외 목록에 추가(`m5-32-fresh-mackerel` AC5).
- require: 견본 모듈이 토핑 모듈 6개(`sushi-body`·`m5-28-concept-skins`).

### 검증
- `lune run tests` **2552 passed, 0 failed** (이 브랜치 기준 2535 + 새 17). `rojo build` 통과, `stylua --check src tests tools` 통과, `luau-lsp analyze` 끝 코드 0, selene 근사 std(Roblox API 검사 없음) 0 errors / 0 warnings.

### Studio에서 확인할 것 (사용자)
1. 탈의실 전설 탭 맨 끝(악마 다음) 다이너마이트, 카드 "R$ 199 — 곧 열려요" + "🎫 뽑기 전설에서도 나와요".
2. 불꽃 Sparkles·심지 Smoke 양(렌더러는 Sparkles를 안 그려요), Neon 불꽃이 Future 조명에서 너무 밝지 않은지.
3. 걸을 때 팔이 앞 모서리·옆 막대 사이로 자연스럽게 흔들리는지(팔은 막대와 안 겹치게 배치했지만 흔들림 폭은 Studio에서).
4. 이름표가 불꽃과 겹치지 않는지(꼭대기 2.62, 이름표 3.6).
5. 뽑기 화면: 전설 줄 1.0%, ⓘ 스킨별 "각 0.11%" 9줄(실제 0.111%), 보유 n/18.
6. 대사·영어 문구, 개발자 상품(R$ 199) → `productId`. 공격 연출은 메인 세션 main 쪽(`AttackFxLogic`).

### 남은 것 / 막힌 점
- 남은 것: 사용자 Studio 확인, 상품 id, 문서 반영(메인 세션), 진짜 roblox std로 selene 한 번, main의 `AttackFxLogic` 연출과 병합 뒤 검증 다시.
- 막힌 점: 없음.
